import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wifi_info.dart';
import '../providers/network_monitor_provider.dart';

/// Card info WiFi aktif — SSID, RSSI, channel, band, IP.
class WifiInfoCard extends ConsumerWidget {
  const WifiInfoCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wifiAsync = ref.watch(wifiInfoProvider);

    return wifiAsync.when(
      loading: () => _buildShimmer(),
      error: (_, __) => _buildDisconnected(),
      data: (info) => info.isConnected ? _buildConnected(info) : _buildDisconnected(),
    );
  }

  Widget _buildConnected(WifiInfo info) {
    final color = Color(info.signalQuality.colorValue);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1F3A), Color(0xFF0D1B2A)],
        ),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    info.ssidDisplay,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.5)),
                  ),
                  child: Text(info.signalQuality.label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip('📶 ${info.rssiDisplay}'),
                _InfoChip('🔗 ${info.linkSpeedDisplay}'),
                _InfoChip('📡 ${info.bandDisplay}'),
                _InfoChip('Ch ${info.channelDisplay}'),
                if (info.ipAddress != null) _InfoChip('🌐 ${info.ipAddress}'),
                if (info.gateway != null) _InfoChip('GW: ${info.gateway}'),
                _InfoChip('MAC: ${info.bssid}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisconnected() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1A1F3A),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.white38, size: 22),
          SizedBox(width: 12),
          Text('Tidak terhubung ke WiFi', style: TextStyle(color: Colors.white54, fontFamily: 'Inter')),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Container(
      height: 100,
      decoration: BoxDecoration(color: const Color(0xFF1A1F3A), borderRadius: BorderRadius.circular(20)),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4FC3F7))),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String text;
  const _InfoChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, fontFamily: 'Inter')),
    );
  }
}
