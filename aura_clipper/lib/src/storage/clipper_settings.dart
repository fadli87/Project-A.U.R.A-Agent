import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Pengaturan non-rahasia untuk modul AURA Clipper.
class ClipperSettings {
  final String ytDlpPath;
  final String ffmpegPath;
  final String whisperPath;
  final String whisperModelName;
  final String? whisperModelsDir;
  final String language;
  final String? outputDir;
  final List<String> allowedHosts;

  const ClipperSettings({
    this.ytDlpPath = 'yt-dlp',
    this.ffmpegPath = 'ffmpeg',
    this.whisperPath = 'whisper-cli',
    this.whisperModelName = 'ggml-base.bin',
    this.whisperModelsDir,
    this.language = 'auto',
    this.outputDir,
    this.allowedHosts = const [
      'youtube.com',
      'www.youtube.com',
      'youtu.be',
      'm.youtube.com',
    ],
  });

  ClipperSettings copyWith({
    String? ytDlpPath,
    String? ffmpegPath,
    String? whisperPath,
    String? whisperModelName,
    String? whisperModelsDir,
    String? language,
    String? outputDir,
    List<String>? allowedHosts,
  }) {
    return ClipperSettings(
      ytDlpPath: ytDlpPath ?? this.ytDlpPath,
      ffmpegPath: ffmpegPath ?? this.ffmpegPath,
      whisperPath: whisperPath ?? this.whisperPath,
      whisperModelName: whisperModelName ?? this.whisperModelName,
      whisperModelsDir: whisperModelsDir ?? this.whisperModelsDir,
      language: language ?? this.language,
      outputDir: outputDir ?? this.outputDir,
      allowedHosts: allowedHosts ?? this.allowedHosts,
    );
  }

  Map<String, dynamic> toJson() => {
    'yt_dlp_path': ytDlpPath,
    'ffmpeg_path': ffmpegPath,
    'whisper_path': whisperPath,
    'whisper_model_name': whisperModelName,
    'whisper_models_dir': whisperModelsDir,
    'language': language,
    'output_dir': outputDir,
    'allowed_hosts': allowedHosts,
  };

  factory ClipperSettings.fromJson(Map<String, dynamic> json) {
    return ClipperSettings(
      ytDlpPath: json['yt_dlp_path'] as String? ?? 'yt-dlp',
      ffmpegPath: json['ffmpeg_path'] as String? ?? 'ffmpeg',
      whisperPath: json['whisper_path'] as String? ?? 'whisper-cli',
      whisperModelName: json['whisper_model_name'] as String? ?? 'ggml-base.bin',
      whisperModelsDir: json['whisper_models_dir'] as String?,
      language: json['language'] as String? ?? 'auto',
      outputDir: json['output_dir'] as String?,
      allowedHosts: (json['allowed_hosts'] as List?)?.map((e) => e.toString()).toList() ??
          const ['youtube.com', 'www.youtube.com', 'youtu.be', 'm.youtube.com'],
    );
  }
}

/// Store untuk membaca dan menulis berkas `clipper_settings.json`.
class ClipperSettingsStore {
  final File file;
  ClipperSettings _settings;

  ClipperSettingsStore(this.file) : _settings = const ClipperSettings();

  /// Membuat store berbasis folder (misalnya direktori application support).
  factory ClipperSettingsStore.fromDirectory(Directory dir) {
    final filePath = p.join(dir.path, 'clipper_settings.json');
    return ClipperSettingsStore(File(filePath));
  }

  ClipperSettings get current => _settings;

  /// Memuat pengaturan dari file. Jika file belum ada, mengembalikan nilai default.
  Future<ClipperSettings> load() async {
    try {
      if (!await file.exists()) {
        _settings = const ClipperSettings();
        return _settings;
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        _settings = const ClipperSettings();
        return _settings;
      }

      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        _settings = ClipperSettings.fromJson(decoded);
      } else {
        _settings = const ClipperSettings();
      }
    } catch (_) {
      _settings = const ClipperSettings();
    }
    return _settings;
  }

  /// Menyimpan pengaturan ke berkas JSON dengan indentasi rapi.
  Future<void> save(ClipperSettings settings) async {
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    final encoder = const JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(settings.toJson());
    await file.writeAsString(jsonString);
    _settings = settings;
  }
}
