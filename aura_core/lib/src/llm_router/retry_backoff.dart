/// Retry backoff & error classification logic — port dari
/// `internal/handlers/chat/fallback.go` dan `internal/providers/errorclassify.go` (9router-go).
///
/// Mengatur ekstraksi pesan error, estimasi waktu retry, dan kalkulasi exponential
/// backoff saat terjadi error upstream (seperti rate limit 429 atau quota habis).
library retry_backoff;

import 'dart:convert';
import 'dart:math';

// ============================================================================
// Konstanta Default (Addendum Section 3)
// ============================================================================

/// Waktu cooldown dasar untuk rate-limiting (2 detik / 2000 ms).
const backoffBaseMs = 2000;

/// Batas maksimum cooldown backoff (5 menit / 300.000 ms).
const backoffMaxMs = 5 * 60 * 1000;

/// Level maksimum backoff eksponensial.
const backoffMaxLevel = 15;

/// Cooldown default untuk error transient yang tidak cocok dengan aturan apapun (30 detik).
const transientCooldownMs = 30 * 1000;

/// Cooldown panjang untuk error otentikasi atau request tidak valid (2 menit).
const cooldownLong = 2 * 60 * 1000;

/// Cooldown pendek untuk error izin sementara (5 detik).
const cooldownShort = 5 * 1000;

// ============================================================================
// Data Structures
// ============================================================================

/// Aturan pencocokan error berdasarkan pola teks substring atau status HTTP.
/// Port dari `ErrorRule` di `errorclassify.go`.
class ErrorRule {
  final String text;
  final int status;
  final int cooldownMs;
  final bool backoff;

  const ErrorRule({
    this.text = '',
    this.status = 0,
    this.cooldownMs = 0,
    this.backoff = false,
  });
}

/// Hasil klasifikasi error upstream.
/// Port dari `ErrorClassification` di `errorclassify.go`.
class ErrorClassification {
  final bool shouldFallback;
  final int cooldownMs;
  final int newBackoffLevel;

  const ErrorClassification({
    required this.shouldFallback,
    required this.cooldownMs,
    required this.newBackoffLevel,
  });
}

/// Daftar aturan klasifikasi error default (sesuai urutan evaluasi Next.js/Go).
/// Port dari `ErrorRules` di `errorclassify.go`.
const defaultErrorRules = <ErrorRule>[
  // --- Aturan berbasis teks (dicek terlebih dahulu) ---
  ErrorRule(text: 'no credentials', cooldownMs: cooldownLong),
  ErrorRule(text: 'request not allowed', cooldownMs: cooldownShort),
  ErrorRule(text: 'improperly formed request', cooldownMs: cooldownLong),
  ErrorRule(text: 'rate limit', backoff: true),
  ErrorRule(text: 'too many requests', backoff: true),
  ErrorRule(text: 'quota exceeded', backoff: true),
  ErrorRule(text: 'capacity', backoff: true),
  ErrorRule(text: 'overloaded', backoff: true),

  // --- Aturan berbasis status HTTP (fallback jika teks tidak match) ---
  ErrorRule(status: 401, cooldownMs: cooldownLong),
  ErrorRule(status: 402, cooldownMs: cooldownLong),
  ErrorRule(status: 403, cooldownMs: cooldownLong),
  ErrorRule(status: 404, cooldownMs: cooldownLong),
  ErrorRule(status: 429, backoff: true),
];

// ============================================================================
// Functions
// ============================================================================

/// Menghitung cooldown exponential backoff untuk rate limits.
/// Level 0 -> 2s, Level 1 -> 2s, Level 2 -> 4s, Level 3 -> 8s, ... dibatasi pada [backoffMaxMs].
/// Port dari `GetQuotaCooldown` di `errorclassify.go`.
int getQuotaCooldown(int backoffLevel) {
  final level = max(backoffLevel - 1, 0);
  final cooldown = (backoffBaseMs * pow(2, level)).toInt();
  return min(cooldown, backoffMaxMs);
}

