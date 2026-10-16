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

typedef ProcessTreeKiller = Future<void> Function(int pid, Process? process);

/// Implementasi nyata ProcessRunner untuk platform desktop menggunakan Process.start.
class DesktopProcessRunner implements ProcessRunner {
  final ProcessTreeKiller _killer;

  const DesktopProcessRunner({ProcessTreeKiller? killer})
      : _killer = killer ?? killProcessTree;

  static const utf8Decoder = Utf8Decoder(allowMalformed: true);

  /// Argumen taskkill untuk mematikan process tree di Windows.
  static List<String> buildKillTreeArgs(int pid) => ['/PID', pid.toString(), '/T', '/F'];

  /// Membunuh seluruh pohon proses (termasuk child processes seperti yt-dlp/ffmpeg di Windows).
  static Future<void> killProcessTree(int pid, Process? process) async {
    if (Platform.isWindows) {
      try {
        final result = await Process.run(
          'taskkill',
          buildKillTreeArgs(pid),
          runInShell: false,
        );
        if (result.exitCode == 0) return;
      } catch (_) {}
    }
    try {
      process?.kill(ProcessSignal.sigkill);
    } catch (_) {}
  }

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

    var exited = false;

    Future<void> safeKill() async {
      if (exited) return;
      await _killer(process.pid, process);
    }

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();

    // Utf8Decoder(allowMalformed: true) agar tidak crash jika output subprocess mengandung byte non-UTF8
    process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(
      (line) {
        stdoutBuffer.writeln(line);
        onStdout?.call(line);
      },
      onDone: () => stdoutDone.complete(),
      onError: (_) => stdoutDone.complete(),
      cancelOnError: false,
    );

    process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(
      (line) {
        stderrBuffer.writeln(line);
        onStderr?.call(line);
      },
      onDone: () => stderrDone.complete(),
      onError: (_) => stderrDone.complete(),
      cancelOnError: false,
    );

    Timer? timeoutTimer;
    var timedOut = false;

    if (timeout != null) {
      timeoutTimer = Timer(timeout, () {
        if (!exited) {
          timedOut = true;
          safeKill();
        }
      });
    }

    final cancelDisposer = cancel?.onCancel(() {
      if (!exited) {
        safeKill();
      }
    });

    try {
      final exitCode = await process.exitCode;
      exited = true;
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
      if (!exited) {
        await safeKill();
      }
      rethrow;
    } finally {
      exited = true;
      timeoutTimer?.cancel();
      cancelDisposer?.call();
    }
  }
}
