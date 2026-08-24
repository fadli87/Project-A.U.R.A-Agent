import 'dart:convert';
import 'package:http/http.dart' as http;

class LocalLlmService {
  static Future<List<String>> fetchModels({
    required String baseUrl,
    required String apiType,
  }) async {
    try {
      final sanitizedUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      if (apiType.toLowerCase() == 'ollama') {
        final response = await http.get(Uri.parse('$sanitizedUrl/api/tags')).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final models = data['models'] as List<dynamic>?;
          if (models != null) {
            return models.map((m) => m['name'] as String).toList();
          }
        }
      } else {
        // OpenAI / LM Studio / llama-server
        final response = await http.get(Uri.parse('$sanitizedUrl/models')).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final models = data['data'] as List<dynamic>?;
          if (models != null) {
            return models.map((m) => m['id'] as String).toList();
          }
        }
      }
    } catch (_) {
      // Suppress error and return empty list
    }
    return [];
  }

  static Future<Map<String, dynamic>> generateChatReply({
    required String baseUrl,
    required String apiType,
    required String model,
    required List<Map<String, String>> messages,
  }) async {
    final startTime = DateTime.now();
    String replyContent = '';
    int promptTokens = 0;
    int completionTokens = 0;
    final sanitizedUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

    try {
      if (apiType.toLowerCase() == 'ollama') {
        final response = await http.post(
          Uri.parse('$sanitizedUrl/api/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': model,
            'messages': messages,
            'stream': false,
          }),
        ).timeout(const Duration(minutes: 5));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          replyContent = data['message']?['content'] ?? '';
          promptTokens = data['prompt_eval_count'] ?? 0;
          completionTokens = data['eval_count'] ?? 0;
        } else {
          throw Exception('Status Code ${response.statusCode}');
        }
      } else {
        // OpenAI / LM Studio / llama-server
        final response = await http.post(
          Uri.parse('$sanitizedUrl/chat/completions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': model,
            'messages': messages,
            'stream': false,
          }),
        ).timeout(const Duration(minutes: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          replyContent = data['choices']?[0]?['message']?['content'] ?? '';
          promptTokens = data['usage']?['prompt_tokens'] ?? 0;
          completionTokens = data['usage']?['completion_tokens'] ?? 0;
        } else {
          throw Exception('Status Code ${response.statusCode}');
        }
      }
    } catch (e) {
      replyContent = 'Error: Gagal menghubungi server LLM lokal. Pastikan server Anda berjalan di $baseUrl.\nDetail: $e';
    }

    final duration = DateTime.now().difference(startTime);
    return {
      'content': replyContent,
      'promptTokens': promptTokens,
      'completionTokens': completionTokens,
      'durationMs': duration.inMilliseconds,
    };
  }
}
