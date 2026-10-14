import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:aura_core/storage/chat_models.dart';
import 'package:aura_core/src/llm_router/router_client.dart';
import 'package:aura_core/src/llm_router/stall_detection.dart';

void main() {
  group('router_client - evaluateLocalFallback', () {
    test('offline or socket exception immediately triggers fallback', () {
      final decision = evaluateLocalFallback(
        error: const SocketException('Connection failed'),
        attemptIndex: 0,
        totalModelsInCombo: 3,
      );

      expect(decision.shouldFallback, isTrue);
      expect(decision.trigger, equals(FallbackTrigger.offline));
      expect(decision.userFacingMessage, contains('Koneksi internet terputus'));
    });

    test('auth failure (401) does not fallback if alternative model exists in combo', () {
      final decision = evaluateLocalFallback(
        error: const HttpException('401 Unauthorized'),
        attemptIndex: 0,
        totalModelsInCombo: 2,
        statusCode: 401,
      );

      expect(decision.shouldFallback, isFalse);
      expect(decision.trigger, equals(FallbackTrigger.none));
    });

    test('auth failure (401) triggers fallback on last combo model', () {
      final decision = evaluateLocalFallback(
        error: const HttpException('401 Unauthorized'),
        attemptIndex: 1,
        totalModelsInCombo: 2,
        statusCode: 401,
      );

      expect(decision.shouldFallback, isTrue);
      expect(decision.trigger, equals(FallbackTrigger.authFailure));
      expect(decision.userFacingMessage, contains('API Key cloud ditolak'));
    });

    test('quota / rate limit (429) triggers fallback on last combo model', () {
      final decision = evaluateLocalFallback(
        error: const HttpException('429 Too Many Requests'),
        attemptIndex: 0,
        totalModelsInCombo: 1,
        statusCode: 429,
        errorText: 'Resource has been exhausted (e.g. check quota)',
      );

      expect(decision.shouldFallback, isTrue);
      expect(decision.trigger, equals(FallbackTrigger.quotaExhausted));
      expect(decision.userFacingMessage, contains('Kuota cloud gratis habis'));
    });

    test('stall timeout on last model triggers fallback with stall message', () {
      final decision = evaluateLocalFallback(
        error: const StallTimeoutException(timeout: Duration(seconds: 30)),
        attemptIndex: 0,
        totalModelsInCombo: 1,
      );

      expect(decision.shouldFallback, isTrue);
      expect(decision.trigger, equals(FallbackTrigger.stallTimeout));
      expect(decision.userFacingMessage, contains('Respon cloud terhenti'));
    });

    test('generic error on last model triggers comboExhausted fallback', () {
      final decision = evaluateLocalFallback(
        error: Exception('Internal server error 500'),
        attemptIndex: 1,
        totalModelsInCombo: 2,
        statusCode: 500,
      );

      expect(decision.shouldFallback, isTrue);
      expect(decision.trigger, equals(FallbackTrigger.comboExhausted));
      expect(decision.userFacingMessage, contains('Seluruh layanan cloud sibuk'));
    });
  });

  group('router_client - Conversion Helpers', () {
    test('convertAuraToOpenAIMessages handles text, tool_calls, and tool_responses', () {
      final messages = [
        ChatMessage(
          id: 1,
          sessionId: 10,
          role: MessageRole.user,
          content: 'Cari cuaca Jakarta',
          timestamp: DateTime.now(),
        ),
        ChatMessage(
          id: 2,
          sessionId: 10,
          role: MessageRole.assistant,
          content: 'Saya akan periksa cuaca.',
          timestamp: DateTime.now(),
          toolCallJson: jsonEncode([
            {
              'id': 'call_weather_1',
              'type': 'function',
              'function': {'name': 'get_weather', 'arguments': '{"city":"Jakarta"}'}
            }
          ]),
        ),
        ChatMessage(
          id: 3,
          sessionId: 10,
          role: MessageRole.tool,
          content: 'Cerah berawan 30°C',
          timestamp: DateTime.now(),
          toolCallId: 'call_weather_1',
          toolName: 'get_weather',
          toolResult: 'Cerah berawan 30°C',
        ),
      ];

      final openAi = convertAuraToOpenAIMessages(messages, systemPrompt: 'Anda AURA.');
      expect(openAi.length, equals(4));
      expect(openAi[0]['role'], equals('system'));
      expect(openAi[1]['role'], equals('user'));
      expect(openAi[2]['role'], equals('assistant'));
      expect(openAi[2]['tool_calls'], isA<List>());
      expect(openAi[3]['role'], equals('tool'));
      expect(openAi[3]['tool_call_id'], equals('call_weather_1'));
      expect(openAi[3]['content'], equals('Cerah berawan 30°C'));
    });

    test('convertAuraToGeminiPayload handles system, functionCall, and functionResponse', () {
      final messages = [
        ChatMessage(
          id: 1,
          sessionId: 10,
          role: MessageRole.user,
          content: 'Hitung 25 * 4',
          timestamp: DateTime.now(),
        ),
        ChatMessage(
          id: 2,
          sessionId: 10,
          role: MessageRole.assistant,
          content: '',
          timestamp: DateTime.now(),
          toolCallJson: jsonEncode([
            {
              'function': {'name': 'calculator', 'arguments': {'expr': '25 * 4'}}
            }
          ]),
        ),
        ChatMessage(
          id: 3,
          sessionId: 10,
          role: MessageRole.tool,
          content: '100',
          timestamp: DateTime.now(),
          toolCallId: 'call_calc_1',
          toolName: 'calculator',
          toolResult: '100',
        ),
      ];

      final gemini = convertAuraToGeminiPayload(
        messages,
        systemPrompt: 'System instruction AURA',
      );

      expect(gemini['systemInstruction']['parts'][0]['text'], equals('System instruction AURA'));
      final contents = gemini['contents'] as List;
      expect(contents.length, equals(3));

      // 1. user message
      expect(contents[0]['role'], equals('user'));
      expect(contents[0]['parts'][0]['text'], equals('Hitung 25 * 4'));

      // 2. assistant tool call
      expect(contents[1]['role'], equals('model'));
      expect(contents[1]['parts'][0]['functionCall']['name'], equals('calculator'));
      expect(contents[1]['parts'][0]['functionCall']['args']['expr'], equals('25 * 4'));

      // 3. tool result
      expect(contents[2]['role'], equals('user'));
      expect(contents[2]['parts'][0]['functionResponse']['name'], equals('calculator'));
      expect(contents[2]['parts'][0]['functionResponse']['response']['result'], equals('100'));
    });
  });

  group('router_client - LlmRouterClient Execution', () {
    test('tracks cooldown per-provider correctly', () async {
      final mockHttp = MockClient((request) async {
        return http.Response('{"error": {"message": "rate limit exceeded"}}', 429);
      });
      final client = LlmRouterClient(httpClient: mockHttp);
      expect(client.isProviderInCooldown('gemini'), isFalse);

      final messages = [
        ChatMessage(
          id: 1,
          sessionId: 1,
          role: MessageRole.user,
          content: 'Test cooldown',
          timestamp: DateTime.now(),
        )
      ];

      await expectLater(
        () => client.streamGenerate(
          messages: messages,
          modelOrCombo: 'gemini-2.5-flash',
          apiKeys: {'gemini': 'key'},
        ).drain(),
        throwsA(isA<LocalFallbackException>()),
      );

      expect(client.isProviderInCooldown('gemini'), isTrue);
      final expiry = client.getCooldownExpiry('gemini');
      expect(expiry, isNotNull);
      expect(expiry!.isAfter(DateTime.now()), isTrue);

      client.clearCooldown('gemini');
      expect(client.isProviderInCooldown('gemini'), isFalse);
    });

    test('streams Gemini SSE response successfully', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.host, equals('generativelanguage.googleapis.com'));
        const sseData = 'data: {"candidates":[{"content":{"parts":[{"text":"Halo dari Gemini!"}]}}]}\n\n'
            'data: {"candidates":[{"content":{"parts":[{"text":" Siap membantu."}]}}]}\n\n';
        return http.Response(sseData, 200, headers: {'content-type': 'text/event-stream'});
      });

      final router = LlmRouterClient(httpClient: mockHttp);
      final messages = [
        ChatMessage(
          id: 1,
          sessionId: 1,
          role: MessageRole.user,
          content: 'Halo',
          timestamp: DateTime.now(),
        )
      ];

      final stream = router.streamGenerate(
        messages: messages,
        modelOrCombo: 'gemini-2.5-flash',
        apiKeys: {'gemini': 'valid_gemini_key'},
      );

      final events = await stream.toList();
      final text = events.whereType<RouterTextDelta>().map((e) => e.text).join();
      expect(text, equals('Halo dari Gemini! Siap membantu.'));
    });

    test('streams OpenAI-compatible response successfully', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.host, equals('api.openai.com'));
        const sseData = 'data: {"choices":[{"delta":{"content":"Halo "}}]}\n\n'
            'data: {"choices":[{"delta":{"content":"OpenAI!"}}]}\n\n'
            'data: [DONE]\n\n';
        return http.Response(sseData, 200, headers: {'content-type': 'text/event-stream'});
      });

      final router = LlmRouterClient(httpClient: mockHttp);
      final messages = [
        ChatMessage(
          id: 1,
          sessionId: 1,
          role: MessageRole.user,
          content: 'Halo',
          timestamp: DateTime.now(),
        )
      ];

      final stream = router.streamGenerate(
        messages: messages,
        modelOrCombo: 'openai/gpt-4o-mini',
        apiKeys: {'openai': 'valid_openai_key'},
      );

      final events = await stream.toList();
      final text = events.whereType<RouterTextDelta>().map((e) => e.text).join();
      expect(text, equals('Halo OpenAI!'));
    });

    test('streams OpenAI-compatible tool call as RouterToolCall event', () async {
      final mockHttp = MockClient((request) async {
        final chunk1 = 'data: ${jsonEncode({
          'id': 'chatcmpl-tc1',
          'choices': [
            {
              'index': 0,
              'delta': {
                'tool_calls': [
                  {
                    'index': 0,
                    'id': 'call_calc123',
                    'type': 'function',
                    'function': {
                      'name': 'calculator',
                      'arguments': '{"expr": ',
                    }
                  }
                ]
              },
              'finish_reason': null,
            }
          ]
        })}\n\n';

        final chunk2 = 'data: ${jsonEncode({
          'id': 'chatcmpl-tc1',
          'choices': [
            {
              'index': 0,
              'delta': {
                'tool_calls': [
                  {
                    'index': 0,
                    'function': {
                      'arguments': '"25 * 4"}',
                    }
                  }
                ]
              },
              'finish_reason': 'tool_calls',
            }
          ]
        })}\n\n';

        final sseData = '$chunk1$chunk2\ndata: [DONE]\n\n';
        return http.Response(sseData, 200, headers: {'content-type': 'text/event-stream'});
      });

      final router = LlmRouterClient(httpClient: mockHttp);
      final messages = [
        ChatMessage(
          id: 1,
          sessionId: 1,
          role: MessageRole.user,
          content: 'Hitung 25 * 4',
          timestamp: DateTime.now(),
        )
      ];

      final events = await router.streamGenerate(
        messages: messages,
        modelOrCombo: 'openai/gpt-4o-mini',
        apiKeys: {'openai': 'valid_openai_key'},
      ).toList();

      final toolCalls = events.whereType<RouterToolCall>().toList();
      expect(toolCalls, hasLength(1));
      expect(toolCalls[0].id, equals('call_calc123'));
      expect(toolCalls[0].name, equals('calculator'));
      expect(toolCalls[0].argumentsJson, contains('25 * 4'));
    });

    test('streams Gemini tool call (functionCall) as RouterToolCall event', () async {
      final mockHttp = MockClient((request) async {
        const sseData = 'data: {"candidates":[{"content":{"parts":[{"functionCall":{"name":"web_search","args":{"query":"AURA agent"}}}]},"finishReason":"STOP"}]}\n\n';
        return http.Response(sseData, 200, headers: {'content-type': 'text/event-stream'});
      });

      final router = LlmRouterClient(httpClient: mockHttp);
      final messages = [
        ChatMessage(
          id: 1,
          sessionId: 1,
          role: MessageRole.user,
          content: 'Cari info AURA',
          timestamp: DateTime.now(),
        )
      ];

      final events = await router.streamGenerate(
        messages: messages,
        modelOrCombo: 'gemini-2.5-flash',
        apiKeys: {'gemini': 'valid_key'},
      ).toList();

      final toolCalls = events.whereType<RouterToolCall>().toList();
      expect(toolCalls, hasLength(1));
      expect(toolCalls[0].name, equals('web_search'));
      expect(toolCalls[0].argumentsJson, contains('AURA agent'));
    });

    test('streams Anthropic SSE response with x-api-key and anthropic-version headers', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.host, equals('api.anthropic.com'));
        expect(request.headers['x-api-key'], equals('claude_secret_key'));
        expect(request.headers['anthropic-version'], equals('2023-06-01'));

        const sseData = 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\n\n'
            'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Halo dari Claude!"}}\n\n'
            'event: message_stop\ndata: {"type":"message_stop"}\n\n';
        return http.Response(sseData, 200, headers: {'content-type': 'text/event-stream'});
      });

      final router = LlmRouterClient(httpClient: mockHttp);
      final messages = [
        ChatMessage(
          id: 1,
          sessionId: 1,
          role: MessageRole.user,
          content: 'Halo Claude',
          timestamp: DateTime.now(),
        )
      ];

      final events = await router.streamGenerate(
        messages: messages,
        modelOrCombo: 'anthropic/claude-3-5-sonnet',
        apiKeys: {'anthropic': 'claude_secret_key'},
      ).toList();

      final text = events.whereType<RouterTextDelta>().map((e) => e.text).join();
      expect(text, equals('Halo dari Claude!'));
    });

    test('parses combo containing slashes into individual models correctly', () async {
      final requestedModels = <String>[];
      final mockHttp = MockClient((request) async {
        if (request.url.host.contains('googleapis')) {
          requestedModels.add('gemini');
          return http.Response('{"error": {"message": "quota exceeded"}}', 429);
        } else {
          requestedModels.add('openai');
          const sseData = 'data: {"choices":[{"delta":{"content":"Success from OpenAI"}}]}\n\n';
          return http.Response(sseData, 200, headers: {'content-type': 'text/event-stream'});
        }
      });

      final router = LlmRouterClient(httpClient: mockHttp);
      final messages = [
        ChatMessage(
          id: 1,
          sessionId: 1,
          role: MessageRole.user,
          content: 'Test',
          timestamp: DateTime.now(),
        )
      ];

      // String with slashes inside comma-separated combo
      final events = await router.streamGenerate(
        messages: messages,
        modelOrCombo: 'gemini/gemini-2.5-flash,openai/gpt-4o-mini',
        apiKeys: {'gemini': 'gemini_key', 'openai': 'openai_key'},
      ).toList();

      expect(requestedModels, equals(['gemini', 'openai']));
      final text = events.whereType<RouterTextDelta>().map((e) => e.text).join();
      expect(text, equals('Success from OpenAI'));
    });

    test('falls back to local when 429 quota is reached on single model', () async {
      final mockHttp = MockClient((request) async {
        return http.Response('{"error": {"message": "Resource has been exhausted (rate limit / quota)"}}', 429);
      });

      final router = LlmRouterClient(httpClient: mockHttp);
      final messages = [
        ChatMessage(
          id: 1,
          sessionId: 1,
          role: MessageRole.user,
          content: 'Test',
          timestamp: DateTime.now(),
        )
      ];

      await expectLater(
        () => router.streamGenerate(
          messages: messages,
          modelOrCombo: 'gemini-2.5-flash',
          apiKeys: {'gemini': 'test_key'},
        ).drain(),
        throwsA(
          isA<LocalFallbackException>().having(
            (e) => e.decision.trigger,
            'trigger',
            equals(FallbackTrigger.quotaExhausted),
          ),
        ),
      );

      // Verify cooldown was recorded for gemini
      expect(router.isProviderInCooldown('gemini'), isTrue);
    });

    test('skips provider in cooldown and uses next healthy provider in combo', () async {
      var callCount = 0;
      final mockHttp = MockClient((request) async {
        callCount++;
        if (request.url.host.contains('googleapis')) {
          // Gemini returns 429
          return http.Response('{"error": {"message": "quota exceeded"}}', 429);
        } else {
          // OpenAI returns 200
          const sseData = 'data: {"choices":[{"delta":{"content":"Success from OpenAI"}}]}\n\n';
          return http.Response(sseData, 200, headers: {'content-type': 'text/event-stream'});
        }
      });

      final router = LlmRouterClient(httpClient: mockHttp);
      final messages = [
        ChatMessage(
          id: 1,
          sessionId: 1,
          role: MessageRole.user,
          content: 'Test combo failover',
          timestamp: DateTime.now(),
        )
      ];

      // Combo: gemini then openai
      final events = await router.streamGenerate(
        messages: messages,
        modelOrCombo: 'gemini-2.5-flash,openai/gpt-4o-mini',
        apiKeys: {'gemini': 'key_gemini', 'openai': 'key_openai'},
      ).toList();

      final text = events.whereType<RouterTextDelta>().map((e) => e.text).join();
      expect(text, equals('Success from OpenAI'));
      expect(callCount, equals(2));
      expect(router.isProviderInCooldown('gemini'), isTrue);
      expect(router.isProviderInCooldown('openai'), isFalse);

      // On next turn: gemini is in cooldown, so it should directly call openai (callCount = 3)
      final eventsTurn2 = await router.streamGenerate(
        messages: messages,
        modelOrCombo: 'gemini-2.5-flash,openai/gpt-4o-mini',
        apiKeys: {'gemini': 'key_gemini', 'openai': 'key_openai'},
      ).toList();

      final textTurn2 = eventsTurn2.whereType<RouterTextDelta>().map((e) => e.text).join();
      expect(textTurn2, equals('Success from OpenAI'));
      expect(callCount, equals(3)); // Only 1 additional call to openai, gemini was skipped!
    });

    test('resolves non-prefixed model via active provider in apiKeys', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.host, equals('api.groq.com'));
        const sseData =
            'data: {"choices":[{"delta":{"content":"Groq response"}}]}\n\n'
            'data: [DONE]\n\n';
        return http.Response(sseData, 200, headers: {'content-type': 'text/event-stream'});
      });

      final router = LlmRouterClient(httpClient: mockHttp);
      final messages = [
        ChatMessage(
          id: 1,
          sessionId: 1,
          role: MessageRole.user,
          content: 'Test bare model',
          timestamp: DateTime.now(),
        )
      ];

      // 'llama-3.3-70b-versatile' has no slash and no 'gpt'/'gemini' prefix.
      // Must resolve via isProviderActive using active 'groq' in apiKeys.
      final events = await router.streamGenerate(
        messages: messages,
        modelOrCombo: 'llama-3.3-70b-versatile',
        apiKeys: {'groq': 'key_groq'},
      ).toList();

      final text = events.whereType<RouterTextDelta>().map((e) => e.text).join();
      expect(text, equals('Groq response'));
    });
  });
}
