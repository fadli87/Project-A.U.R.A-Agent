import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lan_device.dart';
import '../providers/network_monitor_provider.dart';

/// List device di subnet lokal dengan scanning indicator.
class LanDevicesList extends ConsumerWidget {
  const LanDevicesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lanScanNotifierProvider);
    final notifier = ref.read(lanScanNotifierProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1F3A), Color(0xFF0D1B2A)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📡 LAN Devices', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                    if (state.result != null)
                      Text(
                        state.result!.subnetCidr,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11, fontFamily: 'Inter'),
                      ),
                  ],
                ),
                IconButton(
                  onPressed: state.isScanning ? null : notifier.startScan,
                  icon: state.isScanning
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4FC3F7)))
                      : const Icon(Icons.refresh, color: Color(0xFF4FC3F7)),
                  tooltip: 'Scan ulang',
                ),
              ],
            ),

            // Disclaimer
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ℹ️ Hanya subnet lokal (${state.result?.subnetCidr ?? "N/A"}) — tidak scan ke jaringan luar',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontFamily: 'Inter'),
              ),
            ),
            const SizedBox(height: 12),

            if (state.result == null && !state.isScanning)
              Center(
                child: TextButton.icon(
                  onPressed: notifier.startScan,
                  icon: const Icon(Icons.search, color: Color(0xFF4FC3F7)),
                  label: const Text('Scan LAN Sekarang', style: TextStyle(color: Color(0xFF4FC3F7), fontFamily: 'Inter')),
                ),
              ),

            if (state.result != null) ...[
              Text(
                '${state.result!.devices.length} device ditemukan (${state.result!.scanDuration.inSeconds}s)',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontFamily: 'Inter'),
              ),
              const SizedBox(height: 8),
              ...state.result!.devices.map((d) => _DeviceTile(device: d)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final LanDevice device;
  const _DeviceTile({required this.device});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.devices, color: Color(0xFF4FC3F7), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                ),
                Text(
                  device.macDisplay,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10, fontFamily: 'Inter'),
                ),
              ],
            ),
          ),
          Text(
            device.ipAddress,
            style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 12, fontFamily: 'Inter'),
          ),
        ],
      ),
    );
  }
}
