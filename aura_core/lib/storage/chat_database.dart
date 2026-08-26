import 'package:sqlite3/sqlite3.dart';
import 'chat_models.dart';

/// SQLite database wrapper to mimic sqflite API on top of sqlite3 FFI.
class Sqlite3DatabaseWrapper {
  final Database _db;
  Sqlite3DatabaseWrapper(this._db);

  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    _db.execute(sql, arguments ?? const []);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    var sql = 'SELECT * FROM $table';
    if (where != null) {
      sql += ' WHERE $where';
    }
    if (orderBy != null) {
      sql += ' ORDER BY $orderBy';
    }
    if (limit != null) {
      sql += ' LIMIT $limit';
    }
    final results = _db.select(sql, whereArgs ?? const []);
    return results.map((row) {
      final map = <String, dynamic>{};
      for (final columnName in results.columnNames) {
        map[columnName] = row[columnName];
      }
      return map;
    }).toList();
  }

  Future<int> insert(String table, Map<String, dynamic> values) async {
    final keys = values.keys.toList();
    final columns = keys.join(', ');
    final placeholders = List.filled(keys.length, '?').join(', ');
    final sql = 'INSERT INTO $table ($columns) VALUES ($placeholders)';
    _db.execute(sql, values.values.toList());
    return _db.lastInsertRowId;
  }

  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final keys = values.keys.toList();
    final setClause = keys.map((k) => '$k = ?').join(', ');
    var sql = 'UPDATE $table SET $setClause';
    if (where != null) {
      sql += ' WHERE $where';
    }
    final args = [...values.values, ...?whereArgs];
    _db.execute(sql, args);
    return _db.updatedRows;
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    var sql = 'DELETE FROM $table';
    if (where != null) {
      sql += ' WHERE $where';
    }
    _db.execute(sql, whereArgs ?? const []);
    return _db.updatedRows;
  }

  Future<void> transaction(Future<void> Function(Sqlite3DatabaseWrapper txn) action) async {
    _db.execute('BEGIN TRANSACTION');
    try {
      await action(this);
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> close() async {
    _db.dispose();
  }
}

/// SQLite database for persistent chat history.
///
/// Schema:
///   sessions (id, title, created_at, updated_at, model_name)
///   messages (id, session_id, role, content, timestamp, tool_call_json, tool_result)
class ChatDatabase {
  ChatDatabase._();

  static final ChatDatabase instance = ChatDatabase._();

  static Sqlite3DatabaseWrapper? _db;
  static String? _dbPath;

  static const _dbVersion = 3;

  /// Initialize database path before calling [database]
  static void init(String path) {
    _dbPath = path;
  }

  Future<Sqlite3DatabaseWrapper> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Sqlite3DatabaseWrapper> _initDatabase() async {
    if (_dbPath == null) {
      throw StateError('ChatDatabase must be initialized by calling init(path) first.');
    }
    final db = sqlite3.open(_dbPath!);
    final wrapper = Sqlite3DatabaseWrapper(db);

    final currentVersion = db.userVersion;
    if (currentVersion == 0) {
      await _onCreate(wrapper);
      db.userVersion = _dbVersion;
    } else if (currentVersion < _dbVersion) {
      await _onUpgrade(wrapper, currentVersion, _dbVersion);
      db.userVersion = _dbVersion;
    }

    return wrapper;
  }

  Future<void> _onCreate(Sqlite3DatabaseWrapper db) async {
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

    await _createFase7Tables(db);
    await _createTodoTables(db);
  }

  Future<void> _createFase7Tables(Sqlite3DatabaseWrapper db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Persona (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        content TEXT NOT NULL,
        is_active INTEGER DEFAULT 0,
        is_builtin INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS Skills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT NOT NULL,
        body TEXT NOT NULL,
        enabled INTEGER DEFAULT 1,
        keywords TEXT,
        is_agent_created INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS MemorySnapshot (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        summary TEXT NOT NULL,
        message_count_at_update INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS UserProfile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fact TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // Seed default persona if table is empty
    final existing = await db.query('Persona');
    if (existing.isEmpty) {
      await db.insert('Persona', {
        'name': 'AURA Interactive Persona',
        'content': 'Anda adalah AURA, asisten AI personal ekspresif & interaktif yang berjalan 100% offline di perangkat pengguna. Selalu gunakan emotikon yang relevan (seperti 🚀, ✨, ⚡, 💡, 🎯, 📊, 🛡️), simbol menarik (seperti •, ───, 📌, ➔), poin-poin terstruktur, dan format Markdown yang rapi dalam setiap jawaban agar komunikasi terasa hidup, ramah, dan interaktif.',
        'is_active': 1,
        'is_builtin': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  Future<void> _onUpgrade(Sqlite3DatabaseWrapper db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createFase7Tables(db);
    }
    if (oldVersion < 3) {
      await _upgradeToVersion3(db);
    }
  }

  Future<void> _upgradeToVersion3(Sqlite3DatabaseWrapper db) async {
    try {
      await db.execute('ALTER TABLE Skills ADD COLUMN is_agent_created INTEGER DEFAULT 0');
    } catch (_) {}
    await _createTodoTables(db);
  }

  Future<void> _createTodoTables(Sqlite3DatabaseWrapper db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS TodoLists (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS TodoItems (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        list_id    INTEGER NOT NULL,
        content    TEXT    NOT NULL,
        is_done    INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (list_id) REFERENCES TodoLists(id) ON DELETE CASCADE
      )
    ''');
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
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
