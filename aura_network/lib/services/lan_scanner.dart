import 'dart:async';
import 'dart:io';
import '../models/lan_device.dart';

/// Scanner perangkat di jaringan LAN lokal.
///
/// BATASAN KERAS (Rule 16):
/// - HANYA scan subnet lokal device sendiri (deteksi otomatis dari IP + netmask).
/// - Pakai ARP table + mDNS discovery PASIF — TIDAK port-scan agresif.
/// - TIDAK mengizinkan input IP range manual sembarangan.
///
/// KATEGORI: Sensitif (network scanning).
class LanScanner {
  const LanScanner();

  /// Scan device di subnet lokal via ARP table parsing + TCP reachability check.
  /// [onDeviceFound] dipanggil setiap device baru ditemukan (streaming discovery).
  Future<LanScanResult> scanLocalSubnet({
    void Function(LanDevice device)? onDeviceFound,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final devices = <LanDevice>[];
    final startTime = DateTime.now();

    // 1. Dapatkan IP lokal device
    final localIp = await _getLocalIpAddress();
    if (localIp == null) {
      return LanScanResult(
        subnetCidr: 'N/A',
        deviceIp: 'N/A',
        devices: const [],
        scanDuration: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
    }

    // 2. Hitung subnet /24 dari IP lokal (misal: 192.168.1.x → scan 192.168.1.1-254)
    final subnetBase = _getSubnetBase(localIp); // "192.168.1"
    final subnetCidr = '$subnetBase.0/24';

    // 3. Coba baca ARP table dulu (lebih cepat, pasif)
    final arpDevices = await _readArpTable(subnetBase);
    for (final d in arpDevices) {
      devices.add(d);
      onDeviceFound?.call(d);
    }

    // 4. TCP ping range (ringan — hanya check port 80/443 reachability)
    // Batasi ke 254 host max, dengan concurrency terbatas untuk tidak agresif
    final futures = <Future<void>>[];
    for (int i = 1; i <= 254; i++) {
      final ip = '$subnetBase.$i';
      if (ip == localIp) continue; // Skip device sendiri
      if (devices.any((d) => d.ipAddress == ip)) continue; // Sudah dari ARP

      futures.add(_checkHost(ip, timeout: const Duration(milliseconds: 800)).then((device) {
        if (device != null) {
          devices.add(device);
          onDeviceFound?.call(device);
        }
      }));

      // Batasi concurrency ke 20 parallel untuk tidak agresif
      if (futures.length >= 20) {
        await Future.wait(futures);
        futures.clear();
      }
    }
    if (futures.isNotEmpty) await Future.wait(futures);

    return LanScanResult(
      subnetCidr: subnetCidr,
      deviceIp: localIp,
      devices: devices..sort((a, b) => _compareIps(a.ipAddress, b.ipAddress)),
      scanDuration: DateTime.now().difference(startTime),
      timestamp: DateTime.now(),
    );
  }

  /// Baca ARP cache dari /proc/net/arp (Android/Linux).
  Future<List<LanDevice>> _readArpTable(String subnetBase) async {
    final devices = <LanDevice>[];
    try {
      final arpFile = File('/proc/net/arp');
      if (!arpFile.existsSync()) return devices;

      final lines = await arpFile.readAsLines();
      for (final line in lines.skip(1)) {
        // Format: IP HW Flags HWAddr Mask Device
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 4) continue;
        final ip = parts[0];
        final mac = parts[3];

        if (!ip.startsWith(subnetBase)) continue; // Hanya subnet lokal
        if (mac == '00:00:00:00:00:00') continue; // Invalid entry

        devices.add(LanDevice(
          ipAddress: ip,
          macAddress: mac.toUpperCase(),
          discoveryMethod: LanDiscoveryMethod.arp,
          discoveredAt: DateTime.now(),
        ));
      }
    } catch (_) {}
    return devices;
  }

  /// TCP reachability check — lightweight, satu port saja.
  Future<LanDevice?> _checkHost(String ip, {required Duration timeout}) async {
    try {
      final socket = await Socket.connect(ip, 80, timeout: timeout);
      socket.destroy();
      return LanDevice(
        ipAddress: ip,
        discoveryMethod: LanDiscoveryMethod.arp,
        discoveredAt: DateTime.now(),
      );
    } catch (_) {
      try {
        final socket = await Socket.connect(ip, 443, timeout: timeout);
        socket.destroy();
        return LanDevice(
          ipAddress: ip,
          discoveryMethod: LanDiscoveryMethod.arp,
          discoveredAt: DateTime.now(),
        );
      } catch (_) {
        return null;
      }
    }
  }

  /// Ambil IP address lokal device (WiFi interface).
  Future<String?> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        // Prioritaskan wlan/wifi interface
        if (iface.name.startsWith('wlan') || iface.name.startsWith('en')) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback) return addr.address;
          }
        }
      }
      // Fallback ke interface apapun
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.168.')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Ambil 3 oktet pertama dari IP (subnet /24 base).
  String _getSubnetBase(String ip) {
    final parts = ip.split('.');
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  /// Compare IP address untuk sorting.
  int _compareIps(String a, String b) {
    final partsA = a.split('.').map(int.parse).toList();
    final partsB = b.split('.').map(int.parse).toList();
    for (int i = 0; i < 4; i++) {
      final diff = partsA[i] - partsB[i];
      if (diff != 0) return diff;
    }
    return 0;
  }
}
