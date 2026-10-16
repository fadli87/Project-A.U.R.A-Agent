import 'dart:convert';
import '../pipeline/interfaces.dart';

/// Parser transkrip netral platform untuk output whisper.cpp dan YouTube captions (json3).
class TranscriptParsers {
  const TranscriptParsers._();

  /// Parse output JSON whisper.cpp menjadi Transcript netral.
  static Transcript parseWhisperJson(String jsonContent) {
    final parsed = jsonDecode(jsonContent);
    final segments = <TranscriptSegment>[];

    if (parsed is Map && parsed.containsKey('transcription')) {
      final list = parsed['transcription'] as List;
      for (final item in list) {
        if (item is Map) {
          final startMs = (item['offsets']?['from'] as num?)?.toDouble() ?? 0.0;
          final endMs = (item['offsets']?['to'] as num?)?.toDouble() ?? 0.0;
          final text = (item['text'] as String? ?? '').trim();

          segments.add(TranscriptSegment(
            start: startMs / 1000.0,
            end: endMs / 1000.0,
            text: text,
          ));
        }
      }
    }

    String? language;
    if (parsed is Map) {
      language = parsed['result']?['language'] as String? ??
          parsed['params']?['language'] as String?;
    }

    return Transcript(
      segments: segments,
      rawText: jsonContent,
      language: language,
    );
  }

  /// Parse output JSON3 caption YouTube menjadi Transcript netral.
  static Transcript parseJson3(String jsonContent, {String? language}) {
    final parsed = jsonDecode(jsonContent);
    final segments = <TranscriptSegment>[];

    if (parsed is Map && parsed.containsKey('events')) {
      final events = parsed['events'] as List;
      for (final event in events) {
        if (event is Map) {
          final startMs = (event['tStartMs'] as num?)?.toDouble() ?? 0.0;
          final durMs = (event['dDurationMs'] as num?)?.toDouble() ?? 0.0;
          final endMs = startMs + durMs;

          var text = '';
          if (event.containsKey('segs') && event['segs'] is List) {
            final segs = event['segs'] as List;
            text = segs.whereType<Map>().map((s) => s['utf8']?.toString() ?? '').join();
          }

          final cleanText = text.replaceAll('\n', ' ').trim();
          if (cleanText.isNotEmpty) {
            segments.add(TranscriptSegment(
              start: startMs / 1000.0,
              end: endMs / 1000.0,
              text: cleanText,
            ));
          }
        }
      }
    }

    return Transcript(
      segments: segments,
      rawText: jsonContent,
      language: language,
    );
  }
}
