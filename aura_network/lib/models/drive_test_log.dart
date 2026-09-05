/// Models untuk drive test logging (sinyal seluler + GPS).
/// Log disimpan ke SQLite, diekspor ke CSV & KML.

// ---------------------------------------------------------------------------
// DriveSession
// ---------------------------------------------------------------------------

/// Satu sesi drive test.
class DriveSession {
  final int? id;
  final String name;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int pointCount;
  final bool isAutoStopped; // true jika dihentikan oleh auto-stop timer

  const DriveSession({
    this.id,
    required this.name,
    required this.startedAt,
    this.endedAt,
    this.pointCount = 0,
    this.isAutoStopped = false,
  });

  Duration get duration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  String get durationDisplay {
    final d = duration;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  bool get isActive => endedAt == null;

  DriveSession copyWith({
    int? id,
    String? name,
    DateTime? startedAt,
    DateTime? endedAt,
    int? pointCount,
    bool? isAutoStopped,
  }) =>
      DriveSession(
        id: id ?? this.id,
        name: name ?? this.name,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        pointCount: pointCount ?? this.pointCount,
        isAutoStopped: isAutoStopped ?? this.isAutoStopped,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'started_at': startedAt.millisecondsSinceEpoch,
        if (endedAt != null) 'ended_at': endedAt!.millisecondsSinceEpoch,
        'point_count': pointCount,
        'is_auto_stopped': isAutoStopped ? 1 : 0,
      };

  factory DriveSession.fromMap(Map<String, dynamic> map) => DriveSession(
        id: map['id'] as int?,
        name: map['name'] as String? ?? 'Session',
        startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
        endedAt: map['ended_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['ended_at'] as int)
            : null,
        pointCount: map['point_count'] as int? ?? 0,
        isAutoStopped: (map['is_auto_stopped'] as int? ?? 0) == 1,
      );
}

// ---------------------------------------------------------------------------
// LogPoint
// ---------------------------------------------------------------------------

/// Satu titik data dalam drive test — kombinasi sinyal + GPS + timestamp.
class LogPoint {
  final int? id;
  final int sessionId;
  final DateTime timestamp;

  // GPS
  final double latitude;
  final double longitude;
  final double? altitudeM;
  final double? accuracyM;
  final double? speedMs;

  // Cellular signal (nullable — fallback graceful)
  final String networkType;
  final String? band;
  final int? rsrpDbm;
  final int? rsrqDb;
  final int? sinrDb;
  final int? rssiDbm;
  final int? cellId;
  final int? pci;
  final String? operator_;

  // Speed test (opsional — jika user trigger saat drive test)
  final double? downloadMbps;
  final double? uploadMbps;
  final int? pingMs;

  const LogPoint({
    this.id,
    required this.sessionId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.altitudeM,
    this.accuracyM,
    this.speedMs,
    this.networkType = 'UNKNOWN',
    this.band,
    this.rsrpDbm,
    this.rsrqDb,
    this.sinrDb,
    this.rssiDbm,
    this.cellId,
    this.pci,
    this.operator_,
    this.downloadMbps,
    this.uploadMbps,
    this.pingMs,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'session_id': sessionId,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'latitude': latitude,
        'longitude': longitude,
        'altitude_m': altitudeM,
        'accuracy_m': accuracyM,
        'speed_ms': speedMs,
        'network_type': networkType,
        'band': band,
        'rsrp_dbm': rsrpDbm,
        'rsrq_db': rsrqDb,
        'sinr_db': sinrDb,
        'rssi_dbm': rssiDbm,
        'cell_id': cellId,
        'pci': pci,
        'operator': operator_,
        'download_mbps': downloadMbps,
        'upload_mbps': uploadMbps,
        'ping_ms': pingMs,
      };

  factory LogPoint.fromMap(Map<String, dynamic> map) => LogPoint(
        id: map['id'] as int?,
        sessionId: map['session_id'] as int,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
        altitudeM: map['altitude_m'] as double?,
        accuracyM: map['accuracy_m'] as double?,
        speedMs: map['speed_ms'] as double?,
        networkType: map['network_type'] as String? ?? 'UNKNOWN',
        band: map['band'] as String?,
        rsrpDbm: map['rsrp_dbm'] as int?,
        rsrqDb: map['rsrq_db'] as int?,
        sinrDb: map['sinr_db'] as int?,
        rssiDbm: map['rssi_dbm'] as int?,
        cellId: map['cell_id'] as int?,
        pci: map['pci'] as int?,
        operator_: map['operator'] as String?,
        downloadMbps: map['download_mbps'] as double?,
        uploadMbps: map['upload_mbps'] as double?,
        pingMs: map['ping_ms'] as int?,
      );

  // ---- CSV row ----
  List<dynamic> toCsvRow() => [
        timestamp.toIso8601String(),
        latitude,
        longitude,
        altitudeM ?? '',
        accuracyM ?? '',
        speedMs ?? '',
        networkType,
        band ?? '',
        rsrpDbm ?? '',
        rsrqDb ?? '',
        sinrDb ?? '',
        rssiDbm ?? '',
        cellId ?? '',
        pci ?? '',
        operator_ ?? '',
        downloadMbps ?? '',
        uploadMbps ?? '',
        pingMs ?? '',
      ];

  static List<String> get csvHeaders => [
        'timestamp', 'latitude', 'longitude', 'altitude_m', 'accuracy_m', 'speed_ms',
        'network_type', 'band', 'rsrp_dbm', 'rsrq_db', 'sinr_db', 'rssi_dbm',
        'cell_id', 'pci', 'operator', 'download_mbps', 'upload_mbps', 'ping_ms',
      ];
}

// ---------------------------------------------------------------------------
// Drive test update stream
// ---------------------------------------------------------------------------

/// Update event yang di-emit stream saat drive test berjalan.
class DriveTestUpdate {
  final LogPoint? lastPoint;
  final int pointCount;
  final Duration elapsed;
  final Duration remainingBeforeAutoStop;

  const DriveTestUpdate({
    this.lastPoint,
    required this.pointCount,
    required this.elapsed,
    required this.remainingBeforeAutoStop,
  });
}
