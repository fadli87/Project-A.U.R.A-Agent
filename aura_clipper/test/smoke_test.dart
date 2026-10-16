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
      final ytDlpPath = Platform.environment['YT_DLP_PATH'] ?? 'yt-dlp';
      final ffmpegPath = Platform.environment['FFMPEG_PATH'] ?? 'ffmpeg';
      final ffprobePath = Platform.environment['FFPROBE_PATH'] ?? 'ffprobe';
      final whisperPath = Platform.environment['WHISPER_PATH'] ?? 'whisper-cli';
      final whisperModelPath = Platform.environment['WHISPER_MODEL_PATH'];

      final testUrl = Platform.environment['TEST_VIDEO_URL'];
      final apiKey = Platform.environment['GEMINI_API_KEY'] ??
          Platform.environment['OPENAI_API_KEY'] ??
          Platform.environment['GROQ_API_KEY'];
      final forceWhisper = Platform.environment['FORCE_WHISPER'] == 'true';

      if (testUrl == null || testUrl.isEmpty) {
        markTestSkipped(
          'TEST_VIDEO_URL tidak diset.\n'
          'Untuk menjalankan smoke test penuh:\n'
          '  \$env:TEST_VIDEO_URL="https://youtu.be/..."\n'
          '  \$env:GEMINI_API_KEY="AIzaSy..."\n'
          '  flutter test --tags smoke\n',
        );
        return;
      }

      if (apiKey == null || apiKey.isEmpty) {
        markTestSkipped('GEMINI_API_KEY / OPENAI_API_KEY / GROQ_API_KEY tidak diset.');
        return;
      }

      try {
        final rYt = Process.runSync(ytDlpPath, ['--version']);
        final rFf = Process.runSync(ffmpegPath, ['-version']);
        if (rYt.exitCode != 0 || rFf.exitCode != 0) {
          markTestSkipped('yt-dlp atau ffmpeg tidak dapat dijalankan.');
          return;
        }
      } catch (e) {
        markTestSkipped('Tool eksternal yt-dlp / ffmpeg tidak ditemukan di PATH: $e');
        return;
      }

      if (forceWhisper) {
        if (whisperModelPath == null || !File(whisperModelPath).existsSync()) {
          markTestSkipped('FORCE_WHISPER aktif namun WHISPER_MODEL_PATH tidak valid atau file tidak ada.');
          return;
        }
        try {
          final rW = Process.runSync(whisperPath, ['--help']);
          if (rW.exitCode != 0) {
            markTestSkipped('whisper binary ($whisperPath) tidak dapat dijalankan.');
            return;
          }
        } catch (e) {
          markTestSkipped('whisper binary ($whisperPath) tidak ditemukan: $e');
          return;
        }
      }

      final tempDir = Directory.systemTemp.createTempSync('clipper_smoke_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final downloader = YtDlpDownloader(ytDlpPath: ytDlpPath);
      final transcriber = WhisperCppTranscriber(
        whisperPath: whisperPath,
        ffmpegPath: ffmpegPath,
        whisperModelName: whisperModelPath ?? 'ggml-base.bin',
      );

      final routerClient = LlmRouterClient();
      final analyzer = MomentAnalyzer(
        routerClient: routerClient,
        modelOrCombo: Platform.environment['LLM_MODEL'] ?? 'gemini/gemini-3.5-flash-lite',
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
      print('Mode Transkripsi: ${forceWhisper ? "FORCE_WHISPER (whisper.cpp)" : "Caption YouTube (fallback Whisper)"}');
      final stopwatch = Stopwatch()..start();
      VideoJobStatus? lastStage;
      int lastStageElapsedSec = 0;

      final focusText = Platform.environment['ANALYSIS_FOCUS'];
      final fromSecVal = int.tryParse(Platform.environment['ANALYSIS_FROM_SEC'] ?? '');
      final toSecVal = int.tryParse(Platform.environment['ANALYSIS_TO_SEC'] ?? '');

      await for (final progress in pipeline.run(
        job,
        jobDir: tempDir,
        options: AnalysisOptions(
          tokenBudget: 12000,
          maxClips: 3,
          forceWhisper: forceWhisper,
          focus: focusText,
          from: fromSecVal != null ? Duration(seconds: fromSecVal) : null,
          to: toSecVal != null ? Duration(seconds: toSecVal) : null,
        ),
      )) {
        if (lastStage != progress.stage) {
          if (lastStage != null) {
            final durationSec = stopwatch.elapsed.inSeconds - lastStageElapsedSec;
            print('-> Stage [${lastStage.name}] selesai dalam ${durationSec}s');
          }
          lastStage = progress.stage;
          lastStageElapsedSec = stopwatch.elapsed.inSeconds;
        }
        print('[${stopwatch.elapsed.inSeconds}s] ${progress.stage.name}: ${(progress.fraction * 100).toStringAsFixed(1)}% - ${progress.message}');
      }

      if (lastStage != null) {
        final durationSec = stopwatch.elapsed.inSeconds - lastStageElapsedSec;
        print('-> Stage [${lastStage.name}] selesai dalam ${durationSec}s');
      }

      // Periksa file caption yang terunduh di jobDir
      final json3Files = tempDir.listSync().where((f) => f.path.endsWith('.json3')).toList();
      print('\n--- DIAGNOSTIK TRANSKRIPSI ---');
      print('Jumlah file .json3 di jobDir: ${json3Files.length}');
      if (json3Files.isNotEmpty) {
        print('Nama file caption: ${json3Files.map((f) => f.path.split(Platform.pathSeparator).last).join(", ")}');
      }

      final transcript = pipeline.transcript;
      expect(transcript != null, isTrue, reason: 'Pipeline harus menghasilkan transkrip.');
      print('Bahasa terdeteksi: ${transcript!.language}');
      print('Jumlah segmen transkrip: ${transcript.segments.length}');
      if (transcript.segments.isNotEmpty) {
        final previewCount = transcript.segments.length > 2 ? 2 : transcript.segments.length;
        print('Sampel awal transkrip:');
        for (var i = 0; i < previewCount; i++) {
          final seg = transcript.segments[i];
          final heatStr = seg.heat != null ? ', heat: ${(seg.heat! * 100).toStringAsFixed(1)}%' : '';
          print('  [${seg.start.toStringAsFixed(1)}s - ${seg.end.toStringAsFixed(1)}s$heatStr]: ${seg.text}');
        }
      }

      final candidates = pipeline.candidates;
      final chunks = MomentAnalyzer.chunkSegments(
        transcript.segments,
        maxCharsPerChunk: 12000 * 4,
      );
      print('\n--- DIAGNOSTIK ANALISIS LLM ---');
      print('Jumlah chunk transkrip: ${chunks.length}');
      print('Jumlah kandidat klip: ${candidates.length}');
      print('Daftar seluruh kandidat klip:');
      for (var i = 0; i < candidates.length; i++) {
        final c = candidates[i];
        print('  [$i] "${c.title}" (${c.startTime.inSeconds}s - ${c.endTime.inSeconds}s, durasi: ${(c.endTime - c.startTime).inSeconds}s, skor: ${c.score})');
        print('      Alasan: ${c.reason}');
      }
      expect(candidates.isNotEmpty, isTrue, reason: 'Smoke test harus menghasilkan minimal satu kandidat klip valid.');

      final bestClip = candidates.first;
      print('\nKandidat terpilih untuk diekspor: "${bestClip.title}" (${bestClip.startTime.inSeconds}s - ${bestClip.endTime.inSeconds}s, Skor: ${bestClip.score})');

      print('\n--- EKSPOR KLIP ---');
      final exportStartSec = stopwatch.elapsed.inSeconds;
      final exportPath = await pipeline.exportClip(
        bestClip,
        outDir: tempDir,
      );
      final exportDurationSec = stopwatch.elapsed.inSeconds - exportStartSec;
      print('Ekspor selesai dalam ${exportDurationSec}s');

      expect(File(exportPath).existsSync(), isTrue, reason: 'File MP4 hasil ekspor harus ada di disk.');
      final exportSize = File(exportPath).lengthSync();
      expect(exportSize, greaterThan(10000), reason: 'Ukuran file video hasil ekspor harus valid (>10KB).');

      // Verifikasi durasi dengan ffprobe
      try {
        final probeRes = Process.runSync(ffprobePath, [
          '-v',
          'error',
          '-show_entries',
          'format=duration',
          '-of',
          'default=noprint_wrappers=1:nokey=1',
          exportPath,
        ]);
        expect(probeRes.exitCode, 0, reason: 'ffprobe gagal membaca durasi');
        final measuredDuration = double.parse((probeRes.stdout as String).trim());
        final expectedDuration = (bestClip.endTime - bestClip.startTime).inMilliseconds / 1000.0;
        final delta = (measuredDuration - expectedDuration).abs();
        print('Verifikasi ffprobe durasi: ${measuredDuration}s (ekspektasi: ${expectedDuration}s, delta: ${delta.toStringAsFixed(2)}s)');
        expect(delta, lessThanOrEqualTo(0.5), reason: 'Durasi klip meleset lebih dari 0.5 detik');
      } catch (e) {
        print('Peringatan ffprobe: $e');
      }

      print('\n=== SMOKE TEST SUKSES ===');
      print('Hasil klip: $exportPath ($exportSize bytes)');
      print('Total waktu eksekusi: ${stopwatch.elapsed.inSeconds}s');
    });
  });
}
