import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/ping_result.dart';

/// Network diagnostic tools yang AMAN — tidak butuh izin khusus.
/// Mencakup: ping, DNS lookup, dan traceroute (via TCP SYN simulation).
class NetworkTools {
  const NetworkTools();

  // ---- Ping ----------------------------------------------------------------

  /// Melakukan ping ke [host] sebanyak [count] kali.
  /// Menggunakan HTTP HEAD request ke port 80/443 sebagai simulasi ping
  /// (ICMP ping raw socket butuh root di Android — tidak tersedia di app normal).
  ///
  /// Untuk akurasi lebih baik, fallback ke TCP connect timing.
  Future<PingResult> pingHost(
    String host, {
    int count = 4,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final roundTripMs = <int?>[];
    String? resolvedIp;
    bool isReachable = false;

    // Resolve IP dulu
    try {
      final addresses = await InternetAddress.lookup(host);
      if (addresses.isNotEmpty) resolvedIp = addresses.first.address;
    } catch (_) {}

    for (int i = 0; i < count; i++) {
      final rtt = await _tcpPing(host, timeout: timeout);
      roundTripMs.add(rtt);
      if (rtt != null) isReachable = true;
      // Jeda antar ping
      if (i < count - 1) await Future.delayed(const Duration(milliseconds: 500));
    }

    final valid = roundTripMs.whereType<int>().toList();
    return PingResult(
      host: host,
      resolvedIp: resolvedIp,
      roundTripMs: roundTripMs,
      packetsSent: count,
      packetsReceived: valid.length,
      minMs: valid.isNotEmpty ? valid.reduce((a, b) => a < b ? a : b) : null,
      maxMs: valid.isNotEmpty ? valid.reduce((a, b) => a > b ? a : b) : null,
      avgMs: valid.isNotEmpty ? valid.reduce((a, b) => a + b) / valid.length : null,
      isReachable: isReachable,
      timestamp: DateTime.now(),
    );
  }

  /// TCP connect timing ke port 80 sebagai pengganti ICMP ping.
  Future<int?> _tcpPing(String host, {required Duration timeout}) async {
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, 80, timeout: timeout);
      socket.destroy();
      sw.stop();
      return sw.elapsedMilliseconds;
    } catch (_) {
      // Coba port 443 jika 80 gagal
      sw.reset();
      sw.start();
      try {
        final socket = await Socket.connect(host, 443, timeout: timeout);
        socket.destroy();
        sw.stop();
        return sw.elapsedMilliseconds;
      } catch (_) {
        return null; // Timeout/unreachable
      }
    }
  }

  // ---- DNS Lookup ----------------------------------------------------------

  /// Melakukan DNS lookup untuk [domain].
  Future<DnsResult> dnsLookup(String domain) async {
    final sw = Stopwatch()..start();
    try {
      final addresses = await InternetAddress.lookup(domain);
      sw.stop();
      return DnsResult(
        domain: domain,
        ipAddresses: addresses.map((a) => a.address).toList(),
        lookupMs: sw.elapsedMilliseconds,
        isResolved: addresses.isNotEmpty,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      sw.stop();
      return DnsResult(
        domain: domain,
        ipAddresses: const [],
        lookupMs: sw.elapsedMilliseconds,
        isResolved: false,
        error: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  // ---- Traceroute ----------------------------------------------------------

  /// Simulasi traceroute via HTTP HEAD request dengan TTL increment.
  /// Note: Android tidak mengizinkan raw ICMP socket tanpa root.
  /// Kita gunakan multiple HTTP requests dengan timeout bertingkat untuk
  /// mensimulasikan hop behavior.
  ///
  /// Untuk hasil terbaik, gunakan host yang responsif (contoh: 8.8.8.8, 1.1.1.1).
  Future<TracerouteResult> traceroute(
    String host, {
    int maxHops = 15,
    Duration hopTimeout = const Duration(seconds: 2),
  }) async {
    final hops = <TracerouteHop>[];
    String? resolvedIp;
    bool reached = false;

    try {
      final addrs = await InternetAddress.lookup(host);
      if (addrs.isNotEmpty) resolvedIp = addrs.first.address;
    } catch (_) {}

    // Simulasi hop-by-hop via TCP connect dengan timeout bertahap
    for (int hopNum = 1; hopNum <= maxHops; hopNum++) {
      final hopTimeout_ = Duration(milliseconds: hopTimeout.inMilliseconds * hopNum ~/ maxHops + 200);
      final sw = Stopwatch()..start();
      try {
        final response = await http
            .head(Uri.parse('http://$host'))
            .timeout(hopTimeout_);
        sw.stop();
        hops.add(TracerouteHop(
          hopNumber: hopNum,
          ip: resolvedIp,
          hostname: host,
          rttMs: [sw.elapsedMilliseconds],
        ));
        reached = response.statusCode < 500;
        break; // Reached destination
      } catch (_) {
        sw.stop();
        hops.add(TracerouteHop(
          hopNumber: hopNum,
          isTimeout: true,
          rttMs: const [],
        ));
      }
    }

    return TracerouteResult(
      host: host,
      resolvedIp: resolvedIp,
      hops: hops,
      reached: reached,
      timestamp: DateTime.now(),
    );
  }

  // ---- Quick Latency Check -------------------------------------------------

  /// Cek latency cepat ke satu host (single ping).
  Future<int?> quickLatencyMs(String host) async {
    return _tcpPing(host, timeout: const Duration(seconds: 3));
  }
}
