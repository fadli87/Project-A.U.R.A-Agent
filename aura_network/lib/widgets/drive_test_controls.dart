import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/drive_test_provider.dart';

/// Controls widget untuk drive test: Start/Stop, timer, auto-stop countdown.
class DriveTestControls extends ConsumerWidget {
  final VoidCallback? onExportCsv;
  final VoidCallback? onExportKml;

  const DriveTestControls({
    super.key,
    this.onExportCsv,
    this.onExportKml,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driveTestNotifierProvider);
    final notifier = ref.read(driveTestNotifierProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1F3A), Color(0xFF0D1B2A)],
        ),
        border: Border.all(
          color: state.isRunning
              ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header + status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🚗 Drive Test',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                if (state.isRunning)
                  _PulsingDot(color: const Color(0xFF4CAF50)),
              ],
            ),
            const SizedBox(height: 16),

            // Timer row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _TimerTile(
                  label: 'Elapsed',
                  value: _formatDuration(state.elapsed),
                  color: const Color(0xFF4FC3F7),
                ),
                _TimerTile(
                  label: 'Points',
                  value: state.pointCount.toString(),
                  color: const Color(0xFF4CAF50),
                ),
                _TimerTile(
                  label: 'Auto-stop',
                  value: _formatDuration(state.remainingBeforeAutoStop),
                  color: _autoStopColor(state.remainingBeforeAutoStop),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Auto-stop warning
            if (state.isRunning && state.remainingBeforeAutoStop.inMinutes < 30)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_off, color: Colors.orange, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Auto-stop dalam ${state.remainingBeforeAutoStop.inMinutes} menit (hemat baterai)',
                      style: const TextStyle(color: Colors.orange, fontSize: 11, fontFamily: 'Inter'),
                    ),
                  ],
                ),
              ),

            // Last signal reading
            if (state.lastPoint != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      state.lastPoint!.networkType,
                      style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Inter'),
                    ),
                    Text(
                      state.lastPoint!.rsrpDbm != null ? '${state.lastPoint!.rsrpDbm} dBm' : 'N/A',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter'),
                    ),
                    Text(
                      state.lastPoint!.band ?? 'N/A',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Start / Stop button
            SizedBox(
              width: double.infinity,
              child: state.isRunning
                  ? ElevatedButton.icon(
                      onPressed: () => _confirmStop(context, notifier),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Hentikan Drive Test'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withValues(alpha: 0.15),
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => notifier.startSession(),
                      icon: const Icon(Icons.play_circle_outlined),
                      label: const Text('Mulai Drive Test'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFF4CAF50),
                        side: const BorderSide(color: Color(0xFF4CAF50), width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
            ),

            // Export buttons (hanya saat tidak running dan ada session history)
            if (!state.isRunning && state.sessionHistory.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onExportCsv,
                      icon: const Icon(Icons.table_chart_outlined, size: 16),
                      label: const Text('CSV', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white60,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onExportKml,
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('KML', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white60,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmStop(BuildContext context, DriveTestNotifier notifier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3A),
        title: const Text('Hentikan Drive Test?', style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
        content: const Text(
          'Log akan disimpan dan session akan ditutup.',
          style: TextStyle(color: Colors.white70, fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.8)),
            child: const Text('Hentikan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) await notifier.stopSession();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Color _autoStopColor(Duration remaining) {
    if (remaining.inMinutes < 30) return Colors.orange;
    if (remaining.inMinutes < 60) return Colors.amber;
    return Colors.white54;
  }
}

class _TimerTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TimerTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontFamily: 'Inter')),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _anim.value),
          boxShadow: [BoxShadow(color: widget.color.withValues(alpha: _anim.value * 0.5), blurRadius: 8, spreadRadius: 2)],
        ),
      ),
    );
  }
}
