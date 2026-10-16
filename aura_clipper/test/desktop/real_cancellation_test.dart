// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_clipper/aura_clipper_desktop.dart';

void main() {
  group('Real Cancellation & Process Lifetime on Windows', () {
    test('Cancellation terminates process tree and leaves unrelated apps (Notepad) alive', () async {
      if (!Platform.isWindows) return;

      // 1. Jalankan aplikasi user lain (Notepad)
      Process.runSync('powershell', ['-c', 'Start-Process notepad.exe']);
      await Future.delayed(const Duration(milliseconds: 1000));

      addTearDown(() {
        try {
          Process.runSync('taskkill', ['/IM', 'notepad.exe', '/F']);
        } catch (_) {}
      });

      // Pastikan Notepad benar-benar hidup
      final checkNotepadBefore = Process.runSync('tasklist', ['/FI', 'IMAGENAME eq Notepad.exe']);
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
      final checkNotepadAfter = Process.runSync('tasklist', ['/FI', 'IMAGENAME eq Notepad.exe']);
      expect(checkNotepadAfter.stdout.toString().toLowerCase(), contains('notepad.exe'));

      // 6. Batalkan token sekali lagi (simulasi pembatalan bertahap / langkah berikutnya)
      // Ini membuktikan bahwa listener lama tidak memicu taskkill pada PID acak/baru
      cancel.cancel();
      await Future.delayed(const Duration(milliseconds: 300));

      final checkNotepadFinal = Process.runSync('tasklist', ['/FI', 'IMAGENAME eq Notepad.exe']);
      expect(
        checkNotepadFinal.stdout.toString().toLowerCase(),
        contains('notepad.exe'),
        reason: 'Notepad tidak boleh mati saat token dibatalkan ulang setelah proses selesai!',
      );
    });

    test('Cancelling active YtDlpDownloader kills entire process tree and leaves no orphan and no .part files', () async {
      if (!Platform.isWindows) return;

      final ytDlpPath = Platform.environment['YT_DLP_PATH'] ?? 'yt-dlp';
      try {
        if (Process.runSync(ytDlpPath, ['--version']).exitCode != 0) {
          markTestSkipped('yt-dlp tidak dapat dijalankan');
          return;
        }
      } catch (_) {
        markTestSkipped('yt-dlp tidak ditemukan di PATH');
        return;
      }

      final tempDir = Directory.systemTemp.createTempSync('ytdlp_cancel_test_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final downloader = YtDlpDownloader(ytDlpPath: ytDlpPath);
      final cancel = CancelToken();

      final downloadFuture = downloader.download(
        'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
        jobDir: tempDir,
        cancel: cancel,
      );

      // Tunggu hingga proses download mulai berjalan
      await Future.delayed(const Duration(seconds: 4));

      final beforeRes = Process.runSync('cmd', ['/c', 'tasklist | findstr /i "yt-dlp ffmpeg"']);
      print('=== TASKLIST SEBELUM BATAL ===\n${beforeRes.stdout}');

      cancel.cancel();

      try {
        await downloadFuture;
      } catch (e) {
        expect(e, isA<OperationCancelledException>());
      }

      await Future.delayed(const Duration(milliseconds: 800));

      final afterRes = Process.runSync('cmd', ['/c', 'tasklist | findstr /i "yt-dlp ffmpeg"']);
      print('=== TASKLIST SESUDAH BATAL ===\n${afterRes.stdout}');
      expect(afterRes.stdout.toString().trim(), isEmpty, reason: 'Tidak boleh ada proses yt-dlp atau ffmpeg yang tersisa');

      final partFiles = tempDir.listSync(recursive: true).where((f) => f.path.endsWith('.part')).toList();
      print('=== FILE .PART TERSISA: ${partFiles.length} ===');
      expect(partFiles, isEmpty, reason: 'Tidak boleh ada file .part tersisa setelah dibatalkan');
    });
  });
}
