// Models for cellular signal info.
// Ported from G-Net Track clone (l:/dev_app/network-monitor) — battle-tested on
// Xiaomi Mi A1 (PixelExperience 12) & Infinix Hot 12i (stock ROM).

/// Info satu SIM slot.
class SimSlotInfo {
  final int subscriptionId;
  final int simSlotIndex;
  final String carrierName;
  final String displayName;
  final String? iccId;
  final bool isActive;

  const SimSlotInfo({
    required this.subscriptionId,
    required this.simSlotIndex,
    this.carrierName = '',
    this.displayName = '',
    this.iccId,
    this.isActive = false,
  });

  factory SimSlotInfo.fromMap(Map<dynamic, dynamic> map) {
    return SimSlotInfo(
      subscriptionId: (map['subscriptionId'] as num?)?.toInt() ?? -1,
      simSlotIndex: (map['simSlotIndex'] as num?)?.toInt() ?? -1,
      carrierName: map['carrierName'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      iccId: map['iccId'] as String?,
      isActive: map['isActive'] as bool? ?? false,
    );
  }

  String get operatorTitle {
    if (carrierName.isNotEmpty && displayName.isNotEmpty && carrierName != displayName) {
      return '$carrierName ($displayName)';
    }
    return carrierName.isNotEmpty ? carrierName : displayName;
  }
}

/// Kualitas sinyal seluler berdasarkan RSRP/dBm.
enum SignalQuality {
  excellent, // >= -85 dBm
  good,      // >= -98 dBm
  fair,      // >= -110 dBm
  poor,      // < -110 dBm
  unknown,
}

extension SignalQualityExt on SignalQuality {
  String get label {
    switch (this) {
      case SignalQuality.excellent: return 'Excellent';
      case SignalQuality.good:      return 'Good';
      case SignalQuality.fair:      return 'Fair';
      case SignalQuality.poor:      return 'Poor';
      case SignalQuality.unknown:   return 'N/A';
    }
  }

  /// Hex color string untuk UI
  int get colorValue {
    switch (this) {
      case SignalQuality.excellent: return 0xFF4CAF50; // Green
      case SignalQuality.good:      return 0xFF8BC34A; // Light green
      case SignalQuality.fair:      return 0xFFFF9800; // Orange
      case SignalQuality.poor:      return 0xFFF44336; // Red
      case SignalQuality.unknown:   return 0xFF9E9E9E; // Grey
    }
  }
}

/// Data satu cell (bisa serving cell atau neighboring cell).
class CellData {
  final String cellType; // LTE, NR, WCDMA, GSM, UNKNOWN
  final bool isRegistered;
  final String connectionStatus; // PRIMARY, SECONDARY, NONE, UNKNOWN

  // Identifiers
  final int? cellId;
  final int? pci;
  final int? tac;
  final int? lac;
  final int? arfcn;
  final String? band;
  final String? mcc;
  final String? mnc;

  // Signal Metrics (LTE/5G)
  final int? rsrp;
  final int? rsrq;
  final int? sinr;
  final int? cqi;
  final int? timingAdvance;

  // Generic / GSM / WCDMA
  final int? rssi;
  final int? dbm;
  final int? level;

  // 5G NR Specific
  final int? ssRsrp;
  final int? ssRsrq;
  final int? ssSinr;
  final int? csiRsrp;
  final int? csiRsrq;
  final int? csiSinr;

  const CellData({
    this.cellType = 'UNKNOWN',
    this.isRegistered = false,
    this.connectionStatus = 'UNKNOWN',
    this.cellId,
    this.pci,
    this.tac,
    this.lac,
    this.arfcn,
    this.band,
    this.mcc,
    this.mnc,
    this.rsrp,
    this.rsrq,
    this.sinr,
    this.cqi,
    this.timingAdvance,
    this.rssi,
    this.dbm,
    this.level,
    this.ssRsrp,
    this.ssRsrq,
    this.ssSinr,
    this.csiRsrp,
    this.csiRsrq,
    this.csiSinr,
  });

  factory CellData.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const CellData();

    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    final parsedRsrp = toInt(map['rsrp']) ?? toInt(map['ssRsrp']) ?? toInt(map['csiRsrp']);
    final parsedRsrq = toInt(map['rsrq']) ?? toInt(map['ssRsrq']) ?? toInt(map['csiRsrq']);
    final parsedSinr = toInt(map['sinr']) ?? toInt(map['ssSinr']) ?? toInt(map['csiSinr']);

