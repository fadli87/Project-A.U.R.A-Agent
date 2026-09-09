import 'dart:async';
import 'package:test/test.dart';
import 'package:aura_core/src/llm_router/fusion.dart';
import 'package:aura_core/src/llm_router/models/llm_router_models.dart';

void main() {
  group('fusion - History Flattening & Judge Prompt', () {
    test('flattenToolHistory converts tool results and assistant tool calls to prose', () {
      final messages = [
        {'role': 'user', 'content': 'What is the weather in Jakarta?'},
        {
          'role': 'assistant',
          'content': 'Checking now',
          'tool_calls': [
            {
              'function': {
                'name': 'get_weather',
                'arguments': '{"city":"Jakarta"}',
              }
            }
          ]
        },
        {'role': 'tool', 'content': '{"temp": 32, "condition": "sunny"}'},
      ];

      final flattened = flattenToolHistory(messages);
      expect(flattened.length, equals(3));
      expect(flattened[0]['role'], equals('user'));

      expect(flattened[1]['role'], equals('assistant'));
      expect(flattened[1]['content'], contains('Checking now'));
      expect(flattened[1]['content'], contains('[Call tool get_weather({"city":"Jakarta"})]'));

      expect(flattened[2]['role'], equals('user'));
      expect(flattened[2]['content'], startsWith('[Tool result]'));
      expect(flattened[2]['content'], contains('"temp": 32'));
    });

    test('buildJudgePrompt formats anonymized sources', () {
      final answers = [
        const FusionAnswer(model: 'gpt-4o', text: 'Answer from Model A'),
        const FusionAnswer(model: 'claude-3-5-sonnet', text: 'Answer from Model B'),
      ];

      final prompt = buildJudgePrompt(answers);
      expect(prompt, contains('You are the JUDGE in a model-fusion panel. 2 expert models'));
      expect(prompt, contains('[Source 1]\nAnswer from Model A'));
      expect(prompt, contains('[Source 2]\nAnswer from Model B'));
      expect(prompt, contains('=== PANEL RESPONSES ==='));
      // Model names should NOT be mentioned in the prompt
      expect(prompt.contains('gpt-4o'), isFalse);
      expect(prompt.contains('claude-3-5-sonnet'), isFalse);
    });

    test('extractPanelText gets content text from response', () {
      final body = {
        'choices': [
          {
            'message': {
              'role': 'assistant',
              'content': 'The capital of Indonesia is Jakarta.',
            }
          }
        ]
      };

      expect(extractPanelText(body), equals('The capital of Indonesia is Jakarta.'));
    });

    test('appendUserTurn appends user message', () {
      final body = {
        'messages': [
          {'role': 'user', 'content': 'First'}
        ]
      };

      final updated = appendUserTurn(body, 'Second turn');
      final msgs = updated['messages'] as List;
      expect(msgs.length, equals(2));
      expect(msgs[1]['role'], equals('user'));
      expect(msgs[1]['content'], equals('Second turn'));
    });
  });

  group('fusion - collectPanel Quorum & Timing', () {
    test('collectPanel collects all calls when all finish promptly', () async {
      final calls = <Future<FusionResult> Function()>[
        () async => const FusionResult(model: 'm1', ok: true, text: 'Ans 1'),
        () async => const FusionResult(model: 'm2', ok: true, text: 'Ans 2'),
      ];

      final results = await collectPanel(
        calls,
        tuning: const FusionTuning(minPanel: 2, stragglerGraceMs: 100, panelHardTimeoutMs: 1000),
      );

      expect(results.length, equals(2));
      expect(results[0]?.text, equals('Ans 1'));
      expect(results[1]?.text, equals('Ans 2'));
    });

    test('collectPanel triggers grace timer when minPanel reached', () async {
      final calls = <Future<FusionResult> Function()>[
        () async => const FusionResult(model: 'm1', ok: true, text: 'Fast 1'),
        () async => const FusionResult(model: 'm2', ok: true, text: 'Fast 2'),
        // Straggler yang lambat
        () async {
          await Future.delayed(const Duration(milliseconds: 500));
          return const FusionResult(model: 'm3', ok: true, text: 'Slow');
        },
      ];

      final stopwatch = Stopwatch()..start();
      final results = await collectPanel(
        calls,
        tuning: const FusionTuning(
          minPanel: 2,
          stragglerGraceMs: 50, // Grace cepat
          panelHardTimeoutMs: 2000,
        ),
      );
      stopwatch.stop();

      // Grace harus memutus pengumpulan sebelum model ke-3 selesai (~500ms)
      expect(stopwatch.elapsedMilliseconds, lessThan(400));
      expect(results.length, equals(3));
      expect(results[0]?.text, equals('Fast 1'));
      expect(results[1]?.text, equals('Fast 2'));
      expect(results[2], isNull); // Straggler terpotong oleh grace
    });
  });
}
