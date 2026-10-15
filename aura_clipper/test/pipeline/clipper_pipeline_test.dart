import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_core/aura_core.dart';
import 'package:aura_clipper/aura_clipper.dart';

class FakeDownloader implements Downloader {
  bool shouldThrow = false;

  @override
  Future<DownloadResult> download(
    String url, {
    required Directory jobDir,
    CancelToken? cancel,
    void Function(double fraction)? onProgress,
  }) async {
    cancel?.throwIfCancelled();
    if (shouldThrow) throw Exception('Simulasi gagal download');
    onProgress?.call(0.5);
    onProgress?.call(1.0);
    return const DownloadResult(
      videoPath: '/temp/video.mp4',
      durationSeconds: 120,
      title: 'Video Uji Coba',
    );
  }
}

class FakeTranscriber implements Transcriber {
  bool shouldThrow = false;

  @override
  Future<Transcript> transcribe(
    String videoPath, {
    String? language,
    CancelToken? cancel,
    void Function(double fraction)? onProgress,
  }) async {
    cancel?.throwIfCancelled();
    if (shouldThrow) throw Exception('Simulasi gagal transkripsi');
    onProgress?.call(0.5);
    onProgress?.call(1.0);
    return const Transcript(
      segments: [
        TranscriptSegment(start: 0, end: 15, text: 'Intro video'),
        TranscriptSegment(start: 15, end: 45, text: 'Momen sangat viral di sini!'),
      ],
    );
  }
}

class FakeExporter implements Exporter {
  @override
  Future<String> export(
    String videoPath,
    ClipCandidate clip, {
    required Directory outDir,
    CancelToken? cancel,
  }) async {
    cancel?.throwIfCancelled();
    return '${outDir.path}/clip_${clip.startTime.inSeconds}-${clip.endTime.inSeconds}.mp4';
  }
}

class FakeRouterClient extends LlmRouterClient {
  final String responseText;
  FakeRouterClient({required this.responseText});

  @override
  Stream<RouterStreamEvent> streamGenerate({
    required List<ChatMessage> messages,
    required String modelOrCombo,
    required Map<String, String> apiKeys,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1024,
    ComboStrategy comboStrategy = ComboStrategy.fallback,
    bool newTurn = true,
  }) async* {
    yield RouterTextDelta(responseText);
  }
}


void main() {
  group('ClipperPipeline with Fakes', () {
    late ClipDatabase db;
    late FakeDownloader downloader;
    late FakeTranscriber transcriber;
    late FakeExporter exporter;
    late MomentAnalyzer analyzer;
    late ClipperPipeline pipeline;

    const validJsonResponse = '''
```json
[
  {
    "title": "Momen Viral Seru",
    "start_seconds": 15,
    "end_seconds": 45,
    "score": 95,
    "reason": "Punchline kuat dan emosi tinggi"
  }
]
```
''';

    setUp(() {
      db = ClipDatabase.inMemory();
      downloader = FakeDownloader();
      transcriber = FakeTranscriber();
      exporter = FakeExporter();
      analyzer = MomentAnalyzer(
        routerClient: FakeRouterClient(responseText: validJsonResponse),
        modelOrCombo: 'fake-model',
        apiKeys: {'fake': 'key'},
      );

      pipeline = ClipperPipeline(
        downloader: downloader,
        transcriber: transcriber,
        analyzer: analyzer,
        exporter: exporter,
        database: db,
      );
    });

    tearDown(() {
      db.dispose();
    });

    test('full pipeline run succeeds with all stages and updates db', () async {
      final initialJob = VideoJob(
        id: 'job_pipeline_1',
        url: 'https://youtube.com/watch?v=abc',
        createdAt: DateTime.now(),
      );

      final stages = <VideoJobStatus>[];
      final progressList = <double>[];

      await for (final progress in pipeline.run(
        initialJob,
        jobDir: Directory('/fake/job/dir'),
      )) {
        stages.add(progress.stage);
        progressList.add(progress.fraction);
      }

      // Urutan stage
      expect(stages, [
        VideoJobStatus.downloading, // awal download
        VideoJobStatus.downloading, // akhir download
        VideoJobStatus.transcribing, // awal transkrip
        VideoJobStatus.transcribing, // akhir transkrip
        VideoJobStatus.analyzing,   // awal analisis
        VideoJobStatus.done,        // selesai
      ]);

      // Kandidat klip terisi
      expect(pipeline.candidates.length, 1);
      expect(pipeline.candidates.first.title, 'Momen Viral Seru');
      expect(pipeline.candidates.first.score, 95);

      // Verifikasi di ClipDatabase
      final savedJob = db.getJob('job_pipeline_1');
      expect(savedJob, isNotNull);
      expect(savedJob!.status, VideoJobStatus.done);
      expect(savedJob.progress, 1.0);
      expect(savedJob.title, 'Video Uji Coba');

      final savedCandidates = db.getCandidates('job_pipeline_1');
      expect(savedCandidates.length, 1);
      expect(savedCandidates.first.title, 'Momen Viral Seru');
    });

    test('stage error marks job as error in db and emits error progress', () async {
      downloader.shouldThrow = true;

      final initialJob = VideoJob(
        id: 'job_pipeline_error',
        url: 'https://youtube.com/watch?v=abc',
        createdAt: DateTime.now(),
      );

      JobProgress? lastProgress;

      try {
        await for (final p in pipeline.run(initialJob, jobDir: Directory('/fake/dir'))) {
          lastProgress = p;
        }
        fail('Pipeline seharusnya melempar Exception');
      } catch (e) {
        expect(e, isA<Exception>());
      }

      final savedJob = db.getJob('job_pipeline_error');
      expect(savedJob, isNotNull);
      expect(savedJob!.status, VideoJobStatus.error);
      expect(savedJob.errorMessage, contains('Simulasi gagal download'));
      expect(lastProgress?.stage, VideoJobStatus.error);
    });

    test('cancellation aborts pipeline early with OperationCancelledException', () async {
      final cancel = CancelToken();
      cancel.cancel(); // Pre-cancelled

      final initialJob = VideoJob(
        id: 'job_cancelled',
        url: 'https://youtube.com/watch?v=abc',
        createdAt: DateTime.now(),
      );

      expect(
        () => pipeline.run(initialJob, jobDir: Directory('/fake/dir'), cancel: cancel).toList(),
        throwsA(isA<OperationCancelledException>()),
      );
    });

    test('exportClip delegates to exporter and returns path', () async {
      final candidate = ClipCandidate(
        title: 'Clip 1',
        startTime: const Duration(seconds: 10),
        endTime: const Duration(seconds: 40),
        score: 85,
        reason: 'Reason',
      );

      final exportedPath = await pipeline.exportClip(
        candidate,
        outDir: Directory('/out'),
        customVideoPath: '/temp/video.mp4',
      );

      expect(exportedPath, contains('/out/clip_10-40.mp4'));
    });
  });
}
