import 'dart:io';
import 'package:path/path.dart' as path;

class TranscriberService {
  final String whisperPath;
  final String whisperModelName;
  final String ffmpegPath;

  TranscriberService({
    required this.whisperPath,
    required this.ffmpegPath,
    this.whisperModelName = 'ggml-base.en.bin',
  });

  /// Mentranskripsi video di [videoPath] menggunakan Whisper.cpp.
  /// Audio diekstrak dulu menggunakan FFmpeg (16kHz WAV).
  /// Mengembalikan path absolut ke file transcript (JSON atau SRT).
  Future<String> transcribeVideo(String videoPath) async {
    final videoFile = File(videoPath);
    final videoDir = videoFile.parent.path;
    final baseName = path.basenameWithoutExtension(videoPath);
    
    // 1. Ekstrak audio ke 16kHz WAV (syarat whisper.cpp)
    final wavPath = path.join(videoDir, '$baseName.wav');
    final ffmpegResult = await Process.run(
      ffmpegPath,
      [
        '-i', videoPath,
        '-ar', '16000',
        '-ac', '1',
        '-c:a', 'pcm_s16le',
        '-y', // Timpa file kalau sudah ada
        wavPath,
      ],
    );

    if (ffmpegResult.exitCode != 0) {
      throw Exception('Gagal mengekstrak audio: ${ffmpegResult.stderr}');
    }

    // 2. Jalankan whisper.cpp
    // Path model diasumsikan relatif terhadap folder executable whisper.cpp
    final whisperDir = File(whisperPath).parent.path;
    final modelPath = path.join(whisperDir, 'models', whisperModelName);
    
    final whisperResult = await Process.run(
      whisperPath,
      [
        '-m', modelPath,
        '-f', wavPath,
        '--output-json', // Hasilkan output JSON
        '--output-file', path.join(videoDir, baseName), // Ekstensi .json akan ditambahkan otomatis
      ],
    );

    if (whisperResult.exitCode != 0) {
      throw Exception('Gagal mentranskripsi audio: ${whisperResult.stderr}');
    }

    // Output default dari whisper.cpp jika --output-json adalah baseName.json
    final jsonPath = path.join(videoDir, '$baseName.json');
    if (!File(jsonPath).existsSync()) {
      throw Exception('File transkripsi tidak ditemukan: $jsonPath');
    }

    // Bersihkan file WAV sementara
    try {
      await File(wavPath).delete();
    } catch (_) {
      // Abaikan jika gagal hapus sementara
    }

    return jsonPath;
  }
}
