// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_clipper/aura_clipper_desktop.dart';

void main() {
  group('Real FfmpegExporter & ffprobe verification', () {
    test('FfmpegExporter cuts video with exact duration verifiable via ffprobe', () async {
      if (!Platform.isWindows) return;

      final ffmpegPath = 'C:\\Users\\Fadli Santoso\\AppData\\Local\\Microsoft\\WinGet\\Links\\ffmpeg.exe';
      final ffprobePath = 'C:\\Users\\Fadli Santoso\\AppData\\Local\\Microsoft\\WinGet\\Links\\ffprobe.exe';

      if (!File(ffmpegPath).existsSync() || !File(ffprobePath).existsSync()) {
        return;
      }

      final tempDir = Directory.systemTemp.createTempSync('ffmpeg_real_test_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      // 1. Buat source video 15 detik menggunakan ffmpeg
      final sourcePath = '${tempDir.path}\\source.mp4';
      final makeSource = Process.runSync(
        ffmpegPath,
        [
          '-y',
          '-f', 'lavfi', '-i', 'testsrc=duration=15:size=640x360:rate=30',
          '-f', 'lavfi', '-i', 'sine=frequency=1000:duration=15',
          '-c:v', 'libx264',
          '-c:a', 'aac',
          sourcePath,
        ],
      );
      expect(makeSource.exitCode, 0);
      expect(File(sourcePath).existsSync(), isTrue);

      // 2. Ekspor klip dari detik 3.0 ke 9.0 (target durasi: 6.0 detik) menggunakan FfmpegExporter sungguhan
      final exporter = FfmpegExporter(ffmpegPath: ffmpegPath);
      final candidate = ClipCandidate(
        title: 'Real Export Test Clip',
        startTime: const Duration(seconds: 3),
        endTime: const Duration(seconds: 9),
        score: 95,
        reason: 'Uji ekspor nyata',
      );

      final outDir = Directory('${tempDir.path}\\output');
      final exportedPath = await exporter.export(
        sourcePath,
        candidate,
        outDir: outDir,
      );

      expect(File(exportedPath).existsSync(), isTrue);
      expect(File(exportedPath).lengthSync(), greaterThan(1000));

      // 3. Ukur durasi file hasil dengan ffprobe
      final ffprobeResult = Process.runSync(
        ffprobePath,
        [
          '-v', 'error',
          '-show_entries', 'format=duration',
          '-of', 'default=noprint_wrappers=1:nokey=1',
          exportedPath,
        ],
      );

      expect(ffprobeResult.exitCode, 0);
      final rawDurationStr = ffprobeResult.stdout.toString().trim();
      final measuredDuration = double.tryParse(rawDurationStr);

      expect(measuredDuration, isNotNull);
      // Durasi harus mendekati 6.0 detik (toleransi frame boundary +-0.15 dtk)
      expect(measuredDuration, closeTo(6.0, 0.15));

      print('=== BUKTI NYATA EKSPOR FFMPEG & FFPROBE ===');
      print('Source: $sourcePath');
      print('Export Clip: $exportedPath');
      print('Candidate Range: 3s - 9s (Expected duration: 6.0s)');
      print('Measured duration by ffprobe: ${measuredDuration}s');
      print('Exit Code: ${ffprobeResult.exitCode}');
    });
  });
}
