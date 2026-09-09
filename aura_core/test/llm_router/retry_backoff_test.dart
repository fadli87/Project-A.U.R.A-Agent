import 'dart:convert';
import 'package:test/test.dart';
import 'package:aura_core/src/llm_router/retry_backoff.dart';

void main() {
  group('retry_backoff - Cooldown & Backoff Calculation', () {
    test('getQuotaCooldown calculates exponential backoff capped at 5 minutes', () {
      expect(getQuotaCooldown(0), equals(2000));
      expect(getQuotaCooldown(1), equals(2000));
      expect(getQuotaCooldown(2), equals(4000));
      expect(getQuotaCooldown(3), equals(8000));
      expect(getQuotaCooldown(4), equals(16000));
      // Level tinggi dibatasi pada backoffMaxMs (300.000 ms)
      expect(getQuotaCooldown(10), equals(300000));
      expect(getQuotaCooldown(15), equals(300000));
    });

    test('classifyError handles text-based rate limit with backoff', () {
      final res = classifyError(200, 'Upstream rate limit reached', 1);
      expect(res.shouldFallback, isTrue);
      expect(res.newBackoffLevel, equals(2));
      expect(res.cooldownMs, equals(4000));
    });

    test('classifyError handles HTTP status code 429 with backoff', () {
      final res = classifyError(429, '', 2);
      expect(res.shouldFallback, isTrue);
      expect(res.newBackoffLevel, equals(3));
      expect(res.cooldownMs, equals(8000));
    });

    test('classifyError handles authentication 401 with cooldownLong', () {
      final res = classifyError(401, 'Unauthorized', 0);
      expect(res.shouldFallback, isTrue);
      expect(res.newBackoffLevel, equals(0)); // level tidak naik
      expect(res.cooldownMs, equals(cooldownLong));
    });

    test('classifyError falls back to transientCooldownMs for unknown error', () {
      final res = classifyError(500, 'Internal backend hiccup', 3);
      expect(res.shouldFallback, isTrue);
      expect(res.newBackoffLevel, equals(3));
      expect(res.cooldownMs, equals(transientCooldownMs));
    });
  });

  group('retry_backoff - Error Extraction & Formatting', () {
    test('extractErrorText parses message from JSON payload', () {
      final jsonStr = jsonEncode({
        'error': {'message': 'Quota exceeded for project-123', 'type': 'rate_limit'}
      });
      expect(extractErrorText(jsonStr), equals('Quota exceeded for project-123'));
    });

    test('extractRetryAfter finds retry timestamp or delay', () {
      final jsonStr = jsonEncode({'retry_after': '2026-09-09T15:00:00Z'});
      expect(extractRetryAfter(jsonStr), equals('2026-09-09T15:00:00Z'));

      final jsonNested = jsonEncode({
        'error': {'retryAfter': '60'}
      });
      expect(extractRetryAfter(jsonNested), equals('60'));
    });

    test('formatRetryAfter formats countdown string correctly', () {
      final futureTime = DateTime.now().toUtc().add(const Duration(minutes: 2, seconds: 15));
      final formatted = formatRetryAfter(futureTime.toIso8601String());
      expect(formatted, startsWith('reset after '));
      expect(formatted, contains('2m'));

      final pastTime = DateTime.now().toUtc().subtract(const Duration(seconds: 10));
      expect(formatRetryAfter(pastTime.toIso8601String()), equals('reset after 0s'));
      expect(formatRetryAfter('invalid-date'), equals(''));
    });
  });
}