    return CellData(
      cellType: (map['cellType'] as String?)?.toUpperCase() ?? 'UNKNOWN',
      isRegistered: map['isRegistered'] as bool? ?? false,
      connectionStatus: map['connectionStatus'] as String? ?? 'UNKNOWN',
      cellId: toInt(map['cellId']),
      pci: toInt(map['pci']),
      tac: toInt(map['tac']),
      lac: toInt(map['lac']),
      arfcn: toInt(map['arfcn']),
      band: map['band'] as String?,
      mcc: map['mcc']?.toString(),
      mnc: map['mnc']?.toString(),
      rsrp: parsedRsrp,
      rsrq: parsedRsrq,
      sinr: parsedSinr,
      cqi: toInt(map['cqi']),
      timingAdvance: toInt(map['timingAdvance']),
      rssi: toInt(map['rssi']),
      dbm: toInt(map['dbm']),
      level: toInt(map['level']),
      ssRsrp: toInt(map['ssRsrp']),
      ssRsrq: toInt(map['ssRsrq']),
      ssSinr: toInt(map['ssSinr']),
      csiRsrp: toInt(map['csiRsrp']),
      csiRsrq: toInt(map['csiRsrq']),
      csiSinr: toInt(map['csiSinr']),
    );
  }

  // ---- Display helpers (graceful fallback: "N/A") ----
  String get networkType   => cellType;
  String get cellIdDisplay => cellId != null ? cellId.toString() : 'N/A';
  String get pciDisplay    => pci != null ? pci.toString() : 'N/A';
  String get tacDisplay    => tac != null ? tac.toString() : (lac != null ? lac.toString() : 'N/A');
  String get lacDisplay    => lac != null ? lac.toString() : 'N/A';
  String get arfcnDisplay  => arfcn != null ? arfcn.toString() : 'N/A';
  String get bandDisplay   => band ?? (arfcn != null ? 'ARFCN $arfcn' : 'N/A');

  String get plmnDisplay {
    if (mcc != null && mnc != null) return '$mcc-$mnc';
    return 'N/A';
  }

  String get rsrpDisplay {
    final val = rsrp ?? ssRsrp ?? csiRsrp;
    return val != null ? '$val dBm' : 'N/A';
  }

  String get rsrqDisplay {
    final val = rsrq ?? ssRsrq ?? csiRsrq;
    return val != null ? '$val dB' : 'N/A';
  }

  String get sinrDisplay {
    final val = sinr ?? ssSinr ?? csiSinr;
    return val != null ? '$val dB' : 'N/A';
  }

  String get rssiDisplay {
    if (rssi != null) return '$rssi dBm';
    if (dbm != null) return '$dbm dBm';
    return 'N/A';
  }

  String get cqiDisplay => cqi != null ? cqi.toString() : 'N/A';
  String get timingAdvanceDisplay => timingAdvance != null ? timingAdvance.toString() : 'N/A';

  /// Primary signal metric untuk ranking/warna.
  int? get primarySignalDbm => rsrp ?? ssRsrp ?? csiRsrp ?? dbm ?? rssi;

  SignalQuality get signalQuality {
    final s = primarySignalDbm;
    if (s == null) return SignalQuality.unknown;
    if (s >= -85)  return SignalQuality.excellent;
    if (s >= -98)  return SignalQuality.good;
    if (s >= -110) return SignalQuality.fair;
    return SignalQuality.poor;
  }
}

/// Snapshot lengkap info jaringan seluler satu subscription.
class TelephonySnapshot {
  final int? subscriptionId;
  final String networkType;
  final String? simOperator;
  final String? simOperatorName;
  final String? networkOperator;
  final String? networkOperatorName;
  final CellData? servingCell;
  final List<CellData> neighborCells;
  final DateTime timestamp;

  const TelephonySnapshot({
    this.subscriptionId,
    this.networkType = 'UNKNOWN',
    this.simOperator,
    this.simOperatorName,
    this.networkOperator,
    this.networkOperatorName,
    this.servingCell,
    this.neighborCells = const [],
    required this.timestamp,
  });

  factory TelephonySnapshot.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return TelephonySnapshot(timestamp: DateTime.now());

    final servingRaw = map['servingCell'] as Map<dynamic, dynamic>?;
    final serving = servingRaw != null ? CellData.fromMap(servingRaw) : null;

    final neighborListRaw = map['neighborCells'] as List<dynamic>? ?? [];
    final neighbors = neighborListRaw
        .map((e) => CellData.fromMap(e as Map<dynamic, dynamic>?))
        .toList();

    return TelephonySnapshot(
      subscriptionId: (map['subscriptionId'] as num?)?.toInt(),
      networkType: map['networkType'] as String? ?? 'UNKNOWN',
      simOperator: map['simOperator'] as String?,
      simOperatorName: map['simOperatorName'] as String?,
      networkOperator: map['networkOperator'] as String?,
      networkOperatorName: map['networkOperatorName'] as String?,
      servingCell: serving,
      neighborCells: neighbors,
      timestamp: DateTime.now(),
    );
  }

  String get operatorDisplayName {
    if (networkOperatorName != null && networkOperatorName!.isNotEmpty) return networkOperatorName!;
    if (simOperatorName != null && simOperatorName!.isNotEmpty) return simOperatorName!;
    if (networkOperator != null && networkOperator!.isNotEmpty) return networkOperator!;
    return 'N/A';
  }
}
