import 'dart:io';
import '../models/clip_candidate.dart';
import '../models/video_job.dart';

/// Progres suatu job pemrosesan klip.
class JobProgress {
  final VideoJobStatus stage;
  final double fraction; // 0.0 - 1.0
  final String message;

  const JobProgress({
    required this.stage,
    required this.fraction,
    required this.message,
  });

  @override
  String toString() => 'JobProgress(stage: ${stage.name}, fraction: ${(fraction * 100).toStringAsFixed(1)}%, message: $message)';
}

/// Token pembatalan sederhana tanpa dependency eksternal.
class CancelToken {
  bool _isCancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _isCancelled;

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in List.of(_listeners)) {
      try {
        listener();
      } catch (_) {}
    }
  }

  void onCancel(void Function() listener) {
    if (_isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw OperationCancelledException('Operasi dibatalkan oleh user.');
    }
  }
}

class OperationCancelledException implements Exception {
  final String message;
  const OperationCancelledException(this.message);

  @override
  String toString() => message;
}

/// Titik data heatmap ("most replayed") YouTube.
class HeatmapPoint {
  final double startTime;
  final double endTime;
  final double value; // Ternormalisasi 0.0 - 1.0

  const HeatmapPoint({
    required this.startTime,
    required this.endTime,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
    'start_time': startTime,
    'end_time': endTime,
    'value': value,
  };

  factory HeatmapPoint.fromJson(Map<String, dynamic> json) {
    return HeatmapPoint(
      startTime: (json['start_time'] as num?)?.toDouble() ?? 0.0,
      endTime: (json['end_time'] as num?)?.toDouble() ?? 0.0,
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Hasil download video dan metadata.
class DownloadResult {
  final String videoPath;
  final int durationSeconds;
  final String title;
  final List<HeatmapPoint>? heatmap;

  const DownloadResult({
    required this.videoPath,
    required this.durationSeconds,
    required this.title,
    this.heatmap,
  });
}

/// Satu segmen transkrip yang netral terhadap sumber (whisper / caption).
class TranscriptSegment {
  final double start; // dalam detik
  final double end;   // dalam detik
  final String text;
  final double? heat; // skor heatmap rata-rata (opsional, 0.0 - 1.0)

  const TranscriptSegment({
    required this.start,
    required this.end,
    required this.text,
    this.heat,
  });

  String formatTimestamp() {
    final startSec = start.toInt();
    final m = startSec ~/ 60;
    final s = startSec % 60;
    return '[${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}]';
  }

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'text': text,
    if (heat != null) 'heat': heat,
  };

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      start: (json['start'] as num?)?.toDouble() ?? 0.0,
      end: (json['end'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] as String? ?? '',
      heat: (json['heat'] as num?)?.toDouble(),
    );
  }
}

/// Transkrip lengkap yang terdiri dari segmen-segmen waktu.
class Transcript {
  final List<TranscriptSegment> segments;
  final String? rawText;

  const Transcript({
    required this.segments,
    this.rawText,
  });

  String toFormattedText() {
    final buffer = StringBuffer();
    for (final seg in segments) {
      final marker = (seg.heat != null && seg.heat! >= 0.7) ? ' ▲' : '';
      buffer.writeln('${seg.formatTimestamp()} ${seg.text}$marker');
    }
    return buffer.toString().trim();
  }
}

/// Interface pengunduh video.
abstract interface class Downloader {
  Future<DownloadResult> download(
    String url, {
    required Directory jobDir,
    CancelToken? cancel,
    void Function(double fraction)? onProgress,
  });
}

/// Interface transkripsi audio/video.
abstract interface class Transcriber {
  Future<Transcript> transcribe(
    String videoPath, {
    String? language,
    CancelToken? cancel,
    void Function(double fraction)? onProgress,
  });
}

/// Interface pengekspor klip video.
abstract interface class Exporter {
  Future<String> export(
    String videoPath,
    ClipCandidate clip, {
    required Directory outDir,
    CancelToken? cancel,
  });
}
