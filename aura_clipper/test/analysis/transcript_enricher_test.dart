import 'package:flutter_test/flutter_test.dart';
import 'package:aura_clipper/aura_clipper.dart';

void main() {
  group('TranscriptEnricher', () {
    test('merges short consecutive segments into reasonable duration chunks', () {
      const raw = Transcript(
        segments: [
          TranscriptSegment(start: 0.0, end: 1.0, text: 'Kata satu,'),
          TranscriptSegment(start: 1.0, end: 2.0, text: 'kata dua,'),
          TranscriptSegment(start: 2.0, end: 3.2, text: 'dan kalimat pertama selesai.'),
          TranscriptSegment(start: 10.0, end: 11.0, text: 'Jeda panjang lalu kata baru.'),
        ],
      );

      final enriched = TranscriptEnricher.enrich(raw);
      expect(enriched.segments.length, 2);

      // Segmen pertama hasil gabungan
      expect(enriched.segments[0].start, 0.0);
      expect(enriched.segments[0].end, 3.2);
      expect(
        enriched.segments[0].text,
        'Kata satu, kata dua, dan kalimat pertama selesai.',
      );

      // Segmen kedua tidak digabung karena ada jeda > 2.0s
      expect(enriched.segments[1].start, 10.0);
      expect(enriched.segments[1].end, 11.0);
    });

    test('overlays heatmap data onto transcript segments', () {
      const raw = Transcript(
        segments: [
          TranscriptSegment(start: 10.0, end: 20.0, text: 'Momen biasa'),
          TranscriptSegment(start: 30.0, end: 40.0, text: 'Puncak viralitas'),
        ],
      );

      final heatmap = [
        const HeatmapPoint(startTime: 10.0, endTime: 20.0, value: 0.2),
        const HeatmapPoint(startTime: 30.0, endTime: 35.0, value: 1.0),
        const HeatmapPoint(startTime: 35.0, endTime: 40.0, value: 0.8),
      ];

      final enriched = TranscriptEnricher.enrich(raw, heatmap: heatmap);
      expect(enriched.segments.length, 2);

      expect(enriched.segments[0].heat, closeTo(0.2, 0.01));
      // Rata-rata 1.0 dan 0.8 = 0.9
      expect(enriched.segments[1].heat, closeTo(0.9, 0.01));
    });

    test('toFormattedText displays ▲ indicator for high heat segments', () {
      const raw = Transcript(
        segments: [
          TranscriptSegment(start: 5.0, end: 15.0, text: 'Segmen biasa', heat: 0.3),
          TranscriptSegment(start: 20.0, end: 35.0, text: 'Segmen viral', heat: 0.85),
        ],
      );

      final formatted = raw.toFormattedText();
      expect(formatted, contains('[00:05] Segmen biasa'));
      expect(formatted, contains('[00:20] Segmen viral ▲'));
    });
  });
}
