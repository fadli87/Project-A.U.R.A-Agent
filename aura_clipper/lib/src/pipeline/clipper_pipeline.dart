import 'dart:async';
import '../models/video_job.dart';
import '../models/clip_candidate.dart';
import '../services/downloader_service.dart';
import '../services/transcriber_service.dart';
import '../services/moment_analyzer.dart';
import '../services/clip_exporter.dart';

class ClipperPipeline {
  final DownloaderService downloader;
  final TranscriberService transcriber;
  final MomentAnalyzer analyzer;
  final ClipExporter exporter;

  ClipperPipeline({
    required this.downloader,
    required this.transcriber,
    required this.analyzer,
    required this.exporter,
  });

  /// Menjalankan pipeline pembuatan klip secara utuh (download -> transcribe -> analyze).
  /// Fungsi panggilan balik [onProgress] dipanggil setiap kali status job berubah.
  Future<List<ClipCandidate>> runPipeline(
    VideoJob initialJob, {
    required String outputDir,
    required Function(VideoJob updatedJob) onProgress,
  }) async {
    VideoJob job = initialJob;
    try {
      // 1. Download
      job = job.copyWith(status: VideoJobStatus.downloading, updatedAt: DateTime.now());
      onProgress(job);
      final videoPath = await downloader.downloadVideo(job.url, outputDir);
      job = job.copyWith(localVideoPath: videoPath, updatedAt: DateTime.now());

      // 2. Transcribe
      job = job.copyWith(status: VideoJobStatus.transcribing, updatedAt: DateTime.now());
      onProgress(job);
      final transcriptPath = await transcriber.transcribeVideo(videoPath);
      job = job.copyWith(transcriptPath: transcriptPath, updatedAt: DateTime.now());

      // 3. Analyze
      job = job.copyWith(status: VideoJobStatus.analyzing, updatedAt: DateTime.now());
      onProgress(job);
      final candidates = await analyzer.analyzeTranscript(transcriptPath);

      // 4. Done
      job = job.copyWith(status: VideoJobStatus.done, updatedAt: DateTime.now());
      onProgress(job);

      return candidates;
    } catch (e) {
      job = job.copyWith(
        status: VideoJobStatus.error,
        errorMessage: e.toString(),
        updatedAt: DateTime.now(),
      );
      onProgress(job);
      throw Exception('Pipeline gagal: $e');
    }
  }

  /// Mengekspor klip yang dipilih oleh user.
  Future<String> exportSelectedClip(VideoJob job, ClipCandidate candidate) async {
    if (job.localVideoPath == null) {
      throw Exception('Path video lokal tidak tersedia untuk diekspor.');
    }
    return await exporter.exportClip(job.localVideoPath!, candidate);
  }
}
