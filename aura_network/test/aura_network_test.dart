import 'package:flutter_test/flutter_test.dart';
import 'package:aura_network/aura_network.dart';

void main() {
  group('CellSignalInfo & CellData Tests', () {
    test('CellData calculates signal quality and display helpers accurately', () {
      const lteCell = CellData(
        cellType: 'LTE',
        isRegistered: true,
        connectionStatus: 'PRIMARY',
        cellId: 123456,
        pci: 42,
        tac: 200,
        rsrp: -80,
        rsrq: -10,
        sinr: 15,
        cqi: 12,
      );

      expect(lteCell.networkType, equals('LTE'));
      expect(lteCell.rsrpDisplay, equals('-80 dBm'));
      expect(lteCell.rsrqDisplay, equals('-10 dB'));
      expect(lteCell.sinrDisplay, equals('15 dB'));
      expect(lteCell.cqiDisplay, equals('12'));
      expect(lteCell.cellIdDisplay, equals('123456'));
      expect(lteCell.pciDisplay, equals('42'));
      expect(lteCell.signalQuality, equals(SignalQuality.excellent));
    });

    test('CellData signal quality classification boundaries', () {
      const goodCell = CellData(cellType: 'LTE', rsrp: -95);
      expect(goodCell.signalQuality, equals(SignalQuality.good));

      const fairCell = CellData(cellType: 'LTE', rsrp: -105);
      expect(fairCell.signalQuality, equals(SignalQuality.fair));

      const poorCell = CellData(cellType: 'LTE', rsrp: -115);
      expect(poorCell.signalQuality, equals(SignalQuality.poor));

      const unknownCell = CellData(cellType: 'UNKNOWN');
      expect(unknownCell.signalQuality, equals(SignalQuality.unknown));
    });
  });

  group('WifiInfo Tests', () {
    test('WifiInfo calculates link quality based on RSSI', () {
      final wifi = WifiInfo(
        ssid: 'AURA_HQ',
        bssid: '00:11:22:33:44:55',
        rssiDbm: -50,
        band: '5 GHz',
        ipAddress: '192.168.1.100',
        isConnected: true,
        timestamp: DateTime.now(),
      );

      expect(wifi.isConnected, isTrue);
      expect(wifi.is5Ghz, isTrue);
      expect(wifi.rssiDisplay, equals('-50 dBm'));
      expect(wifi.signalQuality, equals(WifiSignalQuality.excellent));
    });
  });

  group('SpeedTest Models Tests', () {
    test('SpeedTestResult calculates properties correctly', () {
      final now = DateTime.now();
      final result = SpeedTestResult(
        downloadMbps: 85.5,
        uploadMbps: 42.1,
        latencyMs: 14,
        jitterMs: 1.2,
        serverName: 'Cloudflare',
        timestamp: now,
      );

      expect(result.downloadMbps, equals(85.5));
      expect(result.uploadMbps, equals(42.1));
      expect(result.latencyMs, equals(14));
      expect(result.isFromCache, isFalse);
    });

    test('SpeedTestProgress handles various phases', () {
      const progress = SpeedTestProgress(
        phase: SpeedTestPhase.downloading,
        currentMbps: 45.0,
        progress: 0.5,
        latencyMs: 20,
      );

      expect(progress.phase, equals(SpeedTestPhase.downloading));
      expect(progress.currentMbps, equals(45.0));
      expect(progress.progress, equals(0.5));
      expect(progress.latencyMs, equals(20));
    });
  });

  group('DriveTest Models Tests', () {
    test('LogPoint instantiates and parses correctly', () {
      final point = LogPoint(
        id: 1,
        sessionId: 10,
        latitude: -6.200000,
        longitude: 106.816666,
        altitudeM: 15.0,
        speedMs: 12.5,
        timestamp: DateTime.now(),
        networkType: 'LTE',
        rsrpDbm: -92,
        rsrqDb: -11,
        sinrDb: 12,
        pci: 101,
        cellId: 44021,
        operator_: 'Telkomsel',
      );

      expect(point.networkType, equals('LTE'));
      expect(point.rsrpDbm, equals(-92));
      expect(point.operator_, equals('Telkomsel'));
    });
  });
}
