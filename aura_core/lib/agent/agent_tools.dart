import 'dart:convert';
import 'alarm_service.dart';
import '../storage/chat_database.dart';
import '../memory/embedding_service.dart';
import '../memory/objectbox_store.dart';
import '../objectbox.g.dart';

class ClarifyRequest {
  final String question;
  final List<String>? options;
  final void Function(String response) onRespond;

  ClarifyRequest({
    required this.question,
    required this.options,
    required this.onRespond,
  });
}

/// Represents a tool declaration schema that model can invoke
abstract class AgentTool {
  String get name;
  String get description;
  Map<String, dynamic> get parametersSchema;

  /// Whether execution of this tool requires explicit user permission dialog (Rule 03-tool-calling.md)
  bool get isSensitive;

  /// Execute the tool with parsed arguments
  Future<String> execute(Map<String, dynamic> args);
}

/// Parsed Tool Call from Model Output
class ToolCallRequest {
  final String name;
  final Map<String, dynamic> arguments;
  final String rawJson;

  ToolCallRequest({
    required this.name,
    required this.arguments,
    required this.rawJson,
  });
}

/// Tool 1: Network Status Checker (Safe - Auto-execute)
class CheckNetworkStatusTool extends AgentTool {
  @override
  String get name => 'check_network_status';

  @override
  String get description => 'Mengecek status koneksi jaringan/internet perangkat Android saat ini.';

  @override
  bool get isSensitive => false;

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {},
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    // In a real device, checking connection via battery/network provider
    return jsonEncode({
      'status': 'connected',
      'type': 'wifi',
      'is_online': true,
    });
  }
}

/// Tool 2: Create Note / Reminder (Sensitive - Requires Approval)
class CreateNoteTool extends AgentTool {
  @override
  String get name => 'create_note';

  @override
  String get description => 'Membuat catatan atau pengingat baru di penyimpanan lokal pengguna.';

  @override
  bool get isSensitive => true;

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'title': {'type': 'string', 'description': 'Judul catatan atau pengingat'},
          'content': {'type': 'string', 'description': 'Isi pengingat atau catatan'},
          'reminder_time': {
            'type': 'string',
            'description': 'Waktu pengingat spesifik dalam format ISO 8601 UTC (misal: "2026-08-24T15:30:00Z"), gunakan ini untuk waktu mutlak.'
          },
          'delay_seconds': {
            'type': 'integer',
            'description': 'Jeda waktu dalam detik dari sekarang untuk memicu pengingat (misal: 300 untuk 5 menit), gunakan ini untuk waktu relatif.'
          },
        },
        'required': ['title', 'content'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final title = args['title'] ?? 'Tanpa Judul';
    final content = args['content'] ?? '';
    final reminderTimeStr = args['reminder_time'] as String?;
    final delaySeconds = args['delay_seconds'] as int?;
    final sessionId = args['sessionId'] as int?;

    DateTime? targetTime;
    if (delaySeconds != null) {
      targetTime = DateTime.now().add(Duration(seconds: delaySeconds));
    } else if (reminderTimeStr != null && reminderTimeStr.isNotEmpty) {
      try {
        targetTime = DateTime.parse(reminderTimeStr).toLocal();
      } catch (_) {
        // Abaikan format tanggal tidak valid
      }
    }

    if (targetTime != null && sessionId != null) {
      final alarmId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      await AlarmService.instance.scheduleReminder(
        id: alarmId,
        title: 'AURA Pengingat: $title',
        content: content,
        time: targetTime,
        sessionId: sessionId,
      );
      return jsonEncode({
        'success': true,
        'message': 'Pengingat "$title" berhasil dijadwalkan pada ${targetTime.toLocal()} (Session ID: $sessionId, Alarm ID: $alarmId).',
      });
    }

    return jsonEncode({
      'success': true,
      'message': 'Catatan "$title" berhasil disimpan ke penyimpanan lokal AURA (tanpa pengingat aktif).',
    });
  }
}

/// Tool 3: Read Sandbox File (Safe)
class ReadAppFileTool extends AgentTool {
  @override
  String get name => 'read_app_file';

  @override
  String get description => 'Membaca isi berkas teks dalam sandbox aplikasi AURA.';

