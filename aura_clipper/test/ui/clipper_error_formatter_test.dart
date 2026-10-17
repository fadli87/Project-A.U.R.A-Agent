import 'package:flutter_test/flutter_test.dart';
import 'package:aura_clipper/src/ui/clipper_error_formatter.dart';

void main() {
  group('ClipperErrorFormatter', () {
    test('classifies 404 NOT_FOUND / model retired accurately', () {
      const raw =
          'LocalFallbackException(All models in combo failed): ☁️ -> 💈 Seluruh layanan cloud sibuk/gagal, beralih ke model lokal '
          '(original: HttpException: Gemini HTTP 404 NOT_FOUND: { "error": { "code": 404, "message": "This model models/gemini-2.5-flash is no longer available to new users. Please update your code to use models/gemini-3.8-flash" } })';

      final info = ClipperErrorFormatter.format(raw);

      expect(info.category, contains('404'));
      expect(info.advice, contains('gemini-3.8-flash'));
      expect(info.shortSummary, contains('404'));
      expect(info.detail, raw);
    });

    test('classifies 401 / 403 authentication failures', () {
      const raw = 'HttpException: Gemini HTTP 401 UNAUTHENTICATED: API_KEY_INVALID';

      final info = ClipperErrorFormatter.format(raw);

      expect(info.category, contains('401/403'));
      expect(info.advice, contains('API key'));
      expect(info.shortSummary, contains('401/403'));
    });

    test('classifies 429 quota exhaustion', () {
      const raw = 'HttpException: Gemini HTTP 429 RESOURCE_EXHAUSTED: Quota exceeded for quota metric';

      final info = ClipperErrorFormatter.format(raw);

      expect(info.category, contains('429'));
      expect(info.advice, contains('kuota'));
      expect(info.shortSummary, contains('429'));
    });

    test('classifies 503 server overload', () {
      const raw = 'HttpException: Gemini HTTP 503 UNAVAILABLE: The model is overloaded. Please try again later.';

      final info = ClipperErrorFormatter.format(raw);

      expect(info.category, contains('503'));
      expect(info.advice, contains('sibuk'));
      expect(info.shortSummary, contains('503'));
    });

    test('classifies ProcessException executable failure', () {
      const raw = 'ProcessException: The system cannot find the file specified. (executable: yt-dlp)';

      final info = ClipperErrorFormatter.format(raw);

      expect(info.category, contains('Tool Sistem'));
      expect(info.advice, contains('yt-dlp'));
      expect(info.shortSummary, contains('Tool'));
    });

    test('handles fallback/generic unknown errors gracefully', () {
      const raw = 'SocketException: Connection refused';

      final info = ClipperErrorFormatter.format(raw);

      expect(info.category, contains('Kegagalan Proses'));
      expect(info.detail, raw);
      expect(info.shortSummary, contains('SocketException'));
    });
  });
}
