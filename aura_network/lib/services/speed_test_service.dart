import 'dart:async';
import 'package:flutter_network_speed_test/flutter_network_speed_test.dart';
import '../models/speed_test_result.dart';

/// Service untuk mengukur kecepatan internet: Download (DL), Upload (UL), dan Ping.
///
/// ⚠️ DISCLOSURE (Rule 16): Speed test mengirim/menerima data ke server eksternal.
/// UI WAJIB menampilkan indikator "📡 Menjalankan speed test ke server eksternal"
/// selama test berlangsung — sesuai prinsip transparansi AURA.
///
/// KATEGORI: Sensitif (network data ke pihak ketiga).
class SpeedTestService {
  SpeedTestService._();
  static final SpeedTestService instance = SpeedTestService._();

  // Cache hasil terakhir — jika < [_cacheDuration], kembalikan cache
  SpeedTestResult? _lastResult;
  static const _cacheDuration = Duration(minutes: 5);

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Jalankan speed test lengkap: Ping → Download → Upload.
  ///
  /// Mengembalikan [Stream<SpeedTestProgress>] yang emit update real-time setiap
  /// sampling interval. Stream ditutup dengan phase [SpeedTestPhase.done] atau
  /// [SpeedTestPhase.error].
  ///
  /// Jika ada hasil cache yang masih valid (< 5 menit), [useCacheIfAvailable] = true
  /// akan mengembalikan stream dengan 1 event saja (hasil cache langsung).
  Stream<SpeedTestProgress> runSpeedTest({
    bool useCacheIfAvailable = false,
  }) async* {
    // Cache check
    if (useCacheIfAvailable && _lastResult != null) {
      final age = DateTime.now().difference(_lastResult!.timestamp);
      if (age < _cacheDuration) {
        yield SpeedTestProgress(
          phase: SpeedTestPhase.done,
          currentMbps: _lastResult!.downloadMbps,
          progress: 1.0,
          latencyMs: _lastResult!.latencyMs,
        );
        return;
      }
    }

    if (_isRunning) return; // Hindari concurrent test
    _isRunning = true;

    final controller = StreamController<SpeedTestProgress>();

    Future<void> execute() async {
      try {
        controller.add(const SpeedTestProgress(phase: SpeedTestPhase.pinging, progress: 0.05));

        final speedTest = SpeedTest(const SpeedTestArgs(
          download: true,
          upload: true,
          ping: true,
          duration: Duration(seconds: 8),
        ));

        await speedTest.init();

        int latencyMs = 0;
        // Phase 1: Ping
        try {
          final ping = await speedTest.testPing(
            onProgress: (int ms, double progress, int index) {
              controller.add(SpeedTestProgress(
                phase: SpeedTestPhase.pinging,
                progress: 0.05 + (progress.clamp(0.0, 1.0) * 0.1),
                latencyMs: ms,
              ));
            },
          );
          latencyMs = ping.round();
        } catch (_) {
          latencyMs = 0;
        }

        // Phase 2: Download
        controller.add(SpeedTestProgress(
          phase: SpeedTestPhase.downloading,
          progress: 0.15,
          latencyMs: latencyMs,
        ));
        double downloadSpeed = 0.0;
        try {
          downloadSpeed = await speedTest.testDownloadSpeed(
            onProgress: (double mbps, double progress, double time) {
              controller.add(SpeedTestProgress(
                phase: SpeedTestPhase.downloading,
                currentMbps: mbps,
                progress: 0.15 + (progress.clamp(0.0, 1.0) * 0.4),
                latencyMs: latencyMs,
              ));
            },
          );
        } catch (_) {
          downloadSpeed = 0.0;
        }

        // Phase 3: Upload
        controller.add(SpeedTestProgress(
          phase: SpeedTestPhase.uploading,
          progress: 0.55,
          currentMbps: downloadSpeed,
          latencyMs: latencyMs,
        ));
        double uploadSpeed = 0.0;
        try {
          uploadSpeed = await speedTest.testUploadSpeed(
            onProgress: (double mbps, double progress, double time) {
              controller.add(SpeedTestProgress(
                phase: SpeedTestPhase.uploading,
                currentMbps: mbps,
                progress: 0.55 + (progress.clamp(0.0, 1.0) * 0.45),
                latencyMs: latencyMs,
              ));
            },
          );
        } catch (_) {
          uploadSpeed = 0.0;
        }

        final result = SpeedTestResult(
          downloadMbps: downloadSpeed,
          uploadMbps: uploadSpeed,
          latencyMs: latencyMs,
          jitterMs: 0,
          serverName: 'Cloudflare / Ookla',
          timestamp: DateTime.now(),
        );
        _lastResult = result;

        controller.add(SpeedTestProgress(
          phase: SpeedTestPhase.done,
          currentMbps: result.downloadMbps,
          progress: 1.0,
          latencyMs: latencyMs,
        ));
        await controller.close();
      } catch (e) {
        controller.add(const SpeedTestProgress(phase: SpeedTestPhase.error));
        controller.addError(e);
        await controller.close();
      } finally {
        _isRunning = false;
      }
    }

    execute();
    yield* controller.stream;
  }

  /// Kembalikan hasil speed test terakhir (bisa dari cache).
  SpeedTestResult? get lastResult => _lastResult;

  /// Apakah hasil cache masih valid?
  bool get hasFreshCache {
    if (_lastResult == null) return false;
    return DateTime.now().difference(_lastResult!.timestamp) < _cacheDuration;
  }

  /// Berapa menit lalu cache dibuat?
  int? get cacheAgeMinutes {
    if (_lastResult == null) return null;
    return DateTime.now().difference(_lastResult!.timestamp).inMinutes;
  }

  /// Clear cache manual (misalnya saat user paksa test ulang).
  void clearCache() => _lastResult = null;
}