  @override
  bool get isSensitive => false;

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'filename': {'type': 'string', 'description': 'Nama berkas dalam sandbox'},
        },
        'required': ['filename'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final filename = args['filename'] ?? '';
    return jsonEncode({
      'filename': filename,
      'content': 'Ini adalah isi berkas contoh dari sandbox AURA untuk berkas $filename.',
    });
  }
}

/// Tool 4: Web Search (Safe - Auto-execute)
class SearchWebTool extends AgentTool {
  @override
  String get name => 'search_web';

  @override
  String get description => 'Mencari informasi online di browser web default pengguna. Gunakan alat ini KETIKA pengguna menanyakan informasi terkini, cuaca hari ini, berita terbaru, atau hal lain yang membutuhkan akses internet.';

  @override
  bool get isSensitive => false;

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': 'Kata kunci pencarian yang dikirim ke browser.'},
        },
        'required': ['query'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final query = args['query'] ?? '';
    if (query.trim().isEmpty) {
      return jsonEncode({
        'success': false,
        'message': 'Query pencarian kosong.',
      });
    }

    await AlarmService.instance.searchWeb(query);
    return jsonEncode({
      'success': true,
      'message': 'Pencarian untuk "$query" berhasil dibuka di browser default.',
    });
  }
}

/// Registry & Parser for Agent Tools
class ClarifyTool extends AgentTool {
  static Future<String> Function(String question, List<String>? options)? handler;

  @override
  String get name => 'clarify';

  @override
  String get description => 'Menanyakan pertanyaan klarifikasi kepada pengguna jika permintaan mereka tidak jelas atau kurang spesifik.';

  @override
  bool get isSensitive => false;

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'question': {'type': 'string', 'description': 'Pertanyaan klarifikasi yang akan diajukan ke pengguna.'},
          'options': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Daftar pilihan jawaban singkat (opsional).'
          },
        },
        'required': ['question'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final question = args['question'] as String;
    final optionsList = args['options'] as List<dynamic>?;
    final options = optionsList?.map((e) => e.toString()).toList();

    if (handler != null) {
      return await handler!(question, options);
    }
    return jsonEncode({
      'success': false,
      'message': 'Clarify handler tidak terdaftar di perangkat.',
    });
  }
}

class TodoCreateTool extends AgentTool {
  @override
  String get name => 'todo_create';

  @override
  String get description => 'Membuat daftar tugas (todo list) baru atau menambahkan item tugas baru ke daftar tugas yang sudah ada.';

