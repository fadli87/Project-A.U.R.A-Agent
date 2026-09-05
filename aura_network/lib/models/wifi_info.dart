/// Model informasi jaringan WiFi aktif.
class WifiInfo {
  final String ssid;
  final String bssid;
  final int rssiDbm;       // Signal strength in dBm (e.g. -65)
  final int linkSpeedMbps; // Link speed in Mbps
  final int? channel;      // WiFi channel (e.g. 6, 36)
  final String? band;      // "2.4 GHz" or "5 GHz"
  final String? ipAddress;
  final String? gateway;
  final String? subnetMask;
  final bool isConnected;
  final DateTime timestamp;

  const WifiInfo({
    this.ssid = '',
    this.bssid = '',
    this.rssiDbm = -100,
    this.linkSpeedMbps = 0,
    this.channel,
    this.band,
    this.ipAddress,
    this.gateway,
    this.subnetMask,
    this.isConnected = false,
    required this.timestamp,
  });

  factory WifiInfo.disconnected() => WifiInfo(
        ssid: '',
        bssid: '',
        isConnected: false,
        timestamp: DateTime.now(),
      );

  factory WifiInfo.fromMap(Map<dynamic, dynamic> map) {
    return WifiInfo(
      ssid: map['ssid'] as String? ?? '',
      bssid: map['bssid'] as String? ?? '',
      rssiDbm: (map['rssiDbm'] as num?)?.toInt() ?? -100,
      linkSpeedMbps: (map['linkSpeedMbps'] as num?)?.toInt() ?? 0,
      channel: (map['channel'] as num?)?.toInt(),
      band: map['band'] as String?,
      ipAddress: map['ipAddress'] as String?,
      gateway: map['gateway'] as String?,
      subnetMask: map['subnetMask'] as String?,
      isConnected: map['isConnected'] as bool? ?? false,
      timestamp: DateTime.now(),
    );
  }

  // ---- Display helpers ----
  String get ssidDisplay => ssid.isNotEmpty ? ssid : 'N/A';
  String get rssiDisplay => '$rssiDbm dBm';
  String get linkSpeedDisplay => '$linkSpeedMbps Mbps';
  String get channelDisplay => channel != null ? 'Ch $channel' : 'N/A';
  String get bandDisplay => band ?? 'N/A';
  bool get is5Ghz => band?.contains('5') ?? false;

  /// Perkiraan kekuatan sinyal WiFi berdasarkan RSSI.
  WifiSignalQuality get signalQuality {
    if (rssiDbm >= -50) return WifiSignalQuality.excellent;
    if (rssiDbm >= -60) return WifiSignalQuality.good;
    if (rssiDbm >= -70) return WifiSignalQuality.fair;
    return WifiSignalQuality.poor;
  }
}

enum WifiSignalQuality { excellent, good, fair, poor }

extension WifiSignalQualityExt on WifiSignalQuality {
  String get label {
    switch (this) {
      case WifiSignalQuality.excellent: return 'Excellent';
      case WifiSignalQuality.good:      return 'Good';
      case WifiSignalQuality.fair:      return 'Fair';
      case WifiSignalQuality.poor:      return 'Poor';
    }
  }

  int get colorValue {
    switch (this) {
      case WifiSignalQuality.excellent: return 0xFF4CAF50;
      case WifiSignalQuality.good:      return 0xFF8BC34A;
      case WifiSignalQuality.fair:      return 0xFFFF9800;
      case WifiSignalQuality.poor:      return 0xFFF44336;
    }
  }
}
