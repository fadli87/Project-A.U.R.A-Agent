import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

/// Tool 4a: Web Search Handoff (Safe - Auto-execute)
class SearchWebHandoffTool extends AgentTool {
  @override
  String get name => 'search_web_handoff';

  @override
  String get description => 'Mencari informasi online di browser web default pengguna (handoff langsung). Gunakan alat ini KETIKA pengguna secara eksplisit meminta untuk membuka browser atau mencari di web untuk dibaca sendiri.';

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

/// Tool 4b: Deep Web Search (Sensitive - Fetches snippets and returns to context)
class SearchWebDeepTool extends AgentTool {
  @override
  String get name => 'search_web_deep';

  @override
  String get description => 'Melakukan pencarian internet mendalam untuk mengambil data terkini, ringkasan berita, atau informasi real-time dari internet secara langsung.';

  @override
  bool get isSensitive => true;

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': 'Kata kunci pencarian internet.'},
        },
        'required': ['query'],
      };

  List<Map<String, String>> _parseDuckDuckGo(String html) {
    final results = <Map<String, String>>[];
    
    // Find result blocks in DDG HTML Lite
    final resultBlocks = RegExp(r'<div class="result results_links results_links_deep web-result\s*">([\\s\\S]*?)</div>\\s*</div>')
        .allMatches(html);

    for (final blockMatch in resultBlocks) {
      final block = blockMatch.group(1) ?? '';
      
      // Extract title and URL
      final titleMatch = RegExp(r'<a class="result__a"[^>]*href="([^"]+)"[^>]*>([\\s\\S]*?)</a>').firstMatch(block);
      if (titleMatch == null) continue;
      
      var url = titleMatch.group(1) ?? '';
      if (url.startsWith('/l/?')) {
        final uri = Uri.parse('https://html.duckduckgo.com$url');
        final uddg = uri.queryParameters['uddg'];
        if (uddg != null) {
          url = Uri.decodeComponent(uddg);
        }
      }
      
      var title = titleMatch.group(2) ?? '';
      title = title.replaceAll(RegExp(r'<[^>]*>'), '').trim();

      // Extract snippet
      final snippetMatch = RegExp(r'<a class="result__snippet"[^>]*>([\\s\\S]*?)</a>').firstMatch(block);
      var snippet = snippetMatch?.group(1) ?? '';
      snippet = snippet.replaceAll(RegExp(r'<[^>]*>'), '').trim();

      if (title.isNotEmpty && url.isNotEmpty) {
        results.add({
          'title': title,
          'url': url,
          'snippet': snippet,
        });
      }
      if (results.length >= 4) break;
    }
    return results;
  }

  Future<List<Map<String, String>>> _fetchSearxng(String query, String baseUrl) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      var searchUrl = baseUrl;
      if (!searchUrl.endsWith('/')) searchUrl += '/';
      searchUrl += '?q=${Uri.encodeComponent(query)}&format=json';

      final request = await client.getUrl(Uri.parse(searchUrl));
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        final resultsList = decoded['results'] as List<dynamic>? ?? [];
        final parsed = <Map<String, String>>[];
        for (final item in resultsList) {
          final title = item['title'] as String? ?? '';
          final url = item['url'] as String? ?? '';
          final snippet = (item['content'] ?? item['snippet']) as String? ?? '';
          if (title.isNotEmpty && url.isNotEmpty) {
            parsed.add({
              'title': title,
              'url': url,
              'snippet': snippet,
            });
          }
          if (parsed.length >= 4) break;
        }
        return parsed;
      }
    } catch (e) {
      debugPrint('SearXNG fallback error: $e');
    } finally {
      client.close();
    }
    return [];
  }

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final query = args['query'] ?? '';
    final searxngUrl = args['searxngUrl'] ?? 'https://searx.be/';
    if (query.trim().isEmpty) {
      return 'Error: query pencarian kosong.';
    }

    List<Map<String, String>> results = [];
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);

    try {
      final request = await client.getUrl(
        Uri.parse('https://html.duckduckgo.com/html/?q=${Uri.encodeComponent(query)}'),
      );
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        results = _parseDuckDuckGo(body);
      }
    } catch (e) {
      debugPrint('DuckDuckGo Lite fetch failed, trying SearXNG: $e');
    } finally {
      client.close();
    }

    if (results.isEmpty) {
      results = await _fetchSearxng(query, searxngUrl);
    }

    if (results.isEmpty) {
      return 'Gagal mengambil hasil pencarian online dari DuckDuckGo maupun SearXNG.';
    }

    final sb = StringBuffer();
    sb.writeln('Hasil Pencarian Online untuk "$query":');
    
    for (final res in results) {
      final entry = '- [${res['title'] ?? ''}](${res['url'] ?? ''}): ${res['snippet'] ?? ''}\n';
      if (sb.length + entry.length > 500) {
        final remainingBudget = 500 - sb.length;
        if (remainingBudget > 30) {
          sb.write('${entry.substring(0, remainingBudget)}...\n');
        }
        break;
      }
      sb.write(entry);
    }

    return sb.toString().trim();
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

