/// Model device yang ditemukan di jaringan LAN lokal.
/// Hanya dari subnet lokal device sendiri — TIDAK dari jaringan luar.
class LanDevice {
  final String ipAddress;
  final String? macAddress;
  final String? hostname;
  final String? vendorName;  // Dari OUI lookup berdasarkan MAC prefix
  final LanDiscoveryMethod discoveryMethod;
  final DateTime discoveredAt;

  const LanDevice({
    required this.ipAddress,
    this.macAddress,
    this.hostname,
    this.vendorName,
    this.discoveryMethod = LanDiscoveryMethod.arp,
    required this.discoveredAt,
  });

  String get displayName {
    if (hostname != null && hostname!.isNotEmpty) return hostname!;
    if (vendorName != null && vendorName!.isNotEmpty) return vendorName!;
    return ipAddress;
  }

  String get macDisplay => macAddress ?? 'N/A';
}

enum LanDiscoveryMethod {
  arp,   // ARP table lookup
  mdns,  // mDNS/Bonjour discovery
}

extension LanDiscoveryMethodExt on LanDiscoveryMethod {
  String get label {
    switch (this) {
      case LanDiscoveryMethod.arp:  return 'ARP';
      case LanDiscoveryMethod.mdns: return 'mDNS';
    }
  }
}

/// Hasil scan jaringan LAN lokal.
class LanScanResult {
  final String subnetCidr;      // e.g. "192.168.1.0/24"
  final String deviceIp;        // IP device sendiri
  final List<LanDevice> devices;
  final Duration scanDuration;
  final DateTime timestamp;

  const LanScanResult({
    required this.subnetCidr,
    required this.deviceIp,
    required this.devices,
    required this.scanDuration,
    required this.timestamp,
  });
}
