import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DeviceThermalState { nominal, fair, serious, critical }

class DeviceStatusState {
  const DeviceStatusState({
    this.batteryLevel = 0.8,
    this.batteryState = BatteryState.unknown,
    this.thermalState = DeviceThermalState.nominal,
    this.isCharging = false,
  });

  final double batteryLevel; // 0.0 to 1.0
  final BatteryState batteryState;
  final DeviceThermalState thermalState;
  final bool isCharging;

  DeviceStatusState copyWith({
    double? batteryLevel,
    BatteryState? batteryState,
    DeviceThermalState? thermalState,
    bool? isCharging,
  }) {
    return DeviceStatusState(
      batteryLevel: batteryLevel ?? this.batteryLevel,
      batteryState: batteryState ?? this.batteryState,
      thermalState: thermalState ?? this.thermalState,
      isCharging: isCharging ?? this.isCharging,
    );
  }
}

class DeviceStatusNotifier extends Notifier<DeviceStatusState> {
  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _batteryStateSub;
  Timer? _pollingTimer;

  @override
  DeviceStatusState build() {
    ref.onDispose(() {
      _batteryStateSub?.cancel();
      _pollingTimer?.cancel();
    });

    _initBattery();
    return const DeviceStatusState();
  }

  Future<void> _initBattery() async {
    try {
      final level = await _battery.batteryLevel;
      final bState = await _battery.batteryState;
      state = state.copyWith(
        batteryLevel: (level / 100.0).clamp(0.0, 1.0),
        batteryState: bState,
        isCharging: bState == BatteryState.charging || bState == BatteryState.full,
      );

      _batteryStateSub = _battery.onBatteryStateChanged.listen((bState) {
        state = state.copyWith(
          batteryState: bState,
          isCharging: bState == BatteryState.charging || bState == BatteryState.full,
        );
        _refreshLevel();
      });

      // Periodic check every 30 seconds
      _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _refreshLevel();
      });
    } catch (_) {
      // Keep default values if platform is not supported
    }
  }

  Future<void> _refreshLevel() async {
    try {
      final level = await _battery.batteryLevel;
      state = state.copyWith(
        batteryLevel: (level / 100.0).clamp(0.0, 1.0),
      );
    } catch (_) {}
  }

  void updateThermalState(DeviceThermalState thermal) {
    state = state.copyWith(thermalState: thermal);
  }
}

final deviceStatusProvider =
    NotifierProvider<DeviceStatusNotifier, DeviceStatusState>(
  DeviceStatusNotifier.new,
);