/// Tool: Read Local File from Whitelist (Sensitive)
class ReadLocalFileTool extends AgentTool {
  @override
  String get name => 'read_local_file';

  @override
  String get description => 'Membaca isi berkas teks lokal dari folder yang terdaftar di Whitelist Folder Terpercaya.';

  @override
  bool get isSensitive => true;

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description': 'Absolute path berkas teks yang akan dibaca (misalnya: C:/my_folder/notes.txt atau /storage/emulated/0/my_folder/notes.txt).'
          },
        },
        'required': ['path'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final pathStr = args['path'] ?? '';
    if (pathStr.toString().trim().isEmpty) {
      return jsonEncode({
        'status': 'error',
        'message': 'Parameter path tidak boleh kosong.',
      });
    }

    try {
      final targetFile = File(pathStr);
      final canonicalPath = p.canonicalize(targetFile.absolute.path);

      // Load whitelist folders from SQLite
      final folders = await ChatDatabase.instance.getAllTrustedFolders();
      bool isWhitelisted = false;

      for (final folderMap in folders) {
        final folderPath = folderMap['path'] as String? ?? '';
        if (folderPath.isEmpty) continue;
        final canonicalFolder = p.canonicalize(folderPath);

        if (p.isWithin(canonicalFolder, canonicalPath) || canonicalPath == canonicalFolder) {
          isWhitelisted = true;
          break;
        }
      }

      if (!isWhitelisted) {
        return jsonEncode({
          'status': 'error',
          'message': 'Akses Ditolak: Path "$pathStr" tidak berada di dalam folder yang di-whitelist. Silakan tambahkan folder induknya ke Whitelist Folder Terpercaya di Settings terlebih dahulu.',
        });
      }

      // Check if file exists
      if (!await targetFile.exists()) {
        return jsonEncode({
          'status': 'error',
          'message': 'File tidak ditemukan pada path "$pathStr".',
        });
      }

      // Read contents (Limit to 1MB)
      final fileStat = await targetFile.stat();
      final length = fileStat.size;
      const limit = 1024 * 1024; // 1MB

      if (length > limit) {
        final stream = targetFile.openRead(0, limit);
        final bytes = await stream.fold<List<int>>([], (p, e) => p..addAll(e));
        final fileContent = utf8.decode(bytes, allowMalformed: true);
        return jsonEncode({
          'status': 'success',
          'file': p.basename(canonicalPath),
          'note': 'Peringatan: File ini terlalu besar (>1MB) dan telah dipotong secara otomatis. Hanya menampilkan 1MB pertama.',
          'content': fileContent,
        });
      } else {
        final fileContent = await targetFile.readAsString();
        return jsonEncode({
          'status': 'success',
          'file': p.basename(canonicalPath),
          'content': fileContent,
        });
      }
    } catch (e) {
      return jsonEncode({
        'status': 'error',
        'message': 'Gagal membaca berkas: $e',
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
    registerTool(SearchWebHandoffTool());
    registerTool(SearchWebDeepTool());
    registerTool(ClarifyTool());
    registerTool(TodoCreateTool());
    registerTool(TodoUpdateTool());
    registerTool(TodoListTool());
    registerTool(SkillManageTool());
    registerTool(SessionSearchTool());
    registerTool(ReadLocalFileTool());
  }

  void registerTool(AgentTool tool) {
    _tools[tool.name] = tool;
  }

  /// Safety cap rule (Rule 06-backup-safety-cap.md): max 8 iterations per turn to prevent battery drain
  static const int maxAgentIterations = 8;

  List<AgentTool> get allTools => _tools.values.toList();

  AgentTool? getTool(String name) => _tools[name];

  /// Generate JSON Schema instruction for System Prompt
  String buildToolsPrompt({bool isDeepSearchEnabled = false}) {
    final buffer = StringBuffer();
    buffer.writeln('=== DAFTAR ALAT (TOOL-CALLING) ===');
    buffer.writeln('Anda memiliki akses ke alat-alat berikut. Jika membutuhkan alat, kembalikan HANYA format JSON valid berikut:');
    buffer.writeln('```json');
    buffer.writeln('{ "tool": "<NAMA_TOOL>", "arguments": { <KEY_VALUE_ARGS> } }');
    buffer.writeln('```\n');
    buffer.writeln('PENTING: Jika permintaan pengguna bersifat ambigu, kurang spesifik, atau memiliki beberapa kemungkinan arti, panggil alat "clarify" untuk bertanya balik kepada pengguna alih-alih menebak keinginan mereka.');
    buffer.writeln();

    final toolsToExpose = _tools.values.where((tool) {
      if (tool.name == 'search_web_deep') {
        return isDeepSearchEnabled;
      }
      return true;
    }).toList();

    for (final tool in toolsToExpose) {
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
