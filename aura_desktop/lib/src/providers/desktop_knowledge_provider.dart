import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_core/aura_core.dart';
import 'package:path/path.dart' as path_lib;

class KnowledgeState {
  final List<DocumentSource> sources;
  final bool isImporting;
  final String? importingProgressText;

  const KnowledgeState({
    this.sources = const [],
    this.isImporting = false,
    this.importingProgressText,
  });

  KnowledgeState copyWith({
    List<DocumentSource>? sources,
    bool? isImporting,
    String? importingProgressText,
    bool clearProgress = false,
  }) {
    return KnowledgeState(
      sources: sources ?? this.sources,
      isImporting: isImporting ?? this.isImporting,
      importingProgressText: clearProgress ? null : (importingProgressText ?? this.importingProgressText),
    );
  }
}

Future<List<String>> _parseAndChunkFileInIsolate(String filePath) async {
  final text = await TextExtractor.extractText(filePath);
  return TextChunker.chunkText(text);
}

class DesktopKnowledgeNotifier extends StateNotifier<KnowledgeState> {
  DesktopKnowledgeNotifier() : super(const KnowledgeState()) {
    loadSources();
  }

  Future<void> loadSources() async {
    try {
      final dbMaps = await ChatDatabase.instance.getAllDocumentSources();
      final list = dbMaps.map(DocumentSource.fromMap).toList();
      state = state.copyWith(sources: list);
    } catch (_) {
      state = state.copyWith(sources: []);
    }
  }

  Future<void> importDocument(String filePath) async {
    if (state.isImporting) return;
    
    state = state.copyWith(
      isImporting: true,
      importingProgressText: 'Membaca dan memotong dokumen...',
    );

    try {
      final chunks = await Isolate.run(() => _parseAndChunkFileInIsolate(filePath));

      if (chunks.isEmpty) {
        throw Exception('Dokumen kosong atau tidak dapat diuraikan.');
      }

      final docId = await ChatDatabase.instance.insertDocumentSource({
        'name': path_lib.basename(filePath),
        'path': filePath,
        'imported_at': DateTime.now().millisecondsSinceEpoch,
        'chunk_count': chunks.length,
      });

      final memoryBox = ObjectBoxStore.instance.memoryBox;
      final entries = <MemoryEntry>[];

      for (int i = 0; i < chunks.length; i++) {
        state = state.copyWith(
          importingProgressText: 'Membuat embedding: ${i + 1}/${chunks.length} potongan...',
        );
        final chunk = chunks[i];
        final embedding = await EmbeddingService.instance.embed(chunk);
        entries.add(MemoryEntry(
          content: chunk,
          role: 'document',
          sessionId: 0,
          messageId: 0,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          embedding: embedding,
          sourceType: 'document',
          sourceId: docId,
        ));
      }

      state = state.copyWith(
        importingProgressText: 'Menyimpan indeks dokumen...',
      );
      memoryBox.putMany(entries);

      await loadSources();
    } finally {
      state = state.copyWith(
        isImporting: false,
        clearProgress: true,
      );
    }
  }

  Future<void> deleteDocument(int id) async {
    state = state.copyWith(isImporting: true, importingProgressText: 'Menghapus dokumen...');
    try {
      await ChatDatabase.instance.deleteDocumentSource(id);

      if (ObjectBoxStore.isOpen) {
        final box = ObjectBoxStore.instance.memoryBox;
        final query = box
            .query(MemoryEntry_.sourceType.equals('document').and(MemoryEntry_.sourceId.equals(id)))
            .build();
        final ids = query.findIds();
        query.close();
        if (ids.isNotEmpty) {
          box.removeMany(ids);
        }
      }

      await loadSources();
    } finally {
      state = state.copyWith(
        isImporting: false,
        clearProgress: true,
      );
    }
  }
}

final desktopKnowledgeProvider = StateNotifierProvider<DesktopKnowledgeNotifier, KnowledgeState>((ref) {
  return DesktopKnowledgeNotifier();
});
