import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_clipper/aura_clipper_desktop.dart';

/// Fake implementation of ProcessRunner for testing without actual external binaries.
class FakeProcessRunner implements ProcessRunner {
  ProcessExecutionResult Function(String exe, List<String> args)? onExecute;
  Duration simulatedDelay;

  FakeProcessRunner({
    this.onExecute,
    this.simulatedDelay = Duration.zero,
  });

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
    cancel?.throwIfCancelled();

    if (simulatedDelay > Duration.zero) {
      final completer = Completer<void>();
      final timer = Timer(simulatedDelay, () => completer.complete());
      cancel?.onCancel(() {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.completeError(const OperationCancelledException('Operasi dibatalkan.'));
        }
      });
      await completer.future;
    }

    cancel?.throwIfCancelled();

    final result = onExecute?.call(executable, arguments) ??
        const ProcessExecutionResult(exitCode: 0, stdout: 'success', stderr: '');

    if (result.stdout.isNotEmpty && onStdout != null) {
      for (final line in result.stdout.split('\n')) {
        onStdout(line);
      }
    }

    return result;
  }
}

void main() {
  group('ProcessRunner & CancelToken', () {
    test('FakeProcessRunner executes and returns stdout', () async {
      final runner = FakeProcessRunner(
        onExecute: (exe, args) => ProcessExecutionResult(
          exitCode: 0,
          stdout: 'version 1.0.0\nline 2',
          stderr: '',
        ),
      );

      final lines = <String>[];
      final res = await runner.run(
        'tool',
        ['--version'],
        onStdout: (l) => lines.add(l),
      );

      expect(res.exitCode, 0);
      expect(lines, contains('version 1.0.0'));
      expect(lines, contains('line 2'));
    });

    test('CancelToken aborts run early', () async {
      final cancel = CancelToken();
      final runner = FakeProcessRunner(simulatedDelay: const Duration(milliseconds: 200));

      // Trigger cancel after 50ms
      Timer(const Duration(milliseconds: 50), () => cancel.cancel());

      expect(
        () => runner.run('tool', ['arg'], cancel: cancel),
        throwsA(isA<OperationCancelledException>()),
      );
    });
    test('DesktopProcessRunner.utf8Decoder decodes malformed bytes safely without throwing', () {
      final malformedBytes = [0xC0, 0xAF, 0xFF, 0x68, 0x65, 0x6C, 0x6C, 0x6F];
      // Should decode without throwing FormatException
      final decoded = DesktopProcessRunner.utf8Decoder.convert(malformedBytes);
      expect(decoded, contains('hello'));
    });

    test('DesktopProcessRunner.buildKillTreeArgs generates /PID <pid> /T /F', () {
      final args = DesktopProcessRunner.buildKillTreeArgs(12345);
      expect(args, equals(['/PID', '12345', '/T', '/F']));
    });
  });
}