/// Mengklasifikasikan error berdasarkan status HTTP dan pesan teks untuk menentukan
/// durasi cooldown dan backoff level baru.
/// Port dari `ClassifyError` di `errorclassify.go`.
ErrorClassification classifyError(
  int statusCode,
  String errorText,
  int currentBackoffLevel, {
  List<ErrorRule> rules = defaultErrorRules,
}) {
  final lowerError = errorText.toLowerCase();

  for (final rule in rules) {
    // Pencocokan teks (substring, case-insensitive)
    if (rule.text.isNotEmpty && lowerError.isNotEmpty && lowerError.contains(rule.text)) {
      if (rule.backoff) {
        final newLevel = min(currentBackoffLevel + 1, backoffMaxLevel);
        return ErrorClassification(
          shouldFallback: true,
          cooldownMs: getQuotaCooldown(newLevel),
          newBackoffLevel: newLevel,
        );
      }
      return ErrorClassification(
        shouldFallback: true,
        cooldownMs: rule.cooldownMs,
        newBackoffLevel: currentBackoffLevel,
      );
    }

    // Pencocokan status code
    if (rule.status != 0 && rule.status == statusCode) {
      if (rule.backoff) {
        final newLevel = min(currentBackoffLevel + 1, backoffMaxLevel);
        return ErrorClassification(
          shouldFallback: true,
          cooldownMs: getQuotaCooldown(newLevel),
          newBackoffLevel: newLevel,
        );
      }
      return ErrorClassification(
        shouldFallback: true,
        cooldownMs: rule.cooldownMs,
        newBackoffLevel: currentBackoffLevel,
      );
    }
  }

  // Default: transient cooldown untuk error tak dikenal
  return ErrorClassification(
    shouldFallback: true,
    cooldownMs: transientCooldownMs,
    newBackoffLevel: currentBackoffLevel,
  );
}

/// Mengekstrak pesan error manusiawi dari payload JSON response error.
/// Port dari `extractErrorText` di `fallback.go`.
String extractErrorText(dynamic body) {
  if (body == null) return '';

  Map<String, dynamic>? parsed;
  if (body is Map<String, dynamic>) {
    parsed = body;
  } else if (body is String) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        parsed = decoded;
      }
    } catch (_) {
      return '';
    }
  }

  if (parsed != null && parsed['error'] is Map) {
    final errObj = parsed['error'] as Map;
    if (errObj['message'] is String) {
      return errObj['message'] as String;
    }
  }

  return '';
}

/// Mengekstrak string timestamp atau delay retryAfter dari body error JSON.
/// Port dari `extractRetryAfter` di `fallback.go`.
String extractRetryAfter(dynamic body) {
  if (body == null) return '';

  Map<String, dynamic>? parsed;
  if (body is Map<String, dynamic>) {
    parsed = body;
  } else if (body is String) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        parsed = decoded;
      }
    } catch (_) {
      return '';
    }
  }

  if (parsed == null) return '';

  for (final key in const ['retryAfter', 'retry_after', 'resetsAt', 'resets_at']) {
    if (parsed.containsKey(key) && parsed[key] != null) {
      return parsed[key].toString();
    }
  }

  if (parsed['error'] is Map) {
    final errMap = parsed['error'] as Map;
    if (errMap.containsKey('retryAfter') && errMap['retryAfter'] != null) {
      return errMap['retryAfter'].toString();
    }
  }

  return '';
}

/// Memformat ISO timestamp ke dalam string countdown yang mudah dibaca ("reset after Xm Ys").
/// Port dari `formatRetryAfter` di `fallback.go`.
String formatRetryAfter(String isoTimestamp) {
  if (isoTimestamp.trim().isEmpty) return '';

  DateTime? parsed;
  try {
    parsed = DateTime.parse(isoTimestamp).toUtc();
  } catch (_) {
    return '';
  }

  final now = DateTime.now().toUtc();
  final diff = parsed.difference(now);
  if (diff.isNegative || diff.inMilliseconds <= 0) {
    return 'reset after 0s';
  }

  final totalSec = (diff.inMilliseconds + 999) ~/ 1000;
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = totalSec % 60;

  final parts = <String>[];
  if (h > 0) parts.add('${h}h');
  if (m > 0) parts.add('${m}m');
  if (s > 0 || parts.isEmpty) parts.add('${s}s');

  return 'reset after ${parts.join(' ')}';
}
