import '../pipeline/interfaces.dart';

class TranscriptEnricher {
  /// Menggabungkan segmen-segmen pendek (<1.5 detik) menjadi segmen yang lebih nyaman dibaca (5-15 detik)
  /// dan memperkaya tiap segmen dengan rata-rata skor heatmap YouTube bila tersedia.
  static Transcript enrich(
    Transcript transcript, {
    List<HeatmapPoint>? heatmap,
    double minDurationSec = 1.5,
    double maxMergedDurationSec = 15.0,
  }) {
    if (transcript.segments.isEmpty) return transcript;

    final mergedSegments = <TranscriptSegment>[];
    TranscriptSegment? current;

    for (final seg in transcript.segments) {
      if (current == null) {
        current = seg;
        continue;
      }

      final currentDuration = current.end - current.start;
      final nextDuration = seg.end - seg.start;
      final gap = seg.start - current.end;

      // Gabungkan jika segmen saat ini masih terlalu pendek (< minDurationSec)
      // atau jika gabungan tidak melebihi batas waktu maksimal (~15 detik)
      final canMerge = (gap < 1.0) &&
          (currentDuration < minDurationSec ||
              (currentDuration + nextDuration <= maxMergedDurationSec));

      if (canMerge) {
        current = TranscriptSegment(
          start: current.start,
          end: seg.end,
          text: '${current.text} ${seg.text}'.trim(),
        );
      } else {
        mergedSegments.add(current);
        current = seg;
      }
    }

    if (current != null) {
      mergedSegments.add(current);
    }

    // Lampirkan skor heatmap rata-rata per segmen jika data heatmap ada
    if (heatmap != null && heatmap.isNotEmpty) {
      final enrichedWithHeat = mergedSegments.map((seg) {
        // Cari titik-titik heatmap yang overlap dengan segmen ini [seg.start, seg.end]
        final overlappingPoints = heatmap.where((p) {
          return p.endTime >= seg.start && p.startTime <= seg.end;
        }).toList();

        double? avgHeat;
        if (overlappingPoints.isNotEmpty) {
          final total = overlappingPoints.fold<double>(0.0, (acc, p) => acc + p.value);
          avgHeat = (total / overlappingPoints.length).clamp(0.0, 1.0);
        }

        return TranscriptSegment(
          start: seg.start,
          end: seg.end,
          text: seg.text,
          heat: avgHeat,
        );
      }).toList();

      return Transcript(
        segments: enrichedWithHeat,
        rawText: transcript.rawText,
        language: transcript.language,
      );
    }

    return Transcript(
      segments: mergedSegments,
      rawText: transcript.rawText,
      language: transcript.language,
    );
  }
}
