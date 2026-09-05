import 'dart:async';
import 'package:flutter/services.dart';
import '../models/wifi_info.dart';

/// Service untuk mendapatkan info WiFi aktif.
///
/// KATEGORI: SENSITIF — Android 8+ mewajibkan izin ACCESS_FINE_LOCATION
/// untuk membaca SSID dan detail WiFi.
/// Permission HARUS sudah diberikan sebelum memanggil [getWifiInfo].
class WifiService {
  static const MethodChannel _channel = MethodChannel('com.aura.network/wifi');

  const WifiService();

  /// Ambil info WiFi yang sedang terhubung.
  /// Mengembalikan [WifiInfo.disconnected()] jika tidak terhubung atau gagal.
  Future<WifiInfo> getWifiInfo() async {
    try {
      final Map<dynamic, dynamic>? rawMap =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getWifiInfo');
      if (rawMap == null) return WifiInfo.disconnected();
      return WifiInfo.fromMap(rawMap);
    } on PlatformException {
      return WifiInfo.disconnected();
    } catch (_) {
      return WifiInfo.disconnected();
    }
  }

  /// Stream info WiFi yang terupdate setiap [interval].
  Stream<WifiInfo> wifiInfoStream({
    Duration interval = const Duration(seconds: 5),
  }) async* {
    while (true) {
      yield await getWifiInfo();
      await Future.delayed(interval);
    }
  }
}
