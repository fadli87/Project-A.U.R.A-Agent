import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cell_signal_info.dart';
import '../models/wifi_info.dart';
import '../models/lan_device.dart';
import '../models/ping_result.dart';
import '../models/speed_test_result.dart';
import '../services/telephony_bridge.dart';
import '../services/wifi_service.dart';
import '../services/lan_scanner.dart';
import '../services/network_tools.dart';
import '../services/speed_test_service.dart';

// ============================================================================
// Service providers
// ============================================================================

final telephonyBridgeProvider = Provider<TelephonyBridge>((_) => const TelephonyBridge());
final wifiServiceProvider = Provider<WifiService>((_) => const WifiService());
final lanScannerProvider = Provider<LanScanner>((_) => const LanScanner());
final networkToolsProvider = Provider<NetworkTools>((_) => const NetworkTools());
final speedTestServiceProvider = Provider<SpeedTestService>((_) => SpeedTestService.instance);

// ============================================================================
// Cellular Signal — polling setiap 3 detik
// ============================================================================

final cellSignalProvider = StreamProvider.autoDispose<TelephonySnapshot>((ref) {
  final bridge = ref.watch(telephonyBridgeProvider);
  return Stream.periodic(const Duration(seconds: 3))
      .asyncMap((_) => bridge.getCellInfo())
      .distinct((a, b) =>
          a.servingCell?.rsrpDisplay == b.servingCell?.rsrpDisplay &&
          a.networkType == b.networkType);
});

// ============================================================================
// WiFi Info — polling setiap 5 detik
// ============================================================================

final wifiInfoProvider = StreamProvider.autoDispose<WifiInfo>((ref) {
  final service = ref.watch(wifiServiceProvider);
  return service.wifiInfoStream(interval: const Duration(seconds: 5));
});

// ============================================================================
// LAN Scan — on-demand (StateNotifier)
// ============================================================================

class LanScanState {
  final bool isScanning;
  final LanScanResult? result;
  final String? error;

  const LanScanState({
    this.isScanning = false,
    this.result,
    this.error,
  });

  LanScanState copyWith({bool? isScanning, LanScanResult? result, String? error}) =>
      LanScanState(
        isScanning: isScanning ?? this.isScanning,
        result: result ?? this.result,
        error: error ?? this.error,
      );
}

class LanScanNotifier extends Notifier<LanScanState> {
  LanScanner get _scanner => ref.watch(lanScannerProvider);

  @override
  LanScanState build() => const LanScanState();

  Future<void> startScan() async {
    if (state.isScanning) return;
    state = state.copyWith(isScanning: true, error: null);

    try {
      final result = await _scanner.scanLocalSubnet(
        onDeviceFound: (_) {
          // Re-emit state setiap device baru ditemukan (streaming)
          state = state.copyWith(isScanning: true);
        },
      );
      state = LanScanState(isScanning: false, result: result);
    } catch (e) {
      state = LanScanState(isScanning: false, error: e.toString());
    }
  }
}

final lanScanNotifierProvider =
    NotifierProvider<LanScanNotifier, LanScanState>(
  LanScanNotifier.new,
);

// ============================================================================
// Speed Test — on-demand (Notifier)
// ============================================================================

class SpeedTestState {
  final SpeedTestPhase phase;
  final double downloadMbps;
  final double uploadMbps;
  final int latencyMs;
  final double progress;
  final SpeedTestResult? result;
  final bool isFromCache;
  final String? error;

  const SpeedTestState({
    this.phase = SpeedTestPhase.idle,
    this.downloadMbps = 0,
    this.uploadMbps = 0,
    this.latencyMs = 0,
    this.progress = 0,
    this.result,
    this.isFromCache = false,
    this.error,
  });

  SpeedTestState copyWith({
    SpeedTestPhase? phase,
    double? downloadMbps,
    double? uploadMbps,
    int? latencyMs,
    double? progress,
    SpeedTestResult? result,
    bool? isFromCache,
    String? error,
  }) =>
      SpeedTestState(
        phase: phase ?? this.phase,
        downloadMbps: downloadMbps ?? this.downloadMbps,
        uploadMbps: uploadMbps ?? this.uploadMbps,
        latencyMs: latencyMs ?? this.latencyMs,
        progress: progress ?? this.progress,
        result: result ?? this.result,
        isFromCache: isFromCache ?? this.isFromCache,
        error: error,
      );
}

class SpeedTestNotifier extends Notifier<SpeedTestState> {
  SpeedTestService get _service => ref.watch(speedTestServiceProvider);
  StreamSubscription<SpeedTestProgress>? _sub;

  @override
  SpeedTestState build() {
    ref.onDispose(() {
      _sub?.cancel();
    });
    return const SpeedTestState();
  }

  Future<void> runTest({bool useCacheIfAvailable = false}) async {
    if (state.phase != SpeedTestPhase.idle && state.phase != SpeedTestPhase.done && state.phase != SpeedTestPhase.error) return;

    await _sub?.cancel();
    state = const SpeedTestState(phase: SpeedTestPhase.pinging);

    _sub = _service.runSpeedTest(useCacheIfAvailable: useCacheIfAvailable).listen(
      (progress) {
        state = state.copyWith(
          phase: progress.phase,
          progress: progress.progress,
          latencyMs: progress.latencyMs ?? state.latencyMs,
          downloadMbps: progress.phase == SpeedTestPhase.downloading
              ? progress.currentMbps
              : state.downloadMbps,
          uploadMbps: progress.phase == SpeedTestPhase.uploading
              ? progress.currentMbps
              : state.uploadMbps,
        );

        if (progress.phase == SpeedTestPhase.done) {
          final r = _service.lastResult;
          if (r != null) {
            state = state.copyWith(
              result: r,
              downloadMbps: r.downloadMbps,
              uploadMbps: r.uploadMbps,
              latencyMs: r.latencyMs,
              isFromCache: r.isFromCache,
            );
          }
        }
      },
      onError: (e) {
        state = state.copyWith(phase: SpeedTestPhase.error, error: e.toString());
      },
    );
  }
}

final speedTestNotifierProvider =
    NotifierProvider<SpeedTestNotifier, SpeedTestState>(
  SpeedTestNotifier.new,
);

// ============================================================================
// Network Tools — ping, DNS, traceroute (on-demand Future providers)
// ============================================================================

final pingProvider = FutureProvider.autoDispose.family<PingResult, String>((ref, host) async {
  return ref.watch(networkToolsProvider).pingHost(host);
});

final dnsLookupProvider = FutureProvider.autoDispose.family<DnsResult, String>((ref, domain) async {
  return ref.watch(networkToolsProvider).dnsLookup(domain);
});
