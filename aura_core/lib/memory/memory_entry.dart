import 'package:objectbox/objectbox.dart';

/// A single memory entry stored in ObjectBox for semantic recall.
/// Each entry corresponds to one persisted chat message or a document chunk.
@Entity()
class MemoryEntry {
  @Id()
  int id;

  /// Original message text (what gets injected into context on recall)
  String content;

  /// 'user' | 'assistant' | 'document'
  String role;

  /// Corresponding SQLite session ID, or 0 if document
  int sessionId;

  /// Corresponding SQLite message ID (for deduplication), or 0 if document
  int messageId;

  /// When the message was created (milliseconds since epoch)
  int timestampMs;

  /// 'chat' | 'document'
  String sourceType;

  /// SQLite document source ID if sourceType is 'document', or 0 if chat
  int sourceId;

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
    this.sourceType = 'chat',
    this.sourceId = 0,
  });
}
