import 'dart:io';
import 'process_runner.dart';

/// Status of an external tool executable.
enum ToolStatus {
  available,
  notFound,
  failed,
}

/// Result of checking an external tool.
class ToolCheckResult {
  final String name;
  final String executablePath;
  final ToolStatus status;
  final String? version;
  final String? errorMessage;
  final String installGuide;

  const ToolCheckResult({
    required this.name,
    required this.executablePath,
    required this.status,
    this.version,
    this.errorMessage,
    required this.installGuide,
  });

  bool get isAvailable => status == ToolStatus.available;

  @override
  String toString() =>
      'ToolCheckResult(name: $name, status: $status, version: $version, path: $executablePath)';
}

/// Service to verify presence and functionality of external tools
/// (yt-dlp, ffmpeg, whisper.cpp).
class ToolCheck {
  final ProcessRunner _runner;

  ToolCheck({ProcessRunner? runner})
      : _runner = runner ?? DesktopProcessRunner();

  static const String ytDlpInstallGuide =
      'Download yt-dlp binary from https://github.com/yt-dlp/yt-dlp/releases or install via "winget install yt-dlp" / "pip install yt-dlp", and set the path in Clipper Settings.';

  static const String ffmpegInstallGuide =
      'Download FFmpeg from https://ffmpeg.org/download.html or install via "winget install Gyan.FFmpeg", and set the path in Clipper Settings.';

  static const String whisperInstallGuide =
      'Download whisper.cpp binary (whisper-cli or main) from https://github.com/ggerganov/whisper.cpp/releases with a ggml model (e.g. ggml-base.bin), and set the path in Clipper Settings.';

  /// Checks yt-dlp availability and version.
  Future<ToolCheckResult> checkYtDlp(String executablePath) async {
    return _check(
      name: 'yt-dlp',
      executablePath: executablePath,
      args: const ['--version'],
      installGuide: ytDlpInstallGuide,
    );
  }

  /// Checks ffmpeg availability and version.
  Future<ToolCheckResult> checkFfmpeg(String executablePath) async {
    return _check(
      name: 'ffmpeg',
      executablePath: executablePath,
      args: const ['-version'],
      installGuide: ffmpegInstallGuide,
    );
  }

  /// Checks whisper.cpp availability and version.
  Future<ToolCheckResult> checkWhisper(String executablePath) async {
    return _check(
      name: 'whisper.cpp',
      executablePath: executablePath,
      args: const ['--help'],
      installGuide: whisperInstallGuide,
      acceptNonZeroWithHelp: true,
    );
  }

  /// Checks all three tools given their paths.
  Future<List<ToolCheckResult>> checkAll({
    required String ytDlpPath,
    required String ffmpegPath,
    required String whisperPath,
  }) async {
    return Future.wait([
      checkYtDlp(ytDlpPath),
      checkFfmpeg(ffmpegPath),
      checkWhisper(whisperPath),
    ]);
  }

  Future<ToolCheckResult> _check({
    required String name,
    required String executablePath,
    required List<String> args,
    required String installGuide,
    bool acceptNonZeroWithHelp = false,
  }) async {
    final trimmedPath = executablePath.trim();
    if (trimmedPath.isEmpty) {
      return ToolCheckResult(
        name: name,
        executablePath: executablePath,
        status: ToolStatus.notFound,
        errorMessage: 'Executable path is empty.',
        installGuide: installGuide,
      );
    }

    try {
      final result = await _runner.run(
        trimmedPath,
        args,
        timeout: const Duration(seconds: 10),
      );

      final combinedOutput =
          '${result.stdout}\n${result.stderr}'.trim();

      if (result.exitCode == 0) {
        final versionLine = combinedOutput
            .split('\n')
            .map((l) => l.trim())
            .firstWhere((l) => l.isNotEmpty, orElse: () => 'OK');
        return ToolCheckResult(
          name: name,
          executablePath: trimmedPath,
          status: ToolStatus.available,
          version: versionLine,
          installGuide: installGuide,
        );
      } else if (acceptNonZeroWithHelp &&
          (combinedOutput.toLowerCase().contains('usage:') ||
              combinedOutput.toLowerCase().contains('whisper'))) {
        final firstLine = combinedOutput
            .split('\n')
            .map((l) => l.trim())
            .firstWhere((l) => l.isNotEmpty, orElse: () => 'Available');
        return ToolCheckResult(
          name: name,
          executablePath: trimmedPath,
          status: ToolStatus.available,
          version: firstLine,
          installGuide: installGuide,
        );
      } else {
        return ToolCheckResult(
          name: name,
          executablePath: trimmedPath,
          status: ToolStatus.failed,
          errorMessage: 'Exited with code ${result.exitCode}: $combinedOutput',
          installGuide: installGuide,
        );
      }
    } on ProcessException catch (e) {
      return ToolCheckResult(
        name: name,
        executablePath: trimmedPath,
        status: ToolStatus.notFound,
        errorMessage: e.message,
        installGuide: installGuide,
      );
    } catch (e) {
      return ToolCheckResult(
        name: name,
        executablePath: trimmedPath,
        status: ToolStatus.failed,
        errorMessage: e.toString(),
        installGuide: installGuide,
      );
    }
  }
}
