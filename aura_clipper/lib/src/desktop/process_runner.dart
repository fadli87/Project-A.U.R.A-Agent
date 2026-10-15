import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../pipeline/interfaces.dart';

/// Hasil eksekusi sebuah proses desktop.
class ProcessExecutionResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const ProcessExecutionResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  bool get isSuccess => exitCode == 0;
}

/// Interface eksekusi proses eksternal.
abstract interface class ProcessRunner {
  Future<ProcessExecutionResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
    CancelToken? cancel,
    void Function(String line)? onStdout,
    void Function(String line)? onStderr,
  });
}

/// Implementasi nyata ProcessRunner untuk platform desktop menggunakan Process.start.
class DesktopProcessRunner implements ProcessRunner {
  const DesktopProcessRunner();

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

    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: false, // Wajib false: no shell injection
    );

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        stdoutBuffer.writeln(line);
        onStdout?.call(line);
      },
      onDone: () => stdoutDone.complete(),
      onError: (err) => stdoutDone.completeError(err),
      cancelOnError: false,
    );

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        stderrBuffer.writeln(line);
        onStderr?.call(line);
      },
      onDone: () => stderrDone.complete(),
      onError: (err) => stderrDone.completeError(err),
      cancelOnError: false,
    );

    Timer? timeoutTimer;
    var timedOut = false;

    if (timeout != null) {
      timeoutTimer = Timer(timeout, () {
        timedOut = true;
        try {
          process.kill(ProcessSignal.sigkill);
        } catch (_) {}
      });
    }

    cancel?.onCancel(() {
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {}
    });

    try {
      final exitCode = await process.exitCode;
      timeoutTimer?.cancel();
      await Future.wait([stdoutDone.future, stderrDone.future]);

      if (timedOut) {
        throw TimeoutException('Proses $executable melebihi batas waktu $timeout.');
      }

      cancel?.throwIfCancelled();

      return ProcessExecutionResult(
        exitCode: exitCode,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
      );
    } catch (e) {
      timeoutTimer?.cancel();
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {}
      rethrow;
    }
  }
}
