import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ping_result.dart';
import '../providers/network_monitor_provider.dart';

/// Panel tools jaringan: Ping, DNS Lookup, Traceroute.
class NetworkToolsPanel extends ConsumerStatefulWidget {
  const NetworkToolsPanel({super.key});

  @override
  ConsumerState<NetworkToolsPanel> createState() => _NetworkToolsPanelState();
}

class _NetworkToolsPanelState extends ConsumerState<NetworkToolsPanel> {
  final _hostController = TextEditingController(text: '8.8.8.8');
  PingResult? _pingResult;
  DnsResult? _dnsResult;
  bool _isPinging = false;
  bool _isDnsLooking = false;
  String? _error;

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _runPing() async {
    setState(() { _isPinging = true; _error = null; _pingResult = null; });
    try {
      final tools = ref.read(networkToolsProvider);
      final result = await tools.pingHost(_hostController.text.trim());
      if (mounted) setState(() { _pingResult = result; _isPinging = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isPinging = false; });
    }
  }

  Future<void> _runDns() async {
    setState(() { _isDnsLooking = true; _error = null; _dnsResult = null; });
    try {
      final tools = ref.read(networkToolsProvider);
      final result = await tools.dnsLookup(_hostController.text.trim());
      if (mounted) setState(() { _dnsResult = result; _isDnsLooking = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isDnsLooking = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const Text('🔧 Network Tools', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
            const SizedBox(height: 16),

            // Host input
            TextField(
              controller: _hostController,
              style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
              decoration: InputDecoration(
                labelText: 'Host / IP / Domain',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontFamily: 'Inter'),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4FC3F7)),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                  onPressed: () => _hostController.clear(),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Buttons row
            Row(
              children: [
                Expanded(
                  child: _ToolButton(
                    label: 'Ping',
                    icon: Icons.network_ping,
                    isLoading: _isPinging,
                    onTap: _isPinging ? null : _runPing,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ToolButton(
                    label: 'DNS Lookup',
                    icon: Icons.dns_outlined,
                    isLoading: _isDnsLooking,
                    onTap: _isDnsLooking ? null : _runDns,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12, fontFamily: 'Inter')),
              ),

            // Ping result
            if (_pingResult != null) _PingResultCard(result: _pingResult!),

            // DNS result
            if (_dnsResult != null) _DnsResultCard(result: _dnsResult!),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ToolButton({required this.label, required this.icon, required this.isLoading, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: isLoading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4FC3F7).withValues(alpha: 0.12),
        foregroundColor: const Color(0xFF4FC3F7),
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.03),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.2),
        side: const BorderSide(color: Color(0xFF4FC3F7), width: 1),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _PingResultCard extends StatelessWidget {
  final PingResult result;
  const _PingResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              result.isReachable ? Icons.check_circle : Icons.cancel,
              color: result.isReachable ? const Color(0xFF4CAF50) : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'PING — ${result.host}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
            ),
            if (result.resolvedIp != null && result.resolvedIp != result.host)
              Text(' (${result.resolvedIp})', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11, fontFamily: 'Inter')),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _ResultChip('Min: ${result.minMs ?? "---"} ms'),
            _ResultChip('Avg: ${result.avgMs?.toStringAsFixed(1) ?? "---"} ms'),
            _ResultChip('Max: ${result.maxMs ?? "---"} ms'),
            _ResultChip('Loss: ${result.packetLossPercent.toStringAsFixed(0)}%'),
          ],
        ),
        const SizedBox(height: 8),
        // Packet timeline
        Row(
          children: result.roundTripMs.map((ms) {
            final ok = ms != null;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: ok ? '$ms ms' : 'Timeout',
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ok ? const Color(0xFF4CAF50) : Colors.red.withValues(alpha: 0.5),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _DnsResultCard extends StatelessWidget {
  final DnsResult result;
  const _DnsResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              result.isResolved ? Icons.check_circle : Icons.cancel,
              color: result.isResolved ? const Color(0xFF4CAF50) : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'DNS — ${result.domain}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
            ),
            if (result.lookupMs != null)
              Text(' (${result.lookupMs}ms)', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11, fontFamily: 'Inter')),
          ],
        ),
        const SizedBox(height: 8),
        if (result.isResolved)
          ...result.ipAddresses.map((ip) => GestureDetector(
            onTap: () => Clipboard.setData(ClipboardData(text: ip)),
            child: _ResultChip(ip),
          ))
        else
          Text(result.error ?? 'Resolusi gagal', style: const TextStyle(color: Colors.red, fontSize: 12, fontFamily: 'Inter')),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _ResultChip extends StatelessWidget {
  final String text;
  const _ResultChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11, fontFamily: 'Inter')),
    );
  }
}
