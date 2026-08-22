import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

/// Real-time device status bar showing battery level and thermal state.
/// Displayed at the top of every screen to inform users of device health
/// during CPU-intensive inference operations.
class DeviceStatusBar extends ConsumerWidget {
  const DeviceStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Wire up to real battery/thermal platform channels in Fase 3
    // For now, shows placeholder values
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Battery indicator
          _BatteryIndicator(level: 0.78), // placeholder
          const SizedBox(width: 16),

          // Thermal state
          _ThermalIndicator(state: ThermalState.nominal), // placeholder
          const Spacer(),

          // Inference status text
          Text(
            'Semua data tetap di perangkat',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.lock_outline, color: AppTheme.textMuted, size: 10),
        ],
      ),
    );
  }
}

class _BatteryIndicator extends StatelessWidget {
  const _BatteryIndicator({required this.level});

  /// 0.0 to 1.0
  final double level;

  @override
  Widget build(BuildContext context) {
    final color = level > 0.5
        ? AppTheme.statusReady
        : level > 0.2
            ? AppTheme.warning
            : AppTheme.error;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 10,
          child: CustomPaint(
            painter: _BatteryPainter(level: level, color: color),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${(level * 100).toInt()}%',
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _BatteryPainter extends CustomPainter {
  const _BatteryPainter({required this.level, required this.color});

  final double level;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.border;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width - 2, size.height),
      const Radius.circular(2),
    );
    canvas.drawRRect(bodyRect, paint..style = PaintingStyle.stroke);

    // Battery tip
    final tipRect = Rect.fromLTWH(
      size.width - 2,
      size.height * 0.3,
      2,
      size.height * 0.4,
    );
    canvas.drawRect(tipRect, paint..style = PaintingStyle.fill);

    // Fill level
    final fillWidth = (size.width - 6) * level.clamp(0.0, 1.0);
    final fillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 2, fillWidth, size.height - 4),
      const Radius.circular(1),
    );
    canvas.drawRRect(fillRect, paint..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_BatteryPainter oldDelegate) =>
      oldDelegate.level != level || oldDelegate.color != color;
}

/// Thermal state of the device during inference
enum ThermalState { nominal, fair, serious, critical }

class _ThermalIndicator extends StatelessWidget {
  const _ThermalIndicator({required this.state});

  final ThermalState state;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (state) {
      ThermalState.nominal => (Icons.thermostat, AppTheme.statusReady, 'Normal'),
      ThermalState.fair => (Icons.thermostat, AppTheme.warning, 'Hangat'),
      ThermalState.serious => (Icons.whatshot, AppTheme.error, 'Panas'),
      ThermalState.critical => (Icons.warning, AppTheme.error, 'Kritis'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
