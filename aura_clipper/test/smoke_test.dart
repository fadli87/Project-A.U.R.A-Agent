// ignore_for_file: avoid_print, unused_local_variable
@Tags(['smoke'])
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_core/aura_core.dart';
import 'package:aura_clipper/aura_clipper_desktop.dart';

void main() {
  group('Smoke Test (Real End-to-End Pipeline)', () {
    test('Downloads, transcribes via caption/Whisper, analyzes via LLM, and exports real clip', () async {
      final ytDlpPath = Platform.environment['YT_DLP_PATH'] ??
          'C:\\Users\\Fadli Santoso\\AppData\\Roaming\\Python\\Python314\\Scripts\\yt-dlp.exe';
      final ffmpegPath = Platform.environment['FFMPEG_PATH'] ??
          'C:\\Users\\Fadli Santoso\\AppData\\Local\\Microsoft\\WinGet\\Links\\ffmpeg.exe';
      final testUrl = Platform.environment['TEST_VIDEO_URL'];
      final apiKey = Platform.environment['GEMINI_API_KEY'] ??
          Platform.environment['OPENAI_API_KEY'] ??
          Platform.environment['GROQ_API_KEY'];
      final forceWhisper = Platform.environment['FORCE_WHISPER'] == 'true';

      if (testUrl == null || testUrl.isEmpty) {
        print(
          'SMOKE TEST SKIPPED: TEST_VIDEO_URL tidak diset.\n'
          'Untuk menjalankan smoke test penuh:\n'
          '  \$env:TEST_VIDEO_URL="https://youtu.be/..."\n'
          '  \$env:GEMINI_API_KEY="AIzaSy..."\n'
          '  flutter test --tags smoke\n',
        );
        return;
      }

      if (!File(ytDlpPath).existsSync()) {
        fail('yt-dlp tidak ditemukan di $ytDlpPath');
      }
      if (!File(ffmpegPath).existsSync()) {
        fail('ffmpeg tidak ditemukan di $ffmpegPath');
      }

      final tempDir = Directory.systemTemp.createTempSync('clipper_smoke_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final downloader = YtDlpDownloader(ytDlpPath: ytDlpPath);
      final transcriber = WhisperCppTranscriber(
        whisperPath: Platform.environment['WHISPER_PATH'] ?? 'whisper-cli',
        ffmpegPath: ffmpegPath,
      );

      final routerClient = LlmRouterClient();
      final analyzer = MomentAnalyzer(
        routerClient: routerClient,
        modelOrCombo: Platform.environment['LLM_MODEL'] ?? 'gemini/gemini-2.5-flash',
        apiKeys: {
          if (Platform.environment['GEMINI_API_KEY'] != null)
            'gemini': Platform.environment['GEMINI_API_KEY']!,
          if (Platform.environment['OPENAI_API_KEY'] != null)
            'openai': Platform.environment['OPENAI_API_KEY']!,
          if (Platform.environment['GROQ_API_KEY'] != null)
            'groq': Platform.environment['GROQ_API_KEY']!,
        },
      );

      final exporter = FfmpegExporter(ffmpegPath: ffmpegPath);
      final db = await ClipDatabase.init(tempDir.path);

      final pipeline = ClipperPipeline(
        downloader: downloader,
        transcriber: transcriber,
        analyzer: analyzer,
        exporter: exporter,
        database: db,
      );

      final job = VideoJob(
        id: 'smoke_${DateTime.now().millisecondsSinceEpoch}',
        url: testUrl,
        createdAt: DateTime.now(),
      );

      print('=== MEMULAI SMOKE TEST: $testUrl ===');
      final stopwatch = Stopwatch()..start();

      await for (final progress in pipeline.run(
        job,
        jobDir: tempDir,
        options: const AnalysisOptions(
          tokenBudget: 12000,
          maxClips: 3,
        ),
      )) {
        print('[${stopwatch.elapsed.inSeconds}s] ${progress.stage.name}: ${(progress.fraction * 100).toStringAsFixed(1)}% - ${progress.message}');
      }

      final candidates = pipeline.candidates;
      expect(candidates.isNotEmpty, isTrue, reason: 'Smoke test harus menghasilkan minimal satu kandidat klip valid.');

      final bestClip = candidates.first;
      print('Kandidat terpilih: "${bestClip.title}" (${bestClip.startTime.inSeconds}s - ${bestClip.endTime.inSeconds}s, Skor: ${bestClip.score})');

      final exportPath = await pipeline.exportClip(
        bestClip,
        outDir: tempDir,
      );

      expect(File(exportPath).existsSync(), isTrue, reason: 'File MP4 hasil ekspor harus ada di disk.');
      final exportSize = File(exportPath).lengthSync();
      expect(exportSize, greaterThan(10000), reason: 'Ukuran file video hasil ekspor harus valid (>10KB).');

      print('=== SMOKE TEST SUKSES ===');
      print('Hasil klip: $exportPath ($exportSize bytes)');
    });
  });
}
