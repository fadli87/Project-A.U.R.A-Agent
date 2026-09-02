import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aura_core/aura_core.dart';

part 'memory_provider.g.dart';

/// State for the memory system
class MemoryState {
  const MemoryState({
    this.isIndexing = false,
    this.totalEntries = 0,
    this.lastError,
  });

  final bool isIndexing;
  final int totalEntries;
  final String? lastError;

  MemoryState copyWith({
    bool? isIndexing,
    int? totalEntries,
    String? lastError,
    bool clearError = false,
  }) {
    return MemoryState(
      isIndexing: isIndexing ?? this.isIndexing,
      totalEntries: totalEntries ?? this.totalEntries,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

/// Manages semantic memory: embeds chat messages and performs HNSW recall.
@riverpod
class MemoryNotifier extends _$MemoryNotifier {
  @override
  MemoryState build() => const MemoryState();

  /// Store a message in semantic memory.
  /// Computes its embedding and saves to ObjectBox.
  Future<void> storeMessage(ChatMessage message) async {
    if (!ObjectBoxStore.isOpen) return;
    if (message.content.trim().isEmpty) return;
    // Skip tool messages and very short messages (< 5 chars)
    if (message.isTool || message.content.trim().length < 5) return;

    try {
      state = state.copyWith(isIndexing: true);

      // Compute embedding
      final embedding = await EmbeddingService.instance.embed(message.content);

      final entry = MemoryEntry(
        content: message.content,
        role: message.role.name,
        sessionId: message.sessionId,
        messageId: message.id,
        timestampMs: message.timestamp.millisecondsSinceEpoch,
        embedding: embedding,
      );

      final box = ObjectBoxStore.instance.memoryBox;
      box.put(entry);

      state = state.copyWith(
        isIndexing: false,
        totalEntries: box.count(),
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isIndexing: false,
        lastError: e.toString(),
      );
    }
  }

  /// Retrieve the top-K most semantically relevant memory entries for [query].
  /// Returns an empty list if memory store is not available.
  Future<List<MemoryEntry>> recall(String query, {int topK = 3}) async {
    if (!ObjectBoxStore.isOpen) return [];
    if (query.trim().isEmpty) return [];

    try {
      final queryEmbedding = await EmbeddingService.instance.embed(query);
      if (queryEmbedding.every((v) => v == 0.0)) {
        return [];
      }

      final box = ObjectBoxStore.instance.memoryBox;

      // ObjectBox HNSW nearest-neighbor search
      final query_ = box
          .query(MemoryEntry_.embedding.nearestNeighborsF32(queryEmbedding, topK))
          .build();
      final results = query_.find();
      query_.close();

      return results;
    } catch (_) {
      return [];
    }
  }

  /// Format recalled memories as context injection string for the prompt.
  static Future<String> formatMemoriesForPrompt(List<MemoryEntry> memories) async {
    if (memories.isEmpty) return '';
    final sb = StringBuffer();
    
    // Separate chat memories and document memories
    final chatMemories = memories
        .where((m) =>
            m.sourceType != 'document' &&
            !m.content.contains('[Error Inferensi') &&
            !m.content.startsWith('[Error'))
        .toList();
    final docMemories = memories.where((m) => m.sourceType == 'document').toList();
    
    if (chatMemories.isNotEmpty) {
      sb.writeln('[RELEVANT CHAT MEMORIES]');
      // Take at most 3 concise memories
      for (final m in chatMemories.take(3)) {
        String cleanContent = m.content
            .replaceAll(RegExp(r'<think>[\s\S]*?<\/think>'), '')
            .trim();
        if (cleanContent.isEmpty) continue;
        if (cleanContent.length > 160) {
          cleanContent = '${cleanContent.substring(0, 160)}...';
        }
        final roleLabel = m.role == 'user' ? 'User previously said' : 'Assistant previously said';
        sb.writeln('- $roleLabel: "$cleanContent"');
      }
      sb.writeln('[END CHAT MEMORIES]\n');
    }
    
    if (docMemories.isNotEmpty) {
      sb.writeln('[RELEVANT DOCUMENT CHUNKS]');
      for (final m in docMemories.take(2)) {
        final docName = await ChatDatabase.instance.getDocumentName(m.sourceId) ?? 'Dokumen Tidak Dikenal';
        String docContent = m.content.trim();
        if (docContent.length > 250) {
          docContent = '${docContent.substring(0, 250)}...';
        }
        sb.writeln('Dari dokumen "$docName":');
        sb.writeln('"""');
        sb.writeln(docContent);
        sb.writeln('"""');
        sb.writeln();
      }
      sb.writeln('[END DOCUMENT CHUNKS]');
    }
    
    return sb.toString();
  }
}
