import 'dart:io';
import 'package:flutter/foundation.dart';

/// Konfigurasi runtime host yang disediakan oleh aplikasi induk (`aura_desktop` atau host lain)
/// kepada modul `ClipperScreen`.
class ClipperHostConfig {
  /// String model atau combo LLM (mis. 'gemini/gemini-3.5-flash-lite' atau 'combo').
  final String modelOrCombo;

  /// Kumpulan API key yang valid dan aktif dari SecureStorage host (mis. {'gemini': '...'}).
  final Map<String, String> apiKeys;

  /// Direktori kerja utama untuk Clipper (penyimpanan DB, jobs, settings, logs).
  final Directory workDir;

  /// Callback opsional untuk memilih folder ekspor menggunakan dialog native host.
  final Future<String?> Function()? onPickOutputFolder;

  /// Callback opsional untuk membuka dialog Pengaturan host (jika API key belum ada).
  final VoidCallback? onOpenSettings;

  const ClipperHostConfig({
    required this.modelOrCombo,
    required this.apiKeys,
    required this.workDir,
    this.onPickOutputFolder,
    this.onOpenSettings,
  });

  bool get hasAnyApiKey => apiKeys.values.any((key) => key.trim().isNotEmpty);
}
