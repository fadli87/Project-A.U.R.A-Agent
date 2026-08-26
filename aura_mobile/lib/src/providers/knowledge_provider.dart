import 'dart:isolate';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:aura_core/aura_core.dart';
import 'package:path/path.dart' as path_lib;

part 'knowledge_provider.g.dart';

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

/// Isolate entry point to extract text and chunk a document
Future<List<String>> _parseAndChunkFileInIsolate(String filePath) async {
  final text = await TextExtractor.extractText(filePath);
  return TextChunker.chunkText(text);
}

@riverpod
class KnowledgeNotifier extends _$KnowledgeNotifier {
  @override
  KnowledgeState build() {
    loadSources();
    return const KnowledgeState();
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
      // 1. Run text extraction & chunking in a background Isolate
      final chunks = await Isolate.run(() => _parseAndChunkFileInIsolate(filePath));

      if (chunks.isEmpty) {
        throw Exception('Dokumen kosong atau tidak dapat diuraikan.');
      }

      // 2. Insert reference to DocumentSources in SQLite
      final docId = await ChatDatabase.instance.insertDocumentSource({
        'name': path_lib.basename(filePath),
        'path': filePath,
        'imported_at': DateTime.now().millisecondsSinceEpoch,
        'chunk_count': chunks.length,
      });

      // 3. Compute embedding for each chunk and save to ObjectBox
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

      // 4. Reload list
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
      // 1. Delete from SQLite
      await ChatDatabase.instance.deleteDocumentSource(id);

      // 2. Delete from ObjectBox
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

      // 3. Reload list
      await loadSources();
    } finally {
      state = state.copyWith(
        isImporting: false,
        clearProgress: true,
      );
    }
  }
}
