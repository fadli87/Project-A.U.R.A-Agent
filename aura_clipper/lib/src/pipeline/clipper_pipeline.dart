import 'dart:async';
import 'dart:io';
import '../models/video_job.dart';
import '../models/clip_candidate.dart';
import '../analysis/moment_analyzer.dart';
import '../analysis/transcript_enricher.dart';
import '../desktop/whisper_cpp_transcriber.dart';
import '../storage/clip_database.dart';
import 'interfaces.dart';

class ClipperPipeline {
  final Downloader downloader;
  final Transcriber transcriber;
  final MomentAnalyzer analyzer;
  final Exporter exporter;
  final ClipDatabase? database;

  List<ClipCandidate> _candidates = [];
  VideoJob? _currentJob;

  ClipperPipeline({
    required this.downloader,
    required this.transcriber,
    required this.analyzer,
    required this.exporter,
    this.database,
  });

  List<ClipCandidate> get candidates => List.unmodifiable(_candidates);
  VideoJob? get currentJob => _currentJob;

  /// Menjalankan pipeline pembuatan klip secara utuh (download -> transcribe -> analyze).
  /// Mengalirkan progres secara real-time via `Stream<JobProgress>`.
  Stream<JobProgress> run(
    VideoJob initialJob, {
    required Directory jobDir,
    AnalysisOptions? options,
    CancelToken? cancel,
    String? language,
  }) {
    final controller = StreamController<JobProgress>();

    () async {
      _candidates = [];
      var job = initialJob.copyWith(
        status: VideoJobStatus.pending,
        progress: 0.0,
        updatedAt: DateTime.now(),
      );
      _currentJob = job;
      database?.saveJob(job);

      try {
        cancel?.throwIfCancelled();

        // 1. Download Stage
        job = job.copyWith(
          status: VideoJobStatus.downloading,
          progress: 0.0,
          updatedAt: DateTime.now(),
        );
        _currentJob = job;
        database?.saveJob(job);
        controller.add(const JobProgress(
          stage: VideoJobStatus.downloading,
          fraction: 0.0,
          message: 'Memulai pengunduhan video...',
        ));

        final downloadResult = await downloader.download(
          job.url,
          jobDir: jobDir,
          cancel: cancel,
          onProgress: (fraction) {
            final overallProgress = (fraction * 0.33).clamp(0.0, 0.33);
            job = job.copyWith(progress: overallProgress, updatedAt: DateTime.now());
            _currentJob = job;
            controller.add(JobProgress(
              stage: VideoJobStatus.downloading,
              fraction: overallProgress,
              message: 'Mengunduh video ${(fraction * 100).toInt()}%',
            ));
          },
        );

        cancel?.throwIfCancelled();
        job = job.copyWith(
          localVideoPath: downloadResult.videoPath,
          title: downloadResult.title,
          durationSeconds: downloadResult.durationSeconds,
          progress: 0.33,
          updatedAt: DateTime.now(),
        );
        _currentJob = job;
        database?.saveJob(job);
        controller.add(JobProgress(
          stage: VideoJobStatus.downloading,
          fraction: 0.33,
          message: 'Video berhasil diunduh: ${downloadResult.title}',
        ));

        // 2. Transcribe Stage
        job = job.copyWith(
          status: VideoJobStatus.transcribing,
          progress: 0.33,
          updatedAt: DateTime.now(),
        );
        _currentJob = job;
        database?.saveJob(job);
        controller.add(const JobProgress(
          stage: VideoJobStatus.transcribing,
          fraction: 0.33,
          message: 'Memulai transkripsi...',
        ));

        Transcript rawTranscript;

        // Gunakan YouTube caption (json3) jika ada; bypass Whisper untuk efisiensi
        File? captionFile;
        if (downloadResult.captionPath != null && File(downloadResult.captionPath!).existsSync()) {
          captionFile = File(downloadResult.captionPath!);
        } else {
          try {
            final json3List = jobDir
                .listSync()
                .whereType<File>()
                .where((f) => f.path.endsWith('.json3'))
                .toList();
            if (json3List.isNotEmpty) {
              captionFile = json3List.first;
            }
          } catch (_) {}
        }

        if (captionFile != null) {
          try {
            final jsonContent = await captionFile.readAsString();
            rawTranscript = WhisperCppTranscriber.parseJson3(jsonContent);
            job = job.copyWith(transcriptPath: captionFile.path, updatedAt: DateTime.now());
            controller.add(const JobProgress(
              stage: VideoJobStatus.transcribing,
              fraction: 0.66,
              message: 'Caption YouTube berhasil digunakan (bypassing Whisper).',
            ));
          } catch (_) {
            rawTranscript = await _runWhisperTranscriber(
              downloadResult.videoPath,
              language: language,
              cancel: cancel,
              onProgressFraction: (p) => controller.add(p),
            );
          }
        } else {
          rawTranscript = await _runWhisperTranscriber(
            downloadResult.videoPath,
            language: language,
            cancel: cancel,
            onProgressFraction: (p) => controller.add(p),
          );
        }

        cancel?.throwIfCancelled();

        // 2.5 Pengayaan transkrip (merge kalimat pendek + overlay heatmap YouTube)
        final enrichedTranscript = TranscriptEnricher.enrich(
          rawTranscript,
          heatmap: downloadResult.heatmap,
        );

        job = job.copyWith(progress: 0.66, updatedAt: DateTime.now());
        _currentJob = job;
        database?.saveJob(job);
        controller.add(JobProgress(
          stage: VideoJobStatus.transcribing,
          fraction: 0.66,
          message: 'Transkripsi & pengayaan selesai (${enrichedTranscript.segments.length} segmen).',
        ));

        // 3. Analyze Stage
        job = job.copyWith(
          status: VideoJobStatus.analyzing,
          progress: 0.66,
          updatedAt: DateTime.now(),
        );
        _currentJob = job;
        database?.saveJob(job);
        controller.add(const JobProgress(
          stage: VideoJobStatus.analyzing,
          fraction: 0.66,
          message: 'Menganalisis momen viral dengan AI...',
        ));

        final analyzedCandidates = await analyzer.analyze(
          enrichedTranscript,
          options: options,
          cancel: cancel,
          jobDir: jobDir,
        );

        cancel?.throwIfCancelled();
        _candidates = analyzedCandidates;
        database?.saveCandidates(job.id, analyzedCandidates);

        // 4. Done Stage
        job = job.copyWith(
          status: VideoJobStatus.done,
          progress: 1.0,
          updatedAt: DateTime.now(),
        );
        _currentJob = job;
        database?.saveJob(job);
        controller.add(JobProgress(
          stage: VideoJobStatus.done,
          fraction: 1.0,
          message: 'Analisis selesai, ${analyzedCandidates.length} momen ditemukan.',
        ));
      } on OperationCancelledException catch (e) {
        job = job.copyWith(
          status: VideoJobStatus.cancelled,
          errorMessage: e.message,
          updatedAt: DateTime.now(),
        );
        _currentJob = job;
        database?.saveJob(job);
        controller.add(JobProgress(
          stage: VideoJobStatus.cancelled,
          fraction: job.progress,
          message: 'Operasi dibatalkan oleh user.',
        ));
        controller.addError(e);
      } catch (e, st) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        job = job.copyWith(
          status: VideoJobStatus.error,
          errorMessage: errorMsg,
          updatedAt: DateTime.now(),
        );
        _currentJob = job;
        database?.saveJob(job);
        controller.add(JobProgress(
          stage: VideoJobStatus.error,
          fraction: job.progress,
          message: 'Error: $errorMsg',
        ));
        controller.addError(e, st);
      } finally {
        await controller.close();
      }
    }();

    return controller.stream;
  }

  Future<Transcript> _runWhisperTranscriber(
    String videoPath, {
    String? language,
    CancelToken? cancel,
    required void Function(JobProgress progress) onProgressFraction,
  }) async {
    return await transcriber.transcribe(
      videoPath,
      language: language,
      cancel: cancel,
      onProgress: (fraction) {
        final overallProgress = (0.33 + (fraction * 0.33)).clamp(0.33, 0.66);
        onProgressFraction(JobProgress(
          stage: VideoJobStatus.transcribing,
          fraction: overallProgress,
          message: 'Mentranskripsi audio ${(fraction * 100).toInt()}%',
        ));
      },
    );
  }

  /// Mengekspor klip yang dipilih ke direktori tujuan.
  Future<String> exportClip(
    ClipCandidate candidate, {
    required Directory outDir,
    String? customVideoPath,
    CancelToken? cancel,
  }) async {
    final videoPath = customVideoPath ?? _currentJob?.localVideoPath;
    if (videoPath == null || videoPath.isEmpty) {
      throw Exception('Path video lokal tidak tersedia untuk diekspor.');
    }
    return await exporter.export(videoPath, candidate, outDir: outDir, cancel: cancel);
  }
}
