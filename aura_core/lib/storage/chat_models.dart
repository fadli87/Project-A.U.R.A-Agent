/// Data model for a chat message (user or assistant)
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isStreaming = false,
    this.toolCallJson,
    this.toolResult,
  });

  final int id;
  final int sessionId;
  final MessageRole role;
  final String content;
  final DateTime timestamp;

  /// True if this assistant message is still being streamed token-by-token
  final bool isStreaming;

  /// Non-null if this message contains a tool call (JSON payload from model)
  final String? toolCallJson;

  /// Non-null if this message is a tool execution result (observation)
  final String? toolResult;

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get isTool => role == MessageRole.tool;

  ChatMessage copyWith({
    int? id,
    int? sessionId,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
    String? toolCallJson,
    String? toolResult,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      toolCallJson: toolCallJson ?? this.toolCallJson,
      toolResult: toolResult ?? this.toolResult,
    );
  }

  /// Convert to SQLite-compatible map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'tool_call_json': toolCallJson,
      'tool_result': toolResult,
    };
  }

  /// Create from SQLite row
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int,
      sessionId: map['session_id'] as int,
      role: MessageRole.values.byName(map['role'] as String),
      content: map['content'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      toolCallJson: map['tool_call_json'] as String?,
      toolResult: map['tool_result'] as String?,
    );
  }

  @override
  String toString() =>
      'ChatMessage(role: ${role.name}, content: ${content.substring(0, content.length > 50 ? 50 : content.length)}...)';
}

/// Role of a message in the conversation
enum MessageRole {
  /// Human input
  user,

  /// AI model response
  assistant,

  /// System prompt (not shown in UI)
  system,

  /// Tool execution result (observation fed back to model)
  tool,
}

/// A chat session (conversation)
class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.modelName,
  });

  final int id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? modelName;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'model_name': modelName,
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'] as int,
      title: map['title'] as String,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      modelName: map['model_name'] as String?,
    );
  }

  ChatSession copyWith({
    int? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? modelName,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      modelName: modelName ?? this.modelName,
    );
  }
}


/// A document source imported by the user for RAG
class DocumentSource {
  final int id;
  final String name;
  final String path;
  final DateTime importedAt;
  final int chunkCount;

  const DocumentSource({
    required this.id,
    required this.name,
    required this.path,
    required this.importedAt,
    required this.chunkCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'imported_at': importedAt.millisecondsSinceEpoch,
      'chunk_count': chunkCount,
    };
  }

  factory DocumentSource.fromMap(Map<String, dynamic> map) {
    return DocumentSource(
      id: map['id'] as int,
      name: map['name'] as String,
      path: map['path'] as String,
      importedAt: DateTime.fromMillisecondsSinceEpoch(map['imported_at'] as int),
      chunkCount: map['chunk_count'] as int,
    );
  }
}
