/// Models untuk speed test UL (Upload) / DL (Download).
/// Disclosure: speed test mengirim/menerima data ke server eksternal.
library;

// ---------------------------------------------------------------------------
// Phase enum
// ---------------------------------------------------------------------------

enum SpeedTestPhase {
  idle,
  pinging,
  downloading,
  uploading,
  done,
  error,
}

extension SpeedTestPhaseExt on SpeedTestPhase {
  String get label {
    switch (this) {
      case SpeedTestPhase.idle:        return 'Siap';
      case SpeedTestPhase.pinging:     return '📶 Mengukur Ping...';
      case SpeedTestPhase.downloading: return '⬇ Mengukur Download...';
      case SpeedTestPhase.uploading:   return '⬆ Mengukur Upload...';
      case SpeedTestPhase.done:        return '✅ Selesai';
      case SpeedTestPhase.error:       return '❌ Error';
    }
  }
}

// ---------------------------------------------------------------------------
// Progress update (stream emit selama test berlangsung)
// ---------------------------------------------------------------------------

/// Emitted secara real-time via Stream selama speed test berlangsung.
class SpeedTestProgress {
  final SpeedTestPhase phase;
  final double currentMbps; // Mbps saat ini (DL atau UL tergantung phase)
  final double progress;    // 0.0 – 1.0, progress per phase
  final int? latencyMs;

  const SpeedTestProgress({
    required this.phase,
    this.currentMbps = 0,
    this.progress = 0,
    this.latencyMs,
  });
}

// ---------------------------------------------------------------------------
// Final result
// ---------------------------------------------------------------------------

/// Hasil akhir speed test setelah semua fase selesai.
class SpeedTestResult {
  final double downloadMbps;
  final double uploadMbps;
  final int latencyMs;       // Ping ms
  final double jitterMs;     // Variasi latency
  final String serverName;   // Nama/URL server test yang dipakai
  final DateTime timestamp;
  final bool isFromCache;    // true jika hasil ini dari cache (< 5 menit lalu)

  const SpeedTestResult({
    required this.downloadMbps,
    required this.uploadMbps,
    required this.latencyMs,
    this.jitterMs = 0,
    this.serverName = '',
    required this.timestamp,
    this.isFromCache = false,
  });

  /// Salin result dengan flag cache.
  SpeedTestResult copyWithCache(bool cached) => SpeedTestResult(
        downloadMbps: downloadMbps,
        uploadMbps: uploadMbps,
        latencyMs: latencyMs,
        jitterMs: jitterMs,
        serverName: serverName,
        timestamp: timestamp,
        isFromCache: cached,
      );

  // ---- Display helpers ----
  String get downloadDisplay => '${downloadMbps.toStringAsFixed(1)} Mbps';
  String get uploadDisplay   => '${uploadMbps.toStringAsFixed(1)} Mbps';
  String get latencyDisplay  => '$latencyMs ms';
  String get jitterDisplay   => '${jitterMs.toStringAsFixed(1)} ms';

  /// Klasifikasi kualitas berdasarkan download speed.
  SpeedQuality get quality {
    if (downloadMbps >= 100) return SpeedQuality.ultraFast;
    if (downloadMbps >= 25)  return SpeedQuality.fast;
    if (downloadMbps >= 10)  return SpeedQuality.moderate;
    if (downloadMbps >= 3)   return SpeedQuality.slow;
    return SpeedQuality.verySlow;
  }
}

enum SpeedQuality { ultraFast, fast, moderate, slow, verySlow }

extension SpeedQualityExt on SpeedQuality {
  String get label {
    switch (this) {
      case SpeedQuality.ultraFast: return 'Ultra Fast';
      case SpeedQuality.fast:      return 'Fast';
      case SpeedQuality.moderate:  return 'Moderate';
      case SpeedQuality.slow:      return 'Slow';
      case SpeedQuality.verySlow:  return 'Very Slow';
    }
  }

  int get colorValue {
    switch (this) {
      case SpeedQuality.ultraFast: return 0xFF2196F3; // Blue
      case SpeedQuality.fast:      return 0xFF4CAF50; // Green
      case SpeedQuality.moderate:  return 0xFF8BC34A; // Light green
      case SpeedQuality.slow:      return 0xFFFF9800; // Orange
      case SpeedQuality.verySlow:  return 0xFFF44336; // Red
    }
  }
}
