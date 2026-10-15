import 'package:flutter_test/flutter_test.dart';
import 'package:aura_clipper/aura_clipper_desktop.dart';

class FakeToolProcessRunner implements ProcessRunner {
  final ProcessExecutionResult Function(String exe, List<String> args) handler;

  FakeToolProcessRunner(this.handler);

  @override
  Future<ProcessExecutionResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
    CancelToken? cancel,
    void Function(String line)? onStdout,
    void Function(String line)? onStderr,
  }) async {
    return handler(executable, arguments);
  }
}

void main() {
  group('ToolCheck', () {
    test('checkYtDlp returns available with version on exit code 0', () async {
      final runner = FakeToolProcessRunner((exe, args) {
        expect(args, contains('--version'));
        return const ProcessExecutionResult(exitCode: 0, stdout: '2026.08.19\n', stderr: '');
      });

      final checker = ToolCheck(runner: runner);
      final result = await checker.checkYtDlp('yt-dlp');

      expect(result.status, ToolStatus.available);
      expect(result.version, '2026.08.19');
      expect(result.isAvailable, isTrue);
    });

    test('checkFfmpeg returns available with version on exit code 0', () async {
      final runner = FakeToolProcessRunner((exe, args) {
        expect(args, contains('-version'));
        return const ProcessExecutionResult(
          exitCode: 0,
          stdout: 'ffmpeg version 9.0 Copyright (c) 2000-2026\nother info',
          stderr: '',
        );
      });

      final checker = ToolCheck(runner: runner);
      final result = await checker.checkFfmpeg('ffmpeg');

      expect(result.status, ToolStatus.available);
      expect(result.version, contains('ffmpeg version 9.0'));
      expect(result.isAvailable, isTrue);
    });

    test('checkWhisper accepts non-zero exit code if usage/help output is present', () async {
      final runner = FakeToolProcessRunner((exe, args) {
        expect(args, contains('--help'));
        return const ProcessExecutionResult(
          exitCode: 1,
          stdout: '',
          stderr: 'usage: whisper-cli [options] -m model -f file\n',
        );
      });

      final checker = ToolCheck(runner: runner);
      final result = await checker.checkWhisper('whisper-cli');

      expect(result.status, ToolStatus.available);
      expect(result.version, contains('whisper-cli'));
    });

    test('check returns notFound when path is empty', () async {
      final checker = ToolCheck();
      final result = await checker.checkYtDlp('   ');

      expect(result.status, ToolStatus.notFound);
      expect(result.errorMessage, contains('empty'));
      expect(result.installGuide, contains('yt-dlp'));
    });

    test('check returns failed when execution fails with error code', () async {
      final runner = FakeToolProcessRunner((exe, args) {
        return const ProcessExecutionResult(
          exitCode: 127,
          stdout: '',
          stderr: 'command not found',
        );
      });

      final checker = ToolCheck(runner: runner);
      final result = await checker.checkYtDlp('yt-dlp');

      expect(result.status, ToolStatus.failed);
      expect(result.errorMessage, contains('Exited with code 127'));
    });

    test('checkAll checks yt-dlp, ffmpeg, and whisper in parallel', () async {
      final runner = FakeToolProcessRunner((exe, args) {
        return const ProcessExecutionResult(exitCode: 0, stdout: 'v1.0\n', stderr: '');
      });

      final checker = ToolCheck(runner: runner);
      final results = await checker.checkAll(
        ytDlpPath: 'yt-dlp',
        ffmpegPath: 'ffmpeg',
        whisperPath: 'whisper-cli',
      );

      expect(results.length, 3);
      expect(results.every((r) => r.isAvailable), isTrue);
    });
  });
}
