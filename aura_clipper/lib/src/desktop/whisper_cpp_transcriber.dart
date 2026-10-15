import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../pipeline/interfaces.dart';
import 'process_runner.dart';

class WhisperCppTranscriber implements Transcriber {
  final String whisperPath;
  final String ffmpegPath;
  final String whisperModelName;
  final String? whisperModelsDir;
  final ProcessRunner runner;

  WhisperCppTranscriber({
    required this.whisperPath,
    required this.ffmpegPath,
    this.whisperModelName = 'ggml-base.bin',
    this.whisperModelsDir,
    ProcessRunner? runner,
  }) : runner = runner ?? const DesktopProcessRunner();

  /// Argumen ffmpeg untuk ekstrak audio ke 16 kHz mono WAV (keperluan Whisper).
  static List<String> buildFfmpegExtractArgs({
    required String videoPath,
    required String wavPath,
  }) {
    return [
      '-y',
      '-i',
      videoPath,
      '-ar',
      '16000',
      '-ac',
      '1',
      '-c:a',
      'pcm_s16le',
      wavPath,
    ];
  }

  /// Argumen whisper.cpp untuk transkripsi ke JSON.
  static List<String> buildWhisperArgs({
    required String modelPath,
    required String wavPath,
    required String outputPrefix,
    String? language,
  }) {
    final args = [
      '-m',
      modelPath,
      '-f',
      wavPath,
      '--output-json',
      '--output-file',
      outputPrefix,
    ];

    if (language != null && language.isNotEmpty && language != 'auto') {
      args.addAll(['-l', language]);
    }

    return args;
  }

  /// Parse output JSON whisper.cpp menjadi Transcript netral.
  static Transcript parseWhisperJson(String jsonContent) {
    final parsed = jsonDecode(jsonContent);
    final segments = <TranscriptSegment>[];

    if (parsed is Map && parsed.containsKey('transcription')) {
      final list = parsed['transcription'] as List;
      for (final item in list) {
        if (item is Map) {
          final startMs = (item['offsets']?['from'] as num?)?.toDouble() ?? 0.0;
          final endMs = (item['offsets']?['to'] as num?)?.toDouble() ?? 0.0;
          final text = (item['text'] as String? ?? '').trim();

          segments.add(TranscriptSegment(
            start: startMs / 1000.0,
            end: endMs / 1000.0,
            text: text,
          ));
        }
      }
    }

    return Transcript(
      segments: segments,
      rawText: jsonContent,
    );
  }

  /// Parse output JSON3 caption YouTube menjadi Transcript netral.
  static Transcript parseJson3(String jsonContent) {
    final parsed = jsonDecode(jsonContent);
    final segments = <TranscriptSegment>[];

    if (parsed is Map && parsed.containsKey('events')) {
      final events = parsed['events'] as List;
      for (final event in events) {
        if (event is Map) {
          final startMs = (event['tStartMs'] as num?)?.toDouble() ?? 0.0;
          final durMs = (event['dDurationMs'] as num?)?.toDouble() ?? 0.0;
          final endMs = startMs + durMs;

          var text = '';
          if (event.containsKey('segs') && event['segs'] is List) {
            final segs = event['segs'] as List;
            text = segs.whereType<Map>().map((s) => s['utf8']?.toString() ?? '').join();
          }

          final cleanText = text.replaceAll('\n', ' ').trim();
          if (cleanText.isNotEmpty) {
            segments.add(TranscriptSegment(
              start: startMs / 1000.0,
              end: endMs / 1000.0,
              text: cleanText,
            ));
          }
        }
      }
    }

    return Transcript(
      segments: segments,
      rawText: jsonContent,
    );
  }

  @override
  Future<Transcript> transcribe(
    String videoPath, {
    String? language,
    CancelToken? cancel,
    void Function(double fraction)? onProgress,
  }) async {
    cancel?.throwIfCancelled();

    final videoFile = File(videoPath);
    if (!await videoFile.exists()) {
      throw FileSystemException('File video tidak ditemukan: $videoPath');
    }

    final videoDir = videoFile.parent.path;
    final baseName = p.basenameWithoutExtension(videoPath);
    final wavPath = p.join(videoDir, '$baseName.wav');

    try {
      // 1. Ekstrak WAV via ffmpeg
      onProgress?.call(0.1);
      final ffmpegArgs = buildFfmpegExtractArgs(videoPath: videoPath, wavPath: wavPath);
      final ffmpegResult = await runner.run(
        ffmpegPath,
        ffmpegArgs,
        workingDirectory: videoDir,
        cancel: cancel,
      );

      if (!ffmpegResult.isSuccess) {
        throw Exception('Gagal mengekstrak audio dengan ffmpeg: ${ffmpegResult.stderr}');
      }

      cancel?.throwIfCancelled();
      onProgress?.call(0.3);

      // 2. Tentukan lokasi model whisper
      String modelPath;
      if (whisperModelsDir != null && whisperModelsDir!.isNotEmpty) {
        modelPath = p.join(whisperModelsDir!, whisperModelName);
      } else {
        final whisperDir = File(whisperPath).parent.path;
        modelPath = p.join(whisperDir, 'models', whisperModelName);
      }

      // 3. Jalankan whisper.cpp
      final outputPrefix = p.join(videoDir, baseName);
      final whisperArgs = buildWhisperArgs(
        modelPath: modelPath,
        wavPath: wavPath,
        outputPrefix: outputPrefix,
        language: language,
      );

      final whisperResult = await runner.run(
        whisperPath,
        whisperArgs,
        workingDirectory: videoDir,
        cancel: cancel,
      );

      if (!whisperResult.isSuccess) {
        throw Exception('Gagal transkripsi audio dengan whisper.cpp: ${whisperResult.stderr}');
      }

      cancel?.throwIfCancelled();
      onProgress?.call(0.9);

      // 4. Baca file JSON transkripsi (whisper.cpp menambahkan .json)
      final jsonFile = File('$outputPrefix.json');
      if (!await jsonFile.exists()) {
        throw FileSystemException('File output transkripsi tidak ditemukan: ${jsonFile.path}');
      }

      final jsonContent = await jsonFile.readAsString();
      final transcript = parseWhisperJson(jsonContent);

      onProgress?.call(1.0);
      return transcript;
    } finally {
      // Selalu bersihkan WAV sementara
      try {
        final wavFile = File(wavPath);
        if (await wavFile.exists()) {
          await wavFile.delete();
        }
      } catch (_) {}
    }
  }
}