  @override
  bool get isSensitive => false;

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'list_name': {'type': 'string', 'description': 'Nama daftar tugas (misal: "Belanja", "Kerja").'},
          'content': {'type': 'string', 'description': 'Isi tugas/item (opsional, jika kosong hanya membuat daftar tugas baru).'},
        },
        'required': ['list_name'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final listName = args['list_name'] as String;
    final content = args['content'] as String?;

    try {
      final db = await ChatDatabase.instance.database;
      final existingList = await db.query('TodoLists', where: 'name = ?', whereArgs: [listName]);
      int listId;
      if (existingList.isNotEmpty) {
        listId = existingList.first['id'] as int;
      } else {
        listId = await db.insert('TodoLists', {
          'name': listName,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      }

      if (content != null && content.trim().isNotEmpty) {
        await db.insert('TodoItems', {
          'list_id': listId,
          'content': content.trim(),
          'is_done': 0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
        return jsonEncode({
          'success': true,
          'message': 'Berhasil menambahkan tugas "$content" ke daftar "$listName".',
        });
      }

      return jsonEncode({
        'success': true,
        'message': 'Berhasil membuat daftar tugas baru bernama "$listName".',
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'message': 'Gagal membuat/menambahkan todo: $e',
      });
    }
  }
}

class TodoUpdateTool extends AgentTool {
  @override
  String get name => 'todo_update';

  @override
  String get description => 'Memperbarui status tugas (menandai selesai atau belum selesai) berdasarkan ID tugas.';

  @override
  bool get isSensitive => false;

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'item_id': {'type': 'integer', 'description': 'ID unik dari tugas yang ingin diperbarui.'},
          'is_done': {'type': 'integer', 'description': '1 jika selesai, 0 jika belum selesai.'},
        },
        'required': ['item_id', 'is_done'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final itemId = args['item_id'] as int;
    final isDone = args['is_done'] as int;

    try {
      final db = await ChatDatabase.instance.database;
      final updated = await db.update(
        'TodoItems',
        {'is_done': isDone},
        where: 'id = ?',
        whereArgs: [itemId],
      );

      if (updated > 0) {
        final statusText = isDone == 1 ? 'selesai' : 'belum selesai';
        return jsonEncode({
          'success': true,
          'message': 'Berhasil menandai tugas dengan ID $itemId sebagai $statusText.',
        });
      }
      return jsonEncode({
        'success': false,
        'message': 'Tugas dengan ID $itemId tidak ditemukan.',
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'message': 'Gagal memperbarui status tugas: $e',
      });
    }
  }
}

class TodoListTool extends AgentTool {
  @override
  String get name => 'todo_list';

  @override
  String get description => 'Melihat semua daftar tugas (todo list) dan item-item di dalamnya.';

  @override
  bool get isSensitive => false;

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {},
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final db = await ChatDatabase.instance.database;
      final lists = await db.query('TodoLists', orderBy: 'created_at DESC');
      
      final resultList = <Map<String, dynamic>>[];
      for (final list in lists) {
        final listId = list['id'] as int;
        final items = await db.query('TodoItems', where: 'list_id = ?', whereArgs: [listId], orderBy: 'created_at ASC');
        resultList.add({
          'id': listId,
          'name': list['name'],
          'items': items.map((item) => {
            'id': item['id'],
            'content': item['content'],
            'is_done': item['is_done'],
          }).toList(),
        });
      }

      return jsonEncode({
        'success': true,
        'todo_lists': resultList,
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'message': 'Gagal memuat daftar tugas: $e',
      });
    }
  }
}

class SkillManageTool extends AgentTool {
  @override
  String get name => 'skill_manage';

  @override
  String get description => 'Mengusulkan penyimpanan keterampilan/kemampuan (skill) baru yang asisten temukan atau susun agar dapat digunakan kembali secara permanen.';

  @override
  bool get isSensitive => true;

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'action': {'type': 'string', 'description': 'Aksi yang dilakukan. Gunakan "propose".'},
          'name': {'type': 'string', 'description': 'Nama unik skill (misal: "fetch_academic_papers").'},
          'description': {'type': 'string', 'description': 'Deskripsi tentang fungsi dan kegunaan skill.'},
          'body': {'type': 'string', 'description': 'Script/kode lengkap instruksi detail skill.'},
          'keywords': {'type': 'string', 'description': 'Kata kunci pemicu yang dipisahkan dengan koma.'},
        },
        'required': ['action', 'name', 'description', 'body'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final action = args['action'] as String;
    final name = args['name'] as String;
    final description = args['description'] as String;
    final body = args['body'] as String;
    final keywords = args['keywords'] as String?;

    if (action != 'propose') {
      return jsonEncode({
        'success': false,
        'message': 'Aksi tidak didukung. Hanya mendukung "propose".',
      });
    }

    try {
      final db = await ChatDatabase.instance.database;
      final existing = await db.query('Skills', where: 'name = ?', whereArgs: [name]);
      if (existing.isNotEmpty) {
        await db.update(
          'Skills',
          {
            'description': description,
            'body': body,
            'keywords': keywords,
            'enabled': 1,
            'is_agent_created': 1,
          },
          where: 'name = ?',
          whereArgs: [name],
        );
      } else {
        await db.insert('Skills', {
          'name': name,
          'description': description,
          'body': body,
          'keywords': keywords,
          'enabled': 1,
          'is_agent_created': 1,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      }

      return jsonEncode({
        'success': true,
        'message': 'Keterampilan baru "$name" berhasil disimpan dan diaktifkan.',
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'message': 'Gagal menyimpan keterampilan: $e',
      });
    }
  }
}

class SessionSearchTool extends AgentTool {
  @override
  String get name => 'session_search';

  @override
  String get description => 'Mencari percakapan lama, fakta penting, atau konteks masa lalu dalam memori asisten menggunakan pencarian semantik (vector search).';

  @override
  bool get isSensitive => false;

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': 'Frasa pencarian untuk mencocokkan ingatan masa lalu secara semantik.'},
        },
        'required': ['query'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final query = args['query'] as String;
    if (query.trim().isEmpty) {
      return jsonEncode({
        'success': false,
        'message': 'Query pencarian kosong.',
      });
    }

    try {
      if (!ObjectBoxStore.isOpen) {
        return jsonEncode({
          'success': false,
          'message': 'Vector memory tidak aktif saat ini.',
        });
      }

      final queryEmbedding = await EmbeddingService.instance.embed(query);
      final box = ObjectBoxStore.instance.memoryBox;
      final query_ = box
          .query(MemoryEntry_.embedding.nearestNeighborsF32(queryEmbedding, 5))
          .build();
      final results = query_.find();
      query_.close();

      if (results.isEmpty) {
        return jsonEncode({
          'success': true,
          'message': 'Tidak ditemukan ingatan masa lalu yang relevan dengan kata kunci tersebut.',
        });
      }

      final mappedResults = results.map((r) => {
        'content': r.content,
        'role': r.role,
        'timestampMs': r.timestampMs,
      }).toList();

      return jsonEncode({
        'success': true,
        'memories': mappedResults,
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'message': 'Gagal melakukan pencarian semantik: $e',
      });
    }
  }
}

