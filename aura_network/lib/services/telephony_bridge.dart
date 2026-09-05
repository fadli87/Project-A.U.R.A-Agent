import 'package:flutter/services.dart';
import '../models/cell_signal_info.dart';

/// Dart-side bridge ke Android native plugin untuk info seluler.
/// Menggunakan MethodChannel yang sama dengan G-Net Track clone
/// (channel: 'com.aura.network/telephony').
///
/// Kategori: SENSITIF — membutuhkan izin ACCESS_FINE_LOCATION + READ_PHONE_STATE.
/// Permission harus diminta sebelum memanggil method ini via PermissionService.
class TelephonyBridge {
  static const MethodChannel _channel = MethodChannel('com.aura.network/telephony');

  const TelephonyBridge();

  /// Mengambil daftar SIM slot yang aktif.
  /// Mengembalikan list kosong jika gagal (graceful fallback).
  Future<List<SimSlotInfo>> getSimSlots() async {
    try {
      final List<dynamic>? rawList =
          await _channel.invokeMethod<List<dynamic>>('getSimSlots');
      if (rawList == null || rawList.isEmpty) return [];
      return rawList
          .map((item) => SimSlotInfo.fromMap(item as Map<dynamic, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Mengambil snapshot info cell saat ini untuk subscription tertentu.
  /// Jika [subscriptionId] null, pakai SIM default.
  /// Mengembalikan snapshot kosong dengan timestamp jika gagal.
  Future<TelephonySnapshot> getCellInfo({int? subscriptionId}) async {
    try {
      final Map<dynamic, dynamic>? rawMap =
          await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getCellInfo',
        {'subscriptionId': subscriptionId},
      );
      return TelephonySnapshot.fromMap(rawMap);
    } catch (_) {
      return TelephonySnapshot(timestamp: DateTime.now());
    }
  }
}
