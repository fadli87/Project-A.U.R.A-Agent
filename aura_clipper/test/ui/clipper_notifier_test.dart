import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_core/aura_core.dart';
import 'package:aura_clipper/aura_clipper_ui.dart';

class TestPipeline extends ClipperPipeline {
  final List<ClipCandidate> mockCandidates;
  final bool shouldThrow;
  final Duration delayPerStage;

  TestPipeline({
    this.mockCandidates = const [],
    this.shouldThrow = false,
    this.delayPerStage = Duration.zero,
  }) : super(
          downloader: _DummyDownloader(),
          transcriber: _DummyTranscriber(),
          analyzer: MomentAnalyzer(
            routerClient: LlmRouterClient(),
            modelOrCombo: 'test',
            apiKeys: const {},
          ),
          exporter: _DummyExporter(),
        );

  @override
  List<ClipCandidate> get candidates => mockCandidates;

  @override
  Stream<JobProgress> run(
    VideoJob initialJob, {
    required Directory jobDir,
    AnalysisOptions? options,
    CancelToken? cancel,
    String? language,
  }) async* {
    cancel?.throwIfCancelled();
    yield const JobProgress(
      stage: VideoJobStatus.downloading,
      fraction: 0.1,
      message: 'Mengunduh video...',
    );

    if (delayPerStage > Duration.zero) {
      await Future.delayed(delayPerStage);
    }
    cancel?.throwIfCancelled();

    if (shouldThrow) {
      throw const LlmAnalysisException('Gagal memproses LLM simulasi');
    }

    yield const JobProgress(
      stage: VideoJobStatus.transcribing,
      fraction: 0.5,
      message: 'Mentranskripsi...',
    );

    if (delayPerStage > Duration.zero) {
      await Future.delayed(delayPerStage);
    }
    cancel?.throwIfCancelled();

    yield const JobProgress(
      stage: VideoJobStatus.analyzing,
      fraction: 0.8,
      message: 'Menganalisis klip viral...',
    );

    yield const JobProgress(
      stage: VideoJobStatus.done,
      fraction: 1.0,
      message: 'Selesai!',
    );
  }
}

class _DummyDownloader implements Downloader {
  @override
  Future<DownloadResult> download(
    String url, {
    required Directory jobDir,
    CancelToken? cancel,
    void Function(double fraction)? onProgress,
    String? language,
  }) async {
    return const DownloadResult(
      videoPath: 'dummy.mp4',
      durationSeconds: 60,
      title: 'Dummy Video',
    );
  }
}

class _DummyTranscriber implements Transcriber {
  @override
  Future<Transcript> transcribe(
    String videoPath, {
    String? language,
    CancelToken? cancel,
    void Function(double fraction)? onProgress,
  }) async {
    return const Transcript(segments: []);
  }
}

class _DummyExporter implements Exporter {
  @override
  Future<String> export(
    String videoPath,
    ClipCandidate candidate, {
    required Directory outDir,
    CancelToken? cancel,
    void Function(double fraction)? onProgress,
  }) async {
    return '${outDir.path}/${candidate.title}.mp4';
  }
}

