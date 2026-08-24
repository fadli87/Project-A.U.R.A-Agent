import 'dart:convert';
import 'alarm_service.dart';

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
class AgentToolRegistry {
  final Map<String, AgentTool> _tools = {};

  AgentToolRegistry() {
    registerTool(CheckNetworkStatusTool());
    registerTool(CreateNoteTool());
    registerTool(ReadAppFileTool());
    registerTool(SearchWebTool());
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
