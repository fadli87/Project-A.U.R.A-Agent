import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:csv/csv.dart';
import '../models/cell_signal_info.dart';
import '../models/drive_test_log.dart';
import '../models/speed_test_result.dart';
import 'telephony_bridge.dart';

/// Auto-stop setelah 4 jam (sesuai Rule 16 — cegah boros baterai).
const _kMaxSessionDuration = Duration(hours: 4);

/// Sampling interval default per titik log.
const _kDefaultSamplingInterval = Duration(seconds: 3);

/// Entry point untuk flutter_background_service.
@pragma('vm:entry-point')
void onDriveTestServiceStart(ServiceInstance service) {
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) => service.setAsForegroundService());
    service.on('setAsBackground').listen((_) => service.setAsBackgroundService());
    service.on('updateNotification').listen((event) {
      final title = event?['title'] as String? ?? 'Drive Test Active';
      final content = event?['content'] as String? ?? 'Logging cellular signal...';
      service.setForegroundNotificationInfo(title: title, content: content);
    });
  }
  service.on('stopService').listen((_) => service.stopSelf());
}

/// Manages a drive test session: logging cellular signal + GPS to SQLite,
/// with auto-stop, CSV export, and KML export.
///
/// Ported & extended from G-Net Track clone's DriveTestManager.
class DriveTestManager {
  final TelephonyBridge _telephonyBridge;
  final FlutterBackgroundService _bgService = FlutterBackgroundService();

  DriveSession? _currentSession;
  Timer? _loggingTimer;
  Timer? _autoStopTimer;
  int _pointCount = 0;
  bool _isRunning = false;
  LogPoint? _lastPoint;
  Database? _db;

  final _updateController = StreamController<DriveTestUpdate>.broadcast();
  Stream<DriveTestUpdate> get updateStream => _updateController.stream;

  DriveTestManager({TelephonyBridge? telephonyBridge})
      : _telephonyBridge = telephonyBridge ?? const TelephonyBridge();

  bool get isRunning => _isRunning;
  DriveSession? get currentSession => _currentSession;
  int get pointCount => _pointCount;
  LogPoint? get lastPoint => _lastPoint;

  // ---- Init ----------------------------------------------------------------

