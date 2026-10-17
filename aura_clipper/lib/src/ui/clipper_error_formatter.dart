import 'dart:io';

/// Informasi terstruktur hasil penguraian error pipeline AURA Clipper.
class ClipperErrorInfo {
  final String category;
  final String advice;
  final String detail;
  final String shortSummary;

  const ClipperErrorInfo({
    required this.category,
    required this.advice,
    required this.detail,
    required this.shortSummary,
  });
}

/// Pemformat dan pengklasifikasi error untuk UI AURA Clipper.
///
/// Mengurai kesalahan router, HTTP status code (404, 401, 429, 503),
/// dan kesalahan tool lokal agar pengguna mendapatkan akar masalah yang jelas,
/// bukan sekadar pesan generik "layanan sibuk".
class ClipperErrorFormatter {
  ClipperErrorFormatter._();

  /// Mengurai string error mentah menjadi [ClipperErrorInfo] yang terstruktur.
  static ClipperErrorInfo format(String rawError) {
    final lower = rawError.toLowerCase();

    // 1. Model Pensiun / Tidak Ditemukan (404)
    if (lower.contains('404') ||
        lower.contains('not_found') ||
        lower.contains('not found') ||
        lower.contains('is no longer available') ||
        lower.contains('model not found')) {
      return ClipperErrorInfo(
        category: 'Model Tidak Ditemukan / Pensiun (HTTP 404)',
        advice:
            'Model LLM yang digunakan sudah dipensiunkan oleh penyedia atau nama model tidak valid. '
            'Ubah nama model ke versi aktif (mis. gemini-3.8-flash) di Pengaturan Clipper atau Pengaturan Server.',
        detail: rawError,
        shortSummary: 'Model tidak ditemukan / pensiun (HTTP 404)',
      );
    }

    // 2. Autentikasi / API Key Tidak Valid (401 / 403)
    if (lower.contains('401') ||
        lower.contains('403') ||
        lower.contains('unauthenticated') ||
        lower.contains('api_key_invalid') ||
        lower.contains('invalid api key') ||
        lower.contains('forbidden')) {
      return ClipperErrorInfo(
        category: 'Autentikasi Gagal (HTTP 401/403)',
        advice:
            'API key tidak valid, kedaluwarsa, atau tidak memiliki izin akses untuk model ini. '
            'Periksa kembali API key di Pengaturan Server.',
        detail: rawError,
        shortSummary: 'API key tidak valid / ditolak (HTTP 401/403)',
      );
    }

    // 3. Batas Kuota / Rate Limit (429)
    if (lower.contains('429') ||
        lower.contains('resource_exhausted') ||
        lower.contains('quota exceeded') ||
        lower.contains('rate limit')) {
      return ClipperErrorInfo(
        category: 'Batas Kuota Terlampaui (HTTP 429)',
        advice:
            'Batas kuota gratis atau per-menit untuk model ini telah habis. '
            'Tunggu beberapa saat atau gunakan model/provider lain dalam rantai fallback.',
        detail: rawError,
        shortSummary: 'Batas kuota habis / rate limit (HTTP 429)',
      );
    }

    // 4. Layanan Provider Sibuk / Down (500 / 502 / 503 / 504)
    if (lower.contains('503') ||
        lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('504') ||
        lower.contains('unavailable') ||
        lower.contains('overloaded') ||
        lower.contains('bad gateway')) {
      return ClipperErrorInfo(
        category: 'Layanan Cloud Sibuk / Gangguan (HTTP 503/500)',
        advice:
            'Server penyedia AI sedang sibuk mengalami lonjakan beban atau pemeliharaan sementara. '
            'Silakan coba beberapa saat lagi.',
        detail: rawError,
        shortSummary: 'Layanan cloud sibuk / gangguan (HTTP 503)',
      );
    }

    // 5. Tool Sistem (yt-dlp, ffmpeg, whisper)
    if (lower.contains('processexception') ||
        lower.contains('executable') ||
        lower.contains('winerror 2') ||
        lower.contains('not found in path') ||
        lower.contains('tool eksternal') ||
        lower.contains('gagal dijalankan')) {
      return ClipperErrorInfo(
        category: 'Tool Sistem Gagal Dijalankan',
        advice:
            'Aplikasi gagal mengeksekusi tool eksternal (yt-dlp, FFmpeg, atau whisper). '
            'Pastikan tool sudah terpasang dan path executable diatur dengan benar di Pengaturan Clipper.',
        detail: rawError,
        shortSummary: 'Tool eksternal gagal dieksekusi',
      );
    }

    // 6. JSON Parse / Output Format
    if (lower.contains('format') ||
        lower.contains('json') ||
        lower.contains('tidak ada kandidat klip valid')) {
      return ClipperErrorInfo(
        category: 'Format Respons Model Tidak Valid',
        advice:
            'Model AI memberikan respons yang tidak memuat format JSON kandidat klip yang diharapkan. '
            'Coba ulangi analisis atau ganti fokus topik analisis.',
        detail: rawError,
        shortSummary: 'Format respons AI tidak valid',
      );
    }

    // 7. Generic Fallback
    return ClipperErrorInfo(
      category: 'Kegagalan Proses Analisis',
      advice: 'Terjadi kesalahan selama memproses video. Periksa rincian log untuk diagnosa lebih lanjut.',
      detail: rawError,
      shortSummary: rawError.length > 60 ? '${rawError.substring(0, 57)}...' : rawError,
    );
  }

  /// Membuka file log atau direktori di file manager sistem.
  static Future<bool> openLogFile(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return false;

      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', file.absolute.path]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', file.absolute.path]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [file.parent.absolute.path]);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
