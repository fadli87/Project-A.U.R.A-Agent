import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../pipeline/interfaces.dart';
import 'process_runner.dart';

class YtDlpDownloader implements Downloader {
  final String ytDlpPath;
  final ProcessRunner runner;
  final List<String> allowedHosts;

  YtDlpDownloader({
    required this.ytDlpPath,
    ProcessRunner? runner,
    List<String>? allowedHosts,
  })  : runner = runner ?? const DesktopProcessRunner(),
        allowedHosts = allowedHosts ?? const ['youtube.com', 'www.youtube.com', 'youtu.be', 'm.youtube.com'];

  /// Validasi URL: hanya http/https dan host yang terdaftar.
  static bool isValidUrl(String rawUrl, List<String> allowedHosts) {
    try {
      final uri = Uri.parse(rawUrl);
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return false;
      }
      final host = uri.host.toLowerCase();
      return allowedHosts.any((allowed) => host == allowed || host.endsWith('.$allowed'));
    } catch (_) {
      return false;
    }
  }

  /// Membangun argumen yt-dlp untuk dump json (metadata & heatmap).
  static List<String> buildDumpJsonArgs({required String url}) {
    return [
      '--dump-json',
      '--no-playlist',
      '--',
      url,
    ];
  }

  /// Membangun argumen yt-dlp untuk mendownload video.
  static List<String> buildDownloadArgs({
    required String url,
    required String outputTemplate,
  }) {
    return [
      '-f',
      'bestvideo[height<=1080]+bestaudio/best[height<=1080]/best',
      '-o',
      outputTemplate,
      '--no-playlist',
      '--newline',
      '--print',
      'after_move:filepath',
      '--',
      url,
    ];
  }

  /// Mem-parse persentase progres dari baris stdout yt-dlp.
  static double? parseProgress(String line) {
    // Pola contoh: [download]  45.2% of 12.34MiB at ...
    final match = RegExp(r'\[download\]\s+([\d\.]+)%').firstMatch(line);
    if (match != null) {
      final pct = double.tryParse(match.group(1)!);
      if (pct != null) {
        return (pct / 100.0).clamp(0.0, 1.0);
      }
    }
    return null;
  }

  @override
  Future<DownloadResult> download(
    String url, {
    required Directory jobDir,
    CancelToken? cancel,
    void Function(double fraction)? onProgress,
  }) async {
    cancel?.throwIfCancelled();

    if (!isValidUrl(url, allowedHosts)) {
      throw ArgumentError('URL tidak valid atau domain tidak diizinkan: $url');
    }

    if (!await jobDir.exists()) {
      await jobDir.create(recursive: true);
    }

    // 1. Ambil metadata (title, duration, heatmap) bila memungkinkan
    String title = 'Video_${DateTime.now().millisecondsSinceEpoch}';
    int duration = 0;
    List<HeatmapPoint>? heatmap;

    try {
      final metaResult = await runner.run(
        ytDlpPath,
        buildDumpJsonArgs(url: url),
        workingDirectory: jobDir.path,
        cancel: cancel,
      );

      if (metaResult.isSuccess && metaResult.stdout.trim().isNotEmpty) {
        final json = jsonDecode(metaResult.stdout.trim()) as Map<String, dynamic>;
        title = json['title'] as String? ?? title;
        duration = (json['duration'] as num?)?.toInt() ?? 0;

        if (json.containsKey('heatmap') && json['heatmap'] is List) {
          final rawHeatmap = json['heatmap'] as List;
          heatmap = rawHeatmap
              .whereType<Map<String, dynamic>>()
              .map(HeatmapPoint.fromJson)
              .toList();
        }
      }
    } catch (_) {
      // Dump json opsional jika gagal, lanjut ke proses download
    }

    cancel?.throwIfCancelled();

    // 2. Download video
    final outputTemplate = p.join(jobDir.path, '%(id)s.%(ext)s');
    final args = buildDownloadArgs(url: url, outputTemplate: outputTemplate);

    String? capturedFilePath;

    final result = await runner.run(
      ytDlpPath,
      args,
      workingDirectory: jobDir.path,
      cancel: cancel,
      onStdout: (line) {
        final fraction = parseProgress(line);
        if (fraction != null) {
          onProgress?.call(fraction);
        }
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('[download]') && !trimmed.startsWith('[info]')) {
          capturedFilePath = trimmed;
        }
      },
    );

    if (!result.isSuccess) {
      throw Exception('Gagal mendownload video via yt-dlp: ${result.stderr}');
    }

    // Cari file hasil jika capturedFilePath belum valid
    String finalPath = capturedFilePath ?? '';
    if (finalPath.isEmpty || !await File(finalPath).exists()) {
      final files = await jobDir.list().toList();
      final videoFiles = files.whereType<File>().where((f) {
        final ext = p.extension(f.path).toLowerCase();
        return ['.mp4', '.mkv', '.webm'].contains(ext) && !f.path.endsWith('.part');
      }).toList();

      if (videoFiles.isNotEmpty) {
        // Ambil file terbaru
        videoFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        finalPath = videoFiles.first.path;
      }
    }

    if (finalPath.isEmpty || !await File(finalPath).exists()) {
      throw Exception('File video hasil download tidak ditemukan di ${jobDir.path}');
    }

    onProgress?.call(1.0);

    return DownloadResult(
      videoPath: finalPath,
      durationSeconds: duration,
      title: title,
      heatmap: heatmap,
    );
  }
}
