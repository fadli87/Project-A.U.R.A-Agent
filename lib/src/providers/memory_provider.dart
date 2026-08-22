import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/chat_models.dart';
import '../memory/objectbox_store.dart';
import '../memory/memory_entry.dart';
import '../memory/embedding_service.dart';
import '../../objectbox.g.dart';

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
  static String formatMemoriesForPrompt(List<MemoryEntry> memories) {
    if (memories.isEmpty) return '';
    final sb = StringBuffer('[RELEVANT MEMORIES]\n');
    for (final m in memories) {
      final roleLabel = m.role == 'user' ? 'User previously said' : 'Assistant previously said';
      sb.writeln('- $roleLabel: "${m.content.trim()}"');
    }
    sb.writeln('[END MEMORIES]');
    return sb.toString();
  }
}