  Future<void> initialize() async {
    await _initDb();

    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    await _bgService.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onDriveTestServiceStart,
        isForegroundMode: true,
        autoStart: false,
        notificationChannelId: 'aura_drive_test',
        initialNotificationTitle: 'AURA Drive Test',
        initialNotificationContent: 'Drive test logging is active',
        foregroundServiceNotificationId: 9001,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onDriveTestServiceStart,
        onBackground: (_) async => true,
      ),
    );
  }

  // ---- Start / Stop --------------------------------------------------------

  Future<void> startSession({
    String? name,
    Duration samplingInterval = _kDefaultSamplingInterval,
    Duration maxDuration = _kMaxSessionDuration,
  }) async {
    if (_isRunning) return;

    final sessionName = name ?? 'Session ${DateTime.now().toLocal().toString().substring(0, 16)}';
    final session = DriveSession(name: sessionName, startedAt: DateTime.now());

    // Simpan ke DB
    final id = await _insertSession(session);
    _currentSession = session.copyWith(id: id);
    _pointCount = 0;
    _isRunning = true;

    // Start background service (Android)
    if (!kIsWeb && Platform.isAndroid) {
      await _bgService.startService();
    }

    // Auto-stop timer (Rule 16: max 4 jam)
    _autoStopTimer = Timer(maxDuration, () => stopSession(isAutoStop: true));

    // Logging timer
    _loggingTimer = Timer.periodic(samplingInterval, (_) => _logPoint());

    _emitUpdate();
  }

  Future<void> stopSession({bool isAutoStop = false}) async {
    if (!_isRunning) return;

    _loggingTimer?.cancel();
    _autoStopTimer?.cancel();
    _isRunning = false;

    if (_currentSession?.id != null) {
      await _finalizeSession(_currentSession!.id!, isAutoStop: isAutoStop);
      _currentSession = _currentSession!.copyWith(
        endedAt: DateTime.now(),
        isAutoStopped: isAutoStop,
        pointCount: _pointCount,
      );
    }

    if (!kIsWeb && Platform.isAndroid) {
      _bgService.invoke('stopService');
    }

    _emitUpdate();
  }

  // ---- Logging -------------------------------------------------------------

  Future<void> _logPoint() async {
    if (!_isRunning || _currentSession?.id == null) return;

    // GPS
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}

    if (position == null) return; // Skip titik tanpa GPS

    // Cell signal
    TelephonySnapshot? snapshot;
    try {
      snapshot = await _telephonyBridge.getCellInfo();
    } catch (_) {}

    final cell = snapshot?.servingCell;

    final point = LogPoint(
      sessionId: _currentSession!.id!,
      timestamp: DateTime.now(),
      latitude: position.latitude,
      longitude: position.longitude,
      altitudeM: position.altitude,
      accuracyM: position.accuracy,
      speedMs: position.speed,
      networkType: snapshot?.networkType ?? 'UNKNOWN',
      band: cell?.bandDisplay,
      rsrpDbm: cell?.primarySignalDbm,
      rsrqDb: cell?.rsrq ?? cell?.rsrqDb,
      sinrDb: cell?.sinr,
      rssiDbm: cell?.rssi ?? cell?.dbm,
      cellId: cell?.cellId,
      pci: cell?.pci,
      operator_: snapshot?.operatorDisplayName,
    );

    await _insertLogPoint(point);
    _pointCount++;
    _lastPoint = point;
    _emitUpdate();

    // Update foreground notification
    if (!kIsWeb && Platform.isAndroid) {
      _bgService.invoke('updateNotification', {
        'title': 'AURA Drive Test — ${_currentSession!.name}',
        'content': '$_pointCount titik | ${cell?.networkType ?? "N/A"} ${cell?.rsrpDisplay ?? ""}',
      });
    }
  }

  /// Log speed test result ke titik terakhir (integrasi optional).
  Future<void> logSpeedTestAtCurrentPoint(SpeedTestResult speedResult) async {
    if (!_isRunning || _lastPoint?.id == null) return;
    await _updateLogPointSpeed(
      _lastPoint!.id!,
      downloadMbps: speedResult.downloadMbps,
      uploadMbps: speedResult.uploadMbps,
      pingMs: speedResult.latencyMs,
    );
  }

  // ---- Export --------------------------------------------------------------

  /// Export sesi ke CSV. Simpan ke app-specific storage.
  /// Returns path file CSV yang dihasilkan.
  Future<String> exportToCsv(int sessionId) async {
    final points = await _getSessionPoints(sessionId);
    final session = await _getSession(sessionId);

    final rows = <List<dynamic>>[LogPoint.csvHeaders];
    for (final p in points) {
      rows.add(p.toCsvRow());
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'drive_test_${session?.name ?? sessionId}_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csv);
    return file.path;
  }

  /// Export sesi ke KML untuk Google Earth/Maps.
  /// Returns path file KML yang dihasilkan.
  Future<String> exportToKml(int sessionId) async {
    final points = await _getSessionPoints(sessionId);
    final session = await _getSession(sessionId);
    final sessionName = session?.name ?? 'Drive Test $sessionId';

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buffer.writeln('  <Document>');
    buffer.writeln('    <name>$sessionName</name>');
    buffer.writeln('    <description>AURA Drive Test Export</description>');

    // Style: warna berdasarkan sinyal
    buffer.writeln('    <Style id="excellent"><IconStyle><color>ff00ff00</color></IconStyle></Style>');
    buffer.writeln('    <Style id="good"><IconStyle><color>ff00c000</color></IconStyle></Style>');
    buffer.writeln('    <Style id="fair"><IconStyle><color>ff00a5ff</color></IconStyle></Style>');
    buffer.writeln('    <Style id="poor"><IconStyle><color>ff0000ff</color></IconStyle></Style>');
    buffer.writeln('    <Style id="unknown"><IconStyle><color>ff808080</color></IconStyle></Style>');

    for (final p in points) {
      final quality = _signalQuality(p.rsrpDbm);
      final desc = [
        'Time: ${p.timestamp.toLocal()}',
        'Network: ${p.networkType}',
        'Band: ${p.band ?? "N/A"}',
        'RSRP: ${p.rsrpDbm != null ? "${p.rsrpDbm} dBm" : "N/A"}',
        if (p.downloadMbps != null) 'DL: ${p.downloadMbps!.toStringAsFixed(1)} Mbps',
        if (p.uploadMbps != null) 'UL: ${p.uploadMbps!.toStringAsFixed(1)} Mbps',
      ].join('\n');

      buffer.writeln('    <Placemark>');
      buffer.writeln('      <styleUrl>#$quality</styleUrl>');
      buffer.writeln('      <description><![CDATA[$desc]]></description>');
      buffer.writeln('      <Point><coordinates>${p.longitude},${p.latitude},${p.altitudeM ?? 0}</coordinates></Point>');
      buffer.writeln('    </Placemark>');
    }

    buffer.writeln('  </Document>');
    buffer.writeln('</kml>');

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'drive_test_${sessionName}_${DateTime.now().millisecondsSinceEpoch}.kml';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  String _signalQuality(int? rsrp) {
    if (rsrp == null) return 'unknown';
    if (rsrp >= -85) return 'excellent';
    if (rsrp >= -98) return 'good';
    if (rsrp >= -110) return 'fair';
    return 'poor';
  }

  // ---- DB queries (public untuk backup) ------------------------------------

  Future<List<DriveSession>> getAllSessions() async {
    final db = _db!;
    final rows = db.select('SELECT * FROM sessions ORDER BY started_at DESC');
    return rows.map((r) => DriveSession.fromMap(r)).toList();
  }

  Future<List<LogPoint>> _getSessionPoints(int sessionId) async {
    final db = _db!;
    final rows = db.select(
      'SELECT * FROM log_points WHERE session_id = ? ORDER BY timestamp ASC',
      [sessionId],
    );
    return rows.map((r) => LogPoint.fromMap(r)).toList();
  }

  Future<DriveSession?> _getSession(int sessionId) async {
    final db = _db!;
    final rows = db.select('SELECT * FROM sessions WHERE id = ?', [sessionId]);
    if (rows.isEmpty) return null;
    return DriveSession.fromMap(rows.first);
  }

  // ---- DB CRUD -------------------------------------------------------------

  Future<void> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    _db = sqlite3.open('${dir.path}/aura_network.db');
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        point_count INTEGER DEFAULT 0,
        is_auto_stopped INTEGER DEFAULT 0
      )
    ''');
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS log_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude_m REAL,
        accuracy_m REAL,
        speed_ms REAL,
        network_type TEXT,
        band TEXT,
        rsrp_dbm INTEGER,
        rsrq_db INTEGER,
        sinr_db INTEGER,
        rssi_dbm INTEGER,
        cell_id INTEGER,
        pci INTEGER,
        operator TEXT,
        download_mbps REAL,
        upload_mbps REAL,
        ping_ms INTEGER,
        FOREIGN KEY (session_id) REFERENCES sessions(id)
      )
    ''');
  }

  Future<int> _insertSession(DriveSession session) async {
    _db!.execute(
      'INSERT INTO sessions (name, started_at, point_count) VALUES (?, ?, 0)',
      [session.name, session.startedAt.millisecondsSinceEpoch],
    );
    return _db!.lastInsertRowId;
  }

  Future<void> _finalizeSession(int id, {required bool isAutoStop}) async {
    _db!.execute(
      'UPDATE sessions SET ended_at = ?, point_count = ?, is_auto_stopped = ? WHERE id = ?',
      [DateTime.now().millisecondsSinceEpoch, _pointCount, isAutoStop ? 1 : 0, id],
    );
  }

  Future<void> _insertLogPoint(LogPoint point) async {
    final m = point.toMap();
    final keys = m.keys.where((k) => k != 'id').toList();
    final placeholders = List.filled(keys.length, '?').join(', ');
    _db!.execute(
      'INSERT INTO log_points (${keys.join(', ')}) VALUES ($placeholders)',
      keys.map((k) => m[k]).toList(),
    );
  }

  Future<void> _updateLogPointSpeed(int id, {
    required double downloadMbps,
    required double uploadMbps,
    required int pingMs,
  }) async {
    _db!.execute(
      'UPDATE log_points SET download_mbps = ?, upload_mbps = ?, ping_ms = ? WHERE id = ?',
      [downloadMbps, uploadMbps, pingMs, id],
    );
  }

  // ---- Helpers -------------------------------------------------------------

  void _emitUpdate() {
    if (_updateController.isClosed) return;
    final elapsed = _currentSession != null
        ? DateTime.now().difference(_currentSession!.startedAt)
        : Duration.zero;
    final remaining = _kMaxSessionDuration - elapsed;
    _updateController.add(DriveTestUpdate(
      lastPoint: _lastPoint,
      pointCount: _pointCount,
      elapsed: elapsed,
      remainingBeforeAutoStop: remaining.isNegative ? Duration.zero : remaining,
    ));
  }

  void dispose() {
    _loggingTimer?.cancel();
    _autoStopTimer?.cancel();
    _updateController.close();
    _db?.dispose();
  }
}

extension _CellDataExt on CellData {
  int? get rsrqDb => rsrq;
}
