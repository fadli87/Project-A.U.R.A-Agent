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

  /// Membangun argumen yt-dlp untuk download auto subtitles (format json3).
  /// Memastikan argumen tidak pernah memuat 'all' untuk mencegah unduhan massal & HTTP 429.
  static List<String> buildSubtitlesArgs({
    required String url,
    required String outputTemplate,
    String language = 'id',
    bool writeManualSubs = true,
    bool writeAutoSubs = true,
  }) {
    if (language.contains('all')) {
      throw ArgumentError('Argumen language tidak boleh memuat "all" untuk mencegah unduhan massal.');
    }
    final args = <String>[];
    if (writeManualSubs) args.add('--write-subs');
    if (writeAutoSubs) args.add('--write-auto-subs');
    args.addAll([
      '--sub-langs',
      language,
      '--sub-format',
      'json3',
      '--skip-download',
      '-o',
      outputTemplate,
      '--no-playlist',
      '--',
      url,
    ]);
    return args;
  }

  /// Mencari file caption .json3 yang cocok dengan target bahasa yang diminta.
  /// Tidak pernah memilih file sembarang (.first); jika tidak ada yang cocok -> return null.
  static File? resolveCaptionFile(
    Directory jobDir,
    String targetLang, {
    String? videoId,
  }) {
    if (!jobDir.existsSync()) return null;

    final baseLang = targetLang.replaceAll('-orig', '').toLowerCase();
    final files = jobDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json3'))
        .toList();

    for (final file in files) {
      final name = p.basename(file.path);
      // Format nama yt-dlp: <id>.<lang>.json3
      if (videoId != null && !name.startsWith(videoId)) {
        continue;
      }

      final parts = name.split('.');
      if (parts.length >= 3) {
        final fileLang = parts[parts.length - 2].toLowerCase();
        if (fileLang == targetLang.toLowerCase() ||
            fileLang == baseLang ||
            fileLang == '$baseLang-orig') {
          return file;
        }
      }
    }

    return null;
  }

  /// Membangun argumen yt-dlp untuk mendownload video.
  /// Menambahkan --progress secara eksplisit agar progres download tetap keluar meski ada --print.
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
      '--progress',
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

  /// Membersihkan file `.part` sementara di jobDir saat pembatalan atau error.
  static void cleanupPartFiles(Directory jobDir) {
    try {
      if (jobDir.existsSync()) {
        final entries = jobDir.listSync();
        for (final entry in entries) {
          if (entry is File && entry.path.endsWith('.part')) {
            try {
              entry.deleteSync();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  @override
  Future<DownloadResult> download(
    String url, {
    required Directory jobDir,
    CancelToken? cancel,
    void Function(double fraction)? onProgress,
    String? language,
  }) async {
    cancel?.throwIfCancelled();

    if (!isValidUrl(url, allowedHosts)) {
      throw ArgumentError('URL tidak valid atau domain tidak diizinkan: $url');
    }

    if (!await jobDir.exists()) {
      await jobDir.create(recursive: true);
    }

    // 1. Ambil metadata (title, duration, heatmap, videoId, subtitles) bila memungkinkan
    String title = 'Video_${DateTime.now().millisecondsSinceEpoch}';
    int duration = 0;
    List<HeatmapPoint>? heatmap;
    String? videoId;
    String? detectedLanguage;
    String? originalCaptionLang;
    bool hasManualSubForLang = false;

    try {
      final metaResult = await runner.run(
        ytDlpPath,
        buildDumpJsonArgs(url: url),
        workingDirectory: jobDir.path,
        cancel: cancel,
      );

      if (metaResult.isSuccess && metaResult.stdout.trim().isNotEmpty) {
        // Ambil baris JSON pertama yang valid dari stdout
        final lines = metaResult.stdout.trim().split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
            try {
              final json = jsonDecode(trimmed) as Map<String, dynamic>;
              title = json['title'] as String? ?? title;
              duration = (json['duration'] as num?)?.toInt() ?? 0;
              videoId = json['id'] as String?;
              detectedLanguage = json['language'] as String?;

              // Periksa dan parse heatmap jika tersedia di dump-json
              if (json['heatmap'] is List) {
                final rawHeatmap = json['heatmap'] as List;
                heatmap = rawHeatmap
                    .whereType<Map>()
                    .map((item) => HeatmapPoint.fromJson(Map<String, dynamic>.from(item)))
                    .toList();
              }

              // Periksa automatic_captions untuk original language (-orig)
              if (json['automatic_captions'] is Map) {
                final autoMap = json['automatic_captions'] as Map<String, dynamic>;
                for (final key in autoMap.keys) {
                  if (key.endsWith('-orig')) {
                    originalCaptionLang = key;
                    break;
                  }
                }
              }

              // Periksa manual subtitles
              if (json['subtitles'] is Map) {
                final subMap = json['subtitles'] as Map<String, dynamic>;
                if (subMap.isNotEmpty) {
                  final candidateLang = (language != null && language != 'auto')
                      ? language
                      : (originalCaptionLang?.replaceAll('-orig', '') ?? detectedLanguage ?? 'id');
                  if (subMap.containsKey(candidateLang) || subMap.containsKey('$candidateLang-orig')) {
                    hasManualSubForLang = true;
                  }
                }
              }
              break;
            } catch (_) {}
          }
        }
      }
    } catch (_) {
      // Dump json opsional jika gagal, lanjut ke langkah berikutnya
    }

    cancel?.throwIfCancelled();

    // 2. Coba unduh subtitle/caption YouTube terlebih dahulu (json3)
    String? captionPath;
    try {
      // Tentukan satu bahasa spesifik yang diminta
      String targetLang;
      if (language != null && language != 'auto' && language.trim().isNotEmpty) {
        targetLang = language.trim();
      } else if (hasManualSubForLang) {
        targetLang = originalCaptionLang?.replaceAll('-orig', '') ?? detectedLanguage ?? 'id';
      } else if (originalCaptionLang != null) {
        targetLang = originalCaptionLang;
      } else if (detectedLanguage != null && detectedLanguage.isNotEmpty) {
        targetLang = detectedLanguage;
      } else {
        targetLang = 'id';
      }

      final subTemplate = p.join(jobDir.path, '%(id)s.%(ext)s');
      final subArgs = buildSubtitlesArgs(
        url: url,
        outputTemplate: subTemplate,
        language: targetLang,
        writeManualSubs: true,
        writeAutoSubs: true,
      );

      await runner.run(
        ytDlpPath,
        subArgs,
        workingDirectory: jobDir.path,
        cancel: cancel,
      );

      // Cari file caption yang cocok dengan bahasa target
      final resolved = resolveCaptionFile(jobDir, targetLang, videoId: videoId);
      if (resolved != null && resolved.existsSync()) {
        captionPath = resolved.path;
      }
    } catch (_) {
      // Subtitle opsional, Whisper akan jadi fallback jika tidak ada captionPath yang cocok
    }

    cancel?.throwIfCancelled();

    // 3. Download video
    final outputTemplate = p.join(jobDir.path, '%(id)s.%(ext)s');
    final args = buildDownloadArgs(url: url, outputTemplate: outputTemplate);

    String? capturedFilePath;

    try {
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
          if (trimmed.isNotEmpty &&
              !trimmed.startsWith('[download]') &&
              !trimmed.startsWith('[info]') &&
              !trimmed.startsWith('WARNING:')) {
            capturedFilePath = trimmed;
          }
        },
      );

      if (!result.isSuccess) {
        cleanupPartFiles(jobDir);
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
          videoFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
          finalPath = videoFiles.first.path;
        }
      }

      if (finalPath.isEmpty || !await File(finalPath).exists()) {
        cleanupPartFiles(jobDir);
        throw Exception('File video hasil download tidak ditemukan di ${jobDir.path}');
      }

      onProgress?.call(1.0);

      return DownloadResult(
        videoPath: finalPath,
        durationSeconds: duration,
        title: title,
        heatmap: heatmap,
        captionPath: captionPath,
      );
    } catch (e) {
      cleanupPartFiles(jobDir);
      rethrow;
    }
  }
}
