import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/clip_candidate.dart';

class ClipExporter {
  final String ffmpegPath;

  ClipExporter({required this.ffmpegPath});

  /// Mengekspor potongan video dari [sourceVideoPath] berdasarkan [candidate].
  /// Mengembalikan path absolut ke file klip video hasil ekspor.
  Future<String> exportClip(String sourceVideoPath, ClipCandidate candidate) async {
    final videoFile = File(sourceVideoPath);
    final videoDir = videoFile.parent.path;
    final baseName = path.basenameWithoutExtension(sourceVideoPath);
    
    // Format nama file: baseName_00m00s_to_00m30s.mp4
    final startStr = '${candidate.startTime.inMinutes}m${(candidate.startTime.inSeconds % 60).toString().padLeft(2, '0')}s';
    final endStr = '${candidate.endTime.inMinutes}m${(candidate.endTime.inSeconds % 60).toString().padLeft(2, '0')}s';
    final outputFileName = '${baseName}_${startStr}_to_$endStr.mp4';
    final outputPath = path.join(videoDir, outputFileName);
    
    // Potong video tanpa re-encode (fast, lossless) jika format aslinya memungkinkan,
    // tapi karena kliping presisi sering butuh re-encode untuk akurasi frame-level, 
    // kita tetap encode ulang dengan setting standar.
    // -ss (start), -to (end)
    final result = await Process.run(
      ffmpegPath,
      [
        '-y', // Timpa file jika sudah ada
        '-i', sourceVideoPath,
        '-ss', candidate.startTime.inSeconds.toString(),
        '-to', candidate.endTime.inSeconds.toString(),
        '-c:v', 'libx264',
        '-preset', 'fast',
        '-c:a', 'aac',
        outputPath,
      ],
    );

    if (result.exitCode != 0) {
      throw Exception('Gagal mengekspor klip: ${result.stderr}');
    }

    if (!File(outputPath).existsSync()) {
      throw Exception('File ekspor tidak ditemukan: $outputPath');
    }

    return outputPath;
  }
}