void main() {
  group('ClipperNotifier Unit Tests (Fase 23b)', () {
    late Directory tempDir;
    late ClipperHostConfig hostConfig;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('clipper_notifier_test_');
      hostConfig = ClipperHostConfig(
        modelOrCombo: 'gemini/gemini-3.5-flash-lite',
        apiKeys: const {'gemini': 'test_api_key'},
        workDir: tempDir,
      );
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('Sukses: startPipeline memancarkan stage, status transisi ke done, dan mengisi candidates', () async {
      final notifier = ClipperNotifier(hostConfig);
      await notifier.init();

      notifier.setUrl('https://www.youtube.com/watch?v=406RNDgauvQ');

      final mockClips = [
        ClipCandidate(
          title: 'Kandidat Viral 1',
          startTime: const Duration(seconds: 10),
          endTime: const Duration(seconds: 40),
          score: 95,
          reason: 'Hook pembuka sangat kuat',
        ),
        ClipCandidate(
          title: 'Kandidat Viral 2',
          startTime: const Duration(seconds: 50),
          endTime: const Duration(seconds: 80),
          score: 85,
          reason: 'Pernyataan mengejutkan',
        ),
      ];

      final pipeline = TestPipeline(mockCandidates: mockClips);

      await notifier.startPipeline(customPipeline: pipeline);

      final state = notifier.state;
      expect(state.isRunning, isFalse);
      expect(state.activeStage, VideoJobStatus.done);
      expect(state.progressFraction, 1.0);
      expect(state.candidates.length, 2);
      expect(state.selectedCandidate, mockClips.first);
      expect(state.checkedCandidateTitles, containsAll(['Kandidat Viral 1', 'Kandidat Viral 2']));
      expect(state.errorMessage, isNull);
    });

    test('Error: saat pipeline gagal, activeStage menjadi error dan pesan ramah muncul', () async {
      final notifier = ClipperNotifier(hostConfig);
      await notifier.init();

      notifier.setUrl('https://www.youtube.com/watch?v=406RNDgauvQ');

      final pipeline = TestPipeline(shouldThrow: true);

      await notifier.startPipeline(customPipeline: pipeline);

      final state = notifier.state;
      expect(state.isRunning, isFalse);
      expect(state.activeStage, VideoJobStatus.error);
      expect(state.errorMessage, contains('Analisis AI Gagal'));
      expect(state.candidates, isEmpty);
    });

    test('Dibatalkan: cancelPipeline di tengah jalan menghasilkan status cancelled (bukan error)', () async {
      final notifier = ClipperNotifier(hostConfig);
      await notifier.init();

      notifier.setUrl('https://www.youtube.com/watch?v=406RNDgauvQ');

      final pipeline = TestPipeline(delayPerStage: const Duration(milliseconds: 200));

      final future = notifier.startPipeline(customPipeline: pipeline);

      // Beri sedikit jeda agar pipeline mulai berjalan
      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.isRunning, isTrue);

      // Batalkan
      notifier.cancelPipeline();
      await future;

      final state = notifier.state;
      expect(state.isRunning, isFalse);
      expect(state.activeStage, VideoJobStatus.cancelled);
      expect(state.progressMessage, contains('dibatalkan oleh pengguna'));
      expect(state.errorMessage, isNull);
    });

    test('Ekspor: mengekspor banyak klip terpilih menggunakan custom exporter', () async {
      final notifier = ClipperNotifier(hostConfig);
      await notifier.init();

      // Buat dummy source video file
      final dummyVideo = File('${tempDir.path}/dummy_source.mp4');
      dummyVideo.writeAsStringSync('dummy video content');

      final mockClips = [
        ClipCandidate(
          title: 'Klip A',
          startTime: const Duration(seconds: 1),
          endTime: const Duration(seconds: 10),
          score: 90,
          reason: 'A',
        ),
        ClipCandidate(
          title: 'Klip B',
          startTime: const Duration(seconds: 20),
          endTime: const Duration(seconds: 35),
          score: 80,
          reason: 'B',
        ),
      ];

      // Setup state dengan job dan kandidat
      final job = VideoJob(
        id: 'job_test_export',
        url: 'https://youtube.com',
        localVideoPath: dummyVideo.path,
        createdAt: DateTime.now(),
      );

      notifier.state = notifier.state.copyWith(
        currentJob: job,
        candidates: mockClips,
        checkedCandidateTitles: {'Klip A', 'Klip B'},
      );

      final exportDir = Directory('${tempDir.path}/output_clips');
      final fakeExporter = _DummyExporter();

      await notifier.exportSelected(
        targetFolder: exportDir.path,
        customExporter: fakeExporter,
      );

      final state = notifier.state;
      expect(state.isExporting, isFalse);
      expect(state.exportProgress, 1.0);
      expect(state.exportedPaths.length, 2);
      expect(state.exportedPaths[0], contains('Klip A.mp4'));
      expect(state.exportedPaths[1], contains('Klip B.mp4'));
      expect(state.errorMessage, isNull);
    });

    test('Pembersihan Cache: clearJobCache menghapus direktori jobs dan mengosongkan riwayat', () async {
      final notifier = ClipperNotifier(hostConfig);
      await notifier.init();

      // Buat file dan direktori di dalam jobs/
      final jobsDir = Directory('${tempDir.path}/jobs/job_123');
      jobsDir.createSync(recursive: true);
      final testFile = File('${jobsDir.path}/sample.mp4');
      testFile.writeAsStringSync('data');
      expect(testFile.existsSync(), isTrue);

      await notifier.clearJobCache();

      final state = notifier.state;
      expect(state.historyJobs, isEmpty);
      expect(testFile.existsSync(), isFalse);
      expect(state.progressMessage, contains('berhasil dibersihkan'));
    });
  });
}
