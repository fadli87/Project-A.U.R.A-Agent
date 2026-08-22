import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path_lib;

import 'chat_models.dart';

/// SQLite database for persistent chat history.
///
/// Schema:
///   sessions (id, title, created_at, updated_at, model_name)
///   messages (id, session_id, role, content, timestamp, tool_call_json, tool_result)
class ChatDatabase {
  ChatDatabase._();

  static final ChatDatabase instance = ChatDatabase._();

  static Database? _db;

  static const _dbName = 'aura_chat.db';
  static const _dbVersion = 1;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path_lib.join(dbPath, _dbName);

    return openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        title      TEXT    NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        model_name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id     INTEGER NOT NULL,
        role           TEXT    NOT NULL,
        content        TEXT    NOT NULL,
        timestamp      INTEGER NOT NULL,
        tool_call_json TEXT,
        tool_result    TEXT,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');

    // Index for fast session-based message retrieval
    await db.execute('''
      CREATE INDEX idx_messages_session_id ON messages(session_id, timestamp)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Reserved for future schema migrations
  }

  // ─── Sessions ───────────────────────────────────────────────────────────────

  /// Create a new chat session, return its ID
  Future<int> createSession({String? modelName}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert('sessions', {
      'title': 'Chat baru',
      'created_at': now,
      'updated_at': now,
      'model_name': modelName,
    });
  }

  /// Update session title (e.g. after first user message is sent)
  Future<void> updateSessionTitle(int sessionId, String title) async {
    final db = await database;
    await db.update(
      'sessions',
      {
        'title': title,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<List<ChatSession>> getAllSessions() async {
    final db = await database;
    final maps = await db.query(
      'sessions',
      orderBy: 'updated_at DESC',
    );
    return maps.map(ChatSession.fromMap).toList();
  }

  Future<void> deleteSession(int sessionId) async {
    final db = await database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  // ─── Messages ───────────────────────────────────────────────────────────────

  /// Save a message and return its auto-generated ID.
  /// Called automatically after every user/assistant turn.
  Future<int> saveMessage(ChatMessage message) async {
    final db = await database;

    // Also update session's updated_at timestamp
    await db.update(
      'sessions',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [message.sessionId],
    );

    return db.insert('messages', {
      'session_id': message.sessionId,
      'role': message.role.name,
      'content': message.content,
      'timestamp': message.timestamp.millisecondsSinceEpoch,
      'tool_call_json': message.toolCallJson,
      'tool_result': message.toolResult,
    });
  }

  /// Load all messages for a session, ordered chronologically
  Future<List<ChatMessage>> getMessagesForSession(int sessionId) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return maps.map(ChatMessage.fromMap).toList();
  }

  /// Get the last N messages for a session (useful for context window building)
  Future<List<ChatMessage>> getRecentMessages(
    int sessionId, {
    int limit = 20,
  }) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    // Reverse to get chronological order
    return maps.reversed.map(ChatMessage.fromMap).toList();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
