/// Models untuk hasil network diagnostic tools (ping, DNS, traceroute).
/// Tools ini "aman" — tidak butuh izin khusus.
library;

// ---------------------------------------------------------------------------
// Ping
// ---------------------------------------------------------------------------

/// Hasil ping ke satu host.
class PingResult {
  final String host;
  final String? resolvedIp;
  final List<int?> roundTripMs; // null = timeout/unreachable per packet
  final int packetsSent;
  final int packetsReceived;
  final int? minMs;
  final int? maxMs;
  final double? avgMs;
  final bool isReachable;
  final DateTime timestamp;

  const PingResult({
    required this.host,
    this.resolvedIp,
    required this.roundTripMs,
    required this.packetsSent,
    required this.packetsReceived,
    this.minMs,
    this.maxMs,
    this.avgMs,
    required this.isReachable,
    required this.timestamp,
  });

  double get packetLossPercent {
    if (packetsSent == 0) return 100.0;
    return ((packetsSent - packetsReceived) / packetsSent) * 100.0;
  }

  String get summaryDisplay {
    if (!isReachable) return '$host — Unreachable';
    return '$host — ${avgMs?.toStringAsFixed(1) ?? "N/A"} ms avg, ${packetLossPercent.toStringAsFixed(0)}% loss';
  }
}

// ---------------------------------------------------------------------------
// DNS Lookup
// ---------------------------------------------------------------------------

/// Hasil DNS lookup untuk satu domain.
class DnsResult {
  final String domain;
  final List<String> ipAddresses;
  final int? lookupMs;
  final bool isResolved;
  final String? error;
  final DateTime timestamp;

  const DnsResult({
    required this.domain,
    required this.ipAddresses,
    this.lookupMs,
    required this.isResolved,
    this.error,
    required this.timestamp,
  });

  String get primaryIp => ipAddresses.isNotEmpty ? ipAddresses.first : 'N/A';
}

// ---------------------------------------------------------------------------
// Traceroute
// ---------------------------------------------------------------------------

/// Satu hop dalam traceroute.
class TracerouteHop {
  final int hopNumber;
  final String? ip;
  final String? hostname;
  final List<int?> rttMs; // null = timeout
  final bool isTimeout;

  const TracerouteHop({
    required this.hopNumber,
    this.ip,
    this.hostname,
    required this.rttMs,
    this.isTimeout = false,
  });

  String get displayAddress {
    if (isTimeout) return '* * *';
    if (hostname != null && hostname!.isNotEmpty && hostname != ip) {
      return '$hostname ($ip)';
    }
    return ip ?? '*';
  }

  String get rttDisplay {
    if (isTimeout) return '---';
    final valid = rttMs.whereType<int>().toList();
    if (valid.isEmpty) return '---';
    final avg = valid.reduce((a, b) => a + b) / valid.length;
    return '${avg.toStringAsFixed(1)} ms';
  }
}

/// Hasil traceroute lengkap ke satu host.
class TracerouteResult {
  final String host;
  final String? resolvedIp;
  final List<TracerouteHop> hops;
  final bool reached;
  final DateTime timestamp;

  const TracerouteResult({
    required this.host,
    this.resolvedIp,
    required this.hops,
    required this.reached,
    required this.timestamp,
  });
}
