import 'dart:async';
import 'dart:io';
import '../models/video_job.dart';
import '../models/clip_candidate.dart';
import '../analysis/moment_analyzer.dart';
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
  }) async* {
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
      yield const JobProgress(
        stage: VideoJobStatus.downloading,
        fraction: 0.0,
        message: 'Memulai pengunduhan video...',
      );

      final downloadResult = await downloader.download(
        job.url,
        jobDir: jobDir,
        cancel: cancel,
        onProgress: (fraction) {
          job = job.copyWith(progress: (fraction * 0.33).clamp(0.0, 0.33), updatedAt: DateTime.now());
          _currentJob = job;
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
      yield JobProgress(
        stage: VideoJobStatus.downloading,
        fraction: 0.33,
        message: 'Video berhasil diunduh: ${downloadResult.title}',
      );

      // 2. Transcribe Stage
      job = job.copyWith(
        status: VideoJobStatus.transcribing,
        progress: 0.33,
        updatedAt: DateTime.now(),
      );
      _currentJob = job;
      database?.saveJob(job);
      yield const JobProgress(
        stage: VideoJobStatus.transcribing,
        fraction: 0.33,
        message: 'Memulai transkripsi audio...',
      );

      final transcript = await transcriber.transcribe(
        downloadResult.videoPath,
        cancel: cancel,
        onProgress: (fraction) {
          job = job.copyWith(
            progress: (0.33 + (fraction * 0.33)).clamp(0.33, 0.66),
            updatedAt: DateTime.now(),
          );
          _currentJob = job;
        },
      );

      cancel?.throwIfCancelled();
      job = job.copyWith(progress: 0.66, updatedAt: DateTime.now());
      _currentJob = job;
      database?.saveJob(job);
      yield JobProgress(
        stage: VideoJobStatus.transcribing,
        fraction: 0.66,
        message: 'Transkripsi selesai (${transcript.segments.length} segmen).',
      );

      // 3. Analyze Stage
      job = job.copyWith(
        status: VideoJobStatus.analyzing,
        progress: 0.66,
        updatedAt: DateTime.now(),
      );
      _currentJob = job;
      database?.saveJob(job);
      yield const JobProgress(
        stage: VideoJobStatus.analyzing,
        fraction: 0.66,
        message: 'Menganalisis momen viral dengan AI...',
      );

      final analyzedCandidates = await analyzer.analyze(
        transcript,
        options: options,
        cancel: cancel,
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
      yield JobProgress(
        stage: VideoJobStatus.done,
        fraction: 1.0,
        message: 'Analisis selesai, ${analyzedCandidates.length} momen ditemukan.',
      );
    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      job = job.copyWith(
        status: VideoJobStatus.error,
        errorMessage: errorMsg,
        updatedAt: DateTime.now(),
      );
      _currentJob = job;
      database?.saveJob(job);
      yield JobProgress(
        stage: VideoJobStatus.error,
        fraction: job.progress,
        message: 'Error: $errorMsg',
      );
      rethrow;
    }
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
