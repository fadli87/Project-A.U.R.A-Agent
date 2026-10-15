import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/clip_candidate.dart';
import '../pipeline/interfaces.dart';
import 'process_runner.dart';

class FfmpegExporter implements Exporter {
  final String ffmpegPath;
  final ProcessRunner runner;

  FfmpegExporter({
    required this.ffmpegPath,
    ProcessRunner? runner,
  }) : runner = runner ?? const DesktopProcessRunner();

  /// Membangun argumen ffmpeg untuk potong video re-encode akurat per frame.
  static List<String> buildExportArgs({
    required String sourceVideoPath,
    required Duration startTime,
    required Duration endTime,
    required String outputPath,
  }) {
    return [
      '-y',
      '-ss',
      (startTime.inMilliseconds / 1000.0).toStringAsFixed(2),
      '-to',
      (endTime.inMilliseconds / 1000.0).toStringAsFixed(2),
      '-i',
      sourceVideoPath,
      '-c:v',
      'libx264',
      '-preset',
      'fast',
      '-c:a',
      'aac',
      '-movflags',
      '+faststart',
      outputPath,
    ];
  }

  /// Membuat nama file keluaran yang aman dan terstruktur.
  static String buildOutputFileName({
    required String baseName,
    required Duration startTime,
    required Duration endTime,
  }) {
    final sMin = startTime.inMinutes;
    final sSec = startTime.inSeconds % 60;
    final eMin = endTime.inMinutes;
    final eSec = endTime.inSeconds % 60;

    final startStr = '${sMin}m${sSec.toString().padLeft(2, '0')}s';
    final endStr = '${eMin}m${eSec.toString().padLeft(2, '0')}s';

    // Bersihkan karakter non-alphanumeric dari baseName
    final cleanBase = baseName.replaceAll(RegExp(r'[^\w\-]'), '_');
    return '${cleanBase}_$startStr-$endStr.mp4';
  }

  @override
  Future<String> export(
    String videoPath,
    ClipCandidate clip, {
    required Directory outDir,
    CancelToken? cancel,
  }) async {
    cancel?.throwIfCancelled();

    final videoFile = File(videoPath);
    if (!await videoFile.exists()) {
      throw FileSystemException('File video sumber tidak ditemukan: $videoPath');
    }

    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final baseName = p.basenameWithoutExtension(videoPath);
    final outputFileName = buildOutputFileName(
      baseName: baseName,
      startTime: clip.startTime,
      endTime: clip.endTime,
    );
    final outputPath = p.join(outDir.path, outputFileName);

    final args = buildExportArgs(
      sourceVideoPath: videoPath,
      startTime: clip.startTime,
      endTime: clip.endTime,
      outputPath: outputPath,
    );

    final result = await runner.run(
      ffmpegPath,
      args,
      workingDirectory: outDir.path,
      cancel: cancel,
    );

    if (!result.isSuccess) {
      throw Exception('Gagal mengekspor klip via ffmpeg: ${result.stderr}');
    }

    final outputFile = File(outputPath);
    if (!await outputFile.exists() || await outputFile.length() == 0) {
      throw Exception('File ekspor klip tidak ditemukan atau kosong di $outputPath');
    }

    return outputPath;
  }
}
