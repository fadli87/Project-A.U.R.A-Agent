import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_clipper/aura_clipper_desktop.dart';

void main() {
  group('Real Cancellation & Process Lifetime on Windows', () {
    test('Cancellation terminates process tree and leaves unrelated apps (Notepad) alive', () async {
      if (!Platform.isWindows) return;

      // 1. Jalankan aplikasi user lain (Notepad)
      final notepadProcess = await Process.start('notepad.exe', []);
      final notepadPid = notepadProcess.pid;
      expect(notepadPid, greaterThan(0));

      addTearDown(() {
        try {
          Process.runSync('taskkill', ['/PID', notepadPid.toString(), '/F']);
        } catch (_) {}
      });

      // Pastikan Notepad benar-benar hidup
      final checkNotepadBefore = Process.runSync('tasklist', ['/FI', 'PID eq $notepadPid']);
      expect(checkNotepadBefore.stdout.toString().toLowerCase(), contains('notepad.exe'));

      // 2. Jalankan proses berdurasi panjang via DesktopProcessRunner (mis. ping 10 dtk)
      final runner = const DesktopProcessRunner();
      final cancel = CancelToken();

      final runFuture = runner.run(
        'ping',
        ['127.0.0.1', '-n', '10'],
        cancel: cancel,
      );

      // Beri waktu 500ms agar proses ping mulai
      await Future.delayed(const Duration(milliseconds: 500));

      // Cari PID ping yang sedang berjalan
      final pingCheck = Process.runSync('tasklist', ['/FI', 'IMAGENAME eq ping.exe']);
      expect(pingCheck.stdout.toString().toLowerCase(), contains('ping.exe'));

      // 3. Batalkan di tengah proses berjalan
      cancel.cancel();

      // Tunggu runFuture selesai (harus melempar OperationCancelledException atau return failed)
      try {
        await runFuture;
      } catch (e) {
        expect(e, isA<OperationCancelledException>());
      }

      // Tunggu sebentar agar taskkill /T /F selesai membersihkan proses
      await Future.delayed(const Duration(milliseconds: 600));

      // 4. Verifikasi: ping.exe sudah TIDAK ada lagi (tidak ada proses yatim)
      final pingCheckAfter = Process.runSync('tasklist', ['/FI', 'IMAGENAME eq ping.exe']);
      expect(pingCheckAfter.stdout.toString().toLowerCase(), isNot(contains('ping.exe')));

      // 5. Verifikasi KRITIS: Notepad harus TETAP HIDUP!
      final checkNotepadAfter = Process.runSync('tasklist', ['/FI', 'PID eq $notepadPid']);
      expect(checkNotepadAfter.stdout.toString().toLowerCase(), contains('notepad.exe'));

      // 6. Batalkan token sekali lagi (simulasi pembatalan bertahap / langkah berikutnya)
      // Ini membuktikan bahwa listener lama tidak memicu taskkill pada PID acak/baru
      cancel.cancel();
      await Future.delayed(const Duration(milliseconds: 300));

      final checkNotepadFinal = Process.runSync('tasklist', ['/FI', 'PID eq $notepadPid']);
      expect(
        checkNotepadFinal.stdout.toString().toLowerCase(),
        contains('notepad.exe'),
        reason: 'Notepad tidak boleh mati saat token dibatalkan ulang setelah proses selesai!',
      );
    });
  });
}