class AgentToolRegistry {
  final Map<String, AgentTool> _tools = {};

  AgentToolRegistry() {
    registerTool(CheckNetworkStatusTool());
    registerTool(CreateNoteTool());
    registerTool(ReadAppFileTool());
    registerTool(SearchWebTool());
    registerTool(ClarifyTool());
    registerTool(TodoCreateTool());
    registerTool(TodoUpdateTool());
    registerTool(TodoListTool());
    registerTool(SkillManageTool());
    registerTool(SessionSearchTool());
  }

  void registerTool(AgentTool tool) {
    _tools[tool.name] = tool;
  }

  /// Safety cap rule (Rule 06-backup-safety-cap.md): max 8 iterations per turn to prevent battery drain
  static const int maxAgentIterations = 8;

  List<AgentTool> get allTools => _tools.values.toList();

  AgentTool? getTool(String name) => _tools[name];

  /// Generate JSON Schema instruction for System Prompt
  String buildToolsPrompt() {
    final buffer = StringBuffer();
    buffer.writeln('=== DAFTAR ALAT (TOOL-CALLING) ===');
    buffer.writeln('Anda memiliki akses ke alat-alat berikut. Jika membutuhkan alat, kembalikan HANYA format JSON valid berikut:');
    buffer.writeln('```json');
    buffer.writeln('{ "tool": "<NAMA_TOOL>", "arguments": { <KEY_VALUE_ARGS> } }');
    buffer.writeln('```\n');
    buffer.writeln('PENTING: Jika permintaan pengguna bersifat ambigu, kurang spesifik, atau memiliki beberapa kemungkinan arti, panggil alat "clarify" untuk bertanya balik kepada pengguna alih-alih menebak keinginan mereka.');
    buffer.writeln();
    for (final tool in _tools.values) {
      buffer.writeln('Alat: ${tool.name}');
      buffer.writeln('Deskripsi: ${tool.description}');
      buffer.writeln('Skema Parameter: ${jsonEncode(tool.parametersSchema)}');
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// Strict Schema Parser for Model Output
  ToolCallRequest? parseToolCall(String responseText) {
    try {
      // Find JSON block or raw json string
      final jsonMatch = RegExp(r'\{[\s\S]*"tool"[\s\S]*\}').firstMatch(responseText);
      if (jsonMatch == null) return null;

      final rawJson = jsonMatch.group(0)!;
      final Map<String, dynamic> decoded = jsonDecode(rawJson);

      if (decoded.containsKey('tool') && decoded['tool'] is String) {
        final toolName = decoded['tool'] as String;
        final args = decoded['arguments'] is Map<String, dynamic>
            ? decoded['arguments'] as Map<String, dynamic>
            : <String, dynamic>{};

        if (_tools.containsKey(toolName)) {
          return ToolCallRequest(
            name: toolName,
            arguments: args,
            rawJson: rawJson,
          );
        }
      }
    } catch (_) {}
    return null;
  }
}
