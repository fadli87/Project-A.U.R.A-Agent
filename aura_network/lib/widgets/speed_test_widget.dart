import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/speed_test_result.dart';
import '../providers/network_monitor_provider.dart';

/// Widget speed test glassmorphic dengan gauge animasi DL + UL.
/// Disclosure banner wajib tampil saat test berlangsung (Rule 16).
class SpeedTestWidget extends ConsumerWidget {
  const SpeedTestWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(speedTestNotifierProvider);
    final notifier = ref.read(speedTestNotifierProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1F3A), Color(0xFF0D1B2A)],
        ),
        border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.25), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Speed Test',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                if (state.isFromCache && state.result != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: Text(
                      'cached',
                      style: TextStyle(color: Colors.amber.shade300, fontSize: 10, fontFamily: 'Inter'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),

            // Disclosure banner — WAJIB saat test berlangsung
            if (state.phase == SpeedTestPhase.downloading ||
                state.phase == SpeedTestPhase.uploading ||
                state.phase == SpeedTestPhase.pinging)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF4FC3F7), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '📡 Mengirim/menerima data ke server eksternal untuk mengukur kecepatan',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Phase indicator
            if (state.phase != SpeedTestPhase.idle)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Text(
                      state.phase.label,
                      style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 13, fontFamily: 'Inter'),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: state.progress,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      color: const Color(0xFF4FC3F7),
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 6,
                    ),
                  ],
                ),
              ),

            // Gauges row — DL + UL
            Row(
              children: [
                Expanded(
                  child: _SpeedGauge(
                    label: '⬇ Download',
                    mbps: state.downloadMbps,
                    color: const Color(0xFF4CAF50),
                    isActive: state.phase == SpeedTestPhase.downloading,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SpeedGauge(
                    label: '⬆ Upload',
                    mbps: state.uploadMbps,
                    color: const Color(0xFF2196F3),
                    isActive: state.phase == SpeedTestPhase.uploading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Bottom metrics: Ping | Jitter | Server
            if (state.result != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _BottomMetric(label: 'Ping', value: state.result!.latencyDisplay),
                  _BottomMetric(label: 'Jitter', value: state.result!.jitterDisplay),
                  _BottomMetric(label: 'Quality', value: state.result!.quality.label),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                state.result!.serverName,
                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10, fontFamily: 'Inter'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],

            // Start button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.phase == SpeedTestPhase.idle ||
                        state.phase == SpeedTestPhase.done ||
                        state.phase == SpeedTestPhase.error
                    ? () => notifier.runTest()
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7).withOpacity(0.15),
                  foregroundColor: const Color(0xFF4FC3F7),
                  disabledBackgroundColor: Colors.white.withOpacity(0.05),
                  disabledForegroundColor: Colors.white.withOpacity(0.3),
                  side: const BorderSide(color: Color(0xFF4FC3F7), width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  state.phase == SpeedTestPhase.idle || state.phase == SpeedTestPhase.done || state.phase == SpeedTestPhase.error
                      ? 'Mulai Speed Test'
                      : 'Testing...',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gauge animasi semi-lingkaran untuk DL atau UL Mbps.
class _SpeedGauge extends StatelessWidget {
  final String label;
  final double mbps;
  final Color color;
  final bool isActive;
  static const double _maxMbps = 200;

  const _SpeedGauge({
    required this.label,
    required this.mbps,
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (mbps / _maxMbps).clamp(0.0, 1.0);

    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 60,
          child: CustomPaint(
            painter: _GaugePainter(fraction: fraction, color: color, isActive: isActive),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            mbps > 0 ? '${mbps.toStringAsFixed(1)} Mbps' : '--- Mbps',
            key: ValueKey(mbps.toStringAsFixed(1)),
            style: TextStyle(
              color: mbps > 0 ? color : Colors.white.withOpacity(0.3),
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontFamily: 'Inter'),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double fraction;
  final Color color;
  final bool isActive;

  const _GaugePainter({required this.fraction, required this.color, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height;
    final radius = size.width / 2 - 4;

    final trackPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = isActive ? color : color.withOpacity(0.6)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Track (background arc)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      math.pi, math.pi, false, trackPaint,
    );

    // Fill arc
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        math.pi, math.pi * fraction, false, fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.fraction != fraction || old.isActive != isActive;
}

class _BottomMetric extends StatelessWidget {
  final String label;
  final String value;
  const _BottomMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Inter')),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontFamily: 'Inter')),
      ],
    );
  }
}
