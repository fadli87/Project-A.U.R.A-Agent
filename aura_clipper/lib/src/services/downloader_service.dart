import 'dart:io';
import 'package:path/path.dart' as path;

class DownloaderService {
  final String ytDlpPath;

  DownloaderService({required this.ytDlpPath});

  /// Mendownload video dari [url] dan menyimpannya di [outputDir].
  /// Mengembalikan path absolut ke file video yang di-download.
  Future<String> downloadVideo(String url, String outputDir) async {
    final outputTemplate = path.join(outputDir, '%(title)s.%(ext)s');
    
    // Gunakan format resolusi yang wajar (misal <= 1080p) agar cepat didownload & proses
    final result = await Process.run(
      ytDlpPath,
      [
        '-f', 'bestvideo[height<=1080]+bestaudio/best[height<=1080]/best',
        '-o', outputTemplate,
        '--no-playlist',
        '--print', 'after_move:filepath', // Cuma output path file akhir
        url,
      ],
    );

    if (result.exitCode != 0) {
      throw Exception('Gagal mendownload video: ${result.stderr}');
    }

    // Ambil baris terakhir dari stdout sebagai path file
    final lines = result.stdout.toString().trim().split('\n');
    final filePath = lines.isNotEmpty ? lines.last.trim() : '';

    if (filePath.isEmpty || !File(filePath).existsSync()) {
      throw Exception('Video berhasil didownload tapi tidak ditemukan di path: $filePath');
    }

    return filePath;
  }
}
