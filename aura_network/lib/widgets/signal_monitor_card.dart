import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cell_signal_info.dart';
import '../providers/network_monitor_provider.dart';

/// Glassmorphic card menampilkan sinyal seluler real-time.
/// Auto-refresh setiap 3 detik via [cellSignalProvider].
class SignalMonitorCard extends ConsumerWidget {
  const SignalMonitorCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(cellSignalProvider);

    return snapshot.when(
      loading: () => const _CardShimmer(),
      error: (e, _) => _ErrorCard(message: e.toString()),
      data: (data) => _SignalCard(snapshot: data),
    );
  }
}

class _SignalCard extends StatelessWidget {
  final TelephonySnapshot snapshot;
  const _SignalCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final cell = snapshot.servingCell;
    final quality = cell?.signalQuality ?? SignalQuality.unknown;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1F3A).withValues(alpha: 0.9),
            const Color(0xFF0D1B2A).withValues(alpha: 0.95),
          ],
        ),
        border: Border.all(
          color: Color(quality.colorValue).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(quality.colorValue).withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: operator + network type badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snapshot.operatorDisplayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      snapshot.networkType,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
                _NetworkTypeBadge(networkType: snapshot.networkType),
              ],
            ),
            const SizedBox(height: 20),

            // Signal bars visual
            _SignalBarsRow(quality: quality, rsrp: cell?.primarySignalDbm),
            const SizedBox(height: 20),

            // Metrics grid
            _MetricsGrid(cell: cell),
            const SizedBox(height: 16),

            // Cell details row
            if (cell != null) _CellDetailsRow(cell: cell),
          ],
        ),
      ),
    );
  }
}

class _NetworkTypeBadge extends StatelessWidget {
  final String networkType;
  const _NetworkTypeBadge({required this.networkType});

  Color get _color {
    if (networkType.contains('5G') || networkType.contains('NR')) return const Color(0xFF2196F3);
    if (networkType.contains('4G') || networkType.contains('LTE')) return const Color(0xFF4CAF50);
    if (networkType.contains('3G')) return const Color(0xFFFF9800);
    if (networkType.contains('2G')) return const Color(0xFFF44336);
    return const Color(0xFF9E9E9E);
  }

  String get _shortLabel {
    if (networkType.contains('5G') || networkType.contains('NR')) return '5G';
    if (networkType.contains('4G') || networkType.contains('LTE')) return '4G';
    if (networkType.contains('3G')) return '3G';
    if (networkType.contains('2G')) return '2G';
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.5)),
      ),
      child: Text(
        _shortLabel,
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.bold,
          fontSize: 16,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

class _SignalBarsRow extends StatelessWidget {
  final SignalQuality quality;
  final int? rsrp;
  const _SignalBarsRow({required this.quality, required this.rsrp});

  @override
  Widget build(BuildContext context) {
    final barCount = switch (quality) {
      SignalQuality.excellent => 4,
      SignalQuality.good      => 3,
      SignalQuality.fair      => 2,
      SignalQuality.poor      => 1,
      SignalQuality.unknown   => 0,
    };

    final color = Color(quality.colorValue);

    return Row(
      children: [
        // Signal bars
        Row(
          children: List.generate(4, (i) {
            final active = i < barCount;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 10,
                height: 12.0 + i * 6,
                decoration: BoxDecoration(
                  color: active ? color : color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quality.label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: 'Inter',
              ),
            ),
            if (rsrp != null)
              Text(
                '$rsrp dBm',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final CellData? cell;
  const _MetricsGrid({required this.cell});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _MetricTile(label: 'RSRP', value: cell?.rsrpDisplay ?? 'N/A')),
        const SizedBox(width: 8),
        Expanded(child: _MetricTile(label: 'RSRQ', value: cell?.rsrqDisplay ?? 'N/A')),
        const SizedBox(width: 8),
        Expanded(child: _MetricTile(label: 'SINR', value: cell?.sinrDisplay ?? 'N/A')),
        const SizedBox(width: 8),
        Expanded(child: _MetricTile(label: 'CQI', value: cell?.cqiDisplay ?? 'N/A')),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontFamily: 'Inter')),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
        ],
      ),
    );
  }
}

class _CellDetailsRow extends StatelessWidget {
  final CellData cell;
  const _CellDetailsRow({required this.cell});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _DetailChip(label: 'Band', value: cell.bandDisplay),
          const SizedBox(width: 8),
          _DetailChip(label: 'Cell ID', value: cell.cellIdDisplay),
          const SizedBox(width: 8),
          _DetailChip(label: 'PCI', value: cell.pciDisplay),
          const SizedBox(width: 8),
          _DetailChip(label: 'TAC', value: cell.tacDisplay),
          const SizedBox(width: 8),
          _DetailChip(label: 'PLMN', value: cell.plmnDisplay),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final String value;
  const _DetailChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11, fontFamily: 'Inter'),
      ),
    );
  }
}

class _CardShimmer extends StatelessWidget {
  const _CardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4FC3F7))),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.signal_cellular_off, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Tidak dapat membaca sinyal.\n$message',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
          ),
        ],
      ),
    );
  }
}
