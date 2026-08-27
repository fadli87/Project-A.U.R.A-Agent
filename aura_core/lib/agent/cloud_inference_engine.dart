import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

abstract class CloudInferenceEngine {
  Future<bool> validateKey(String apiKey);
  Stream<String> generate({
    required List<Map<String, dynamic>> messages,
    required double temperature,
    required int maxTokens,
    required String apiKey,
  });
}

class GeminiInferenceEngine implements CloudInferenceEngine {
  final String modelName;
  GeminiInferenceEngine({this.modelName = 'gemini-3.5-flash'});

  @override
  Future<bool> validateKey(String apiKey) async {
    if (apiKey.trim().isEmpty) return false;
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models',
      );
      final res = await http.get(
        url,
        headers: {'x-goog-api-key': apiKey.trim()},
      ).timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<String> generate({
    required List<Map<String, dynamic>> messages,
    required double temperature,
    required int maxTokens,
    required String apiKey,
  }) {
    final controller = StreamController<String>();

    // Format messages for Gemini API contents format
    final contents = <Map<String, dynamic>>[];
    String? systemInstructionText;

    for (final msg in messages) {
      final role = msg['role'];
      final content = msg['content'] as String;

      if (role == 'system') {
        systemInstructionText = content;
      } else {
        final geminiRole = (role == 'assistant' || role == 'model') ? 'model' : 'user';
        contents.add({
          'role': geminiRole,
          'parts': [{'text': content}],
        });
      }
    }

    final payload = {
      'contents': contents,
      if (systemInstructionText != null && systemInstructionText.isNotEmpty)
        'systemInstruction': {
          'parts': [{'text': systemInstructionText}]
        },
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
      }
    };

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:streamGenerateContent?alt=sse',
    );

    final client = http.Client();
    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..headers['x-goog-api-key'] = apiKey.trim()
      ..body = jsonEncode(payload);

    client.send(request).then((response) async {
      if (response.statusCode != 200) {
        controller.addError(Exception('Gemini API returned status code ${response.statusCode}'));
        controller.close();
        client.close();
        return;
      }

      final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
      try {
        await for (final line in stream) {
          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6).trim();
            if (dataStr.isEmpty) continue;
            final data = jsonDecode(dataStr);
            final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
            if (text != null && text.isNotEmpty) {
              controller.add(text);
            }
          }
        }
      } catch (e) {
        controller.addError(e);
      } finally {
        controller.close();
        client.close();
      }
    }).catchError((e) {
      controller.addError(e);
      controller.close();
      client.close();
    });

    return controller.stream;
  }
}

class OpenAIInferenceEngine implements CloudInferenceEngine {
  final String modelName;
  OpenAIInferenceEngine({this.modelName = 'gpt-4o-mini'});

  @override
  Future<bool> validateKey(String apiKey) async {
    if (apiKey.trim().isEmpty) return false;
    try {
      final url = Uri.parse('https://api.openai.com/v1/models');
      final res = await http.get(
        url,
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<String> generate({
    required List<Map<String, dynamic>> messages,
    required double temperature,
    required int maxTokens,
    required String apiKey,
  }) {
    final controller = StreamController<String>();

    final formattedMessages = messages.map((m) {
      return {
        'role': m['role'],
        'content': m['content'],
      };
    }).toList();

    final payload = {
      'model': modelName,
      'messages': formattedMessages,
      'stream': true,
      'temperature': temperature,
      'max_tokens': maxTokens,
    };

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final client = http.Client();
    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..body = jsonEncode(payload);

    client.send(request).then((response) async {
      if (response.statusCode != 200) {
        controller.addError(Exception('OpenAI API returned status code ${response.statusCode}'));
        controller.close();
        client.close();
        return;
      }

      final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
      try {
        await for (final line in stream) {
          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6).trim();
            if (dataStr == '[DONE]') break;
            if (dataStr.isEmpty) continue;
            final data = jsonDecode(dataStr);
            final text = data['choices']?[0]?['delta']?['content'] as String?;
            if (text != null && text.isNotEmpty) {
              controller.add(text);
            }
          }
        }
      } catch (e) {
        controller.addError(e);
      } finally {
        controller.close();
        client.close();
      }
    }).catchError((e) {
      controller.addError(e);
      controller.close();
      client.close();
    });

    return controller.stream;
  }
}
