import 'package:objectbox/objectbox.dart';

/// A single memory entry stored in ObjectBox for semantic recall.
/// Each entry corresponds to one persisted chat message.
@Entity()
class MemoryEntry {
  @Id()
  int id;

  /// Original message text (what gets injected into context on recall)
  String content;

  /// 'user' | 'assistant'
  String role;

  /// Corresponding SQLite session ID
  int sessionId;

  /// Corresponding SQLite message ID (for deduplication)
  int messageId;

  /// When the message was created (milliseconds since epoch)
  int timestampMs;

  /// 384-dimensional embedding vector from all-MiniLM-L6-v2.
  /// Indexed with HNSW for fast nearest-neighbor search.
  @HnswIndex(dimensions: 384, distanceType: VectorDistanceType.cosine)
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;

  MemoryEntry({
    this.id = 0,
    required this.content,
    required this.role,
    required this.sessionId,
    required this.messageId,
    required this.timestampMs,
    this.embedding,
  });
}
