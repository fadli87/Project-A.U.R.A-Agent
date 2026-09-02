import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/mt5_provider.dart';
import '../../services/mt5_service_launcher.dart';

/// Compact MT5 connection status + live balance indicator + Run/Kill controls.
class Mt5StatusBarWidget extends ConsumerStatefulWidget {
  const Mt5StatusBarWidget({super.key});

  @override
  ConsumerState<Mt5StatusBarWidget> createState() => _Mt5StatusBarWidgetState();
}

class _Mt5StatusBarWidgetState extends ConsumerState<Mt5StatusBarWidget> {
  bool _isProcessing = false;

  Future<void> _handleStartService() async {
    setState(() => _isProcessing = true);
    final success = await Mt5ServiceLauncher.startService();
    if (mounted) {
      setState(() => _isProcessing = false);
      ref.read(mt5RefreshCounterProvider.notifier).increment();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '🚀 MT5 Service berhasil dijalankan!'
                : '⚠️ Gagal menjalankan MT5 Service. Pastikan Python & MT5 terinstall.',
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleStopService() async {
    setState(() => _isProcessing = true);
    final stopped = await Mt5ServiceLauncher.stopService();
    if (mounted) {
      setState(() => _isProcessing = false);
      ref.read(mt5RefreshCounterProvider.notifier).increment();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            stopped
                ? '🛑 MT5 Service berhasil dihentikan (Killed).'
                : '⚠️ Service dihentikan.',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionAsync = ref.watch(mt5ConnectionStatusProvider);
    final accountAsync = ref.watch(mt5AccountRefreshableProvider);

    return connectionAsync.when(
      loading: () => _buildStatusChip(
        color: Colors.white24,
        icon: Icons.circle,
        label: 'MT5 ...',
        sublabel: null,
      ),
      error: (_, __) => _buildOfflineChip(),
      data: (connected) {
        if (!connected) return _buildOfflineChip();

        // Connected — show account info
        return accountAsync.when(
          loading: () => _buildStatusChip(
            color: const Color(0xFF00E676),
            icon: Icons.circle,
            label: 'MT5 Connected',
            sublabel: 'Memuat akun...',
          ),
          error: (_, __) => _buildStatusChip(
            color: const Color(0xFF00E676),
            icon: Icons.circle,
            label: 'MT5 Connected',
            sublabel: 'Gagal baca akun',
          ),
          data: (account) {
            if (account == null) {
              return _buildStatusChip(
                color: const Color(0xFF00E676),
                icon: Icons.circle,
                label: 'MT5 Connected',
                sublabel: 'No account data',
              );
            }
            return _buildAccountChip(
              balance: account.balance.toStringAsFixed(2),
              equity: account.equity.toStringAsFixed(2),
              freeMargin: account.freeMargin.toStringAsFixed(2),
              currency: account.currency,
              login: account.login,
              onRefresh: () {
                ref.read(mt5RefreshCounterProvider.notifier).increment();
              },
            );
          },
        );
      },
    );
  }

  Widget _buildOfflineChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle_outlined, color: Colors.white38, size: 10),
          const SizedBox(width: 6),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MT5 Offline',
                style: TextStyle(
                  color: Colors.white60,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              Text(
                'Service mati',
                style: TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(width: 8),
          _isProcessing
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF00E676)),
                )
              : InkWell(
                  onTap: _handleStartService,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF00E676)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Color(0xFF00E676), size: 12),
                        SizedBox(width: 2),
                        Text(
                          'Run Service',
                          style: TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required Color color,
    required IconData icon,
    required String label,
    required String? sublabel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              if (sublabel != null)
                Text(
                  sublabel,
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountChip({
    required String balance,
    required String equity,
    required String freeMargin,
    required String currency,
    required int login,
    required VoidCallback onRefresh,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF00E676).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Connection dot
          const Icon(Icons.circle, color: Color(0xFF00E676), size: 8),
          const SizedBox(width: 6),
          // Account info columns
          _AccountStat(label: 'Balance', value: '$balance $currency'),
          _AccountDivider(),
          _AccountStat(label: 'Equity', value: '$equity $currency'),
          _AccountDivider(),
          _AccountStat(label: 'Free Margin', value: '$freeMargin $currency'),
          _AccountDivider(),
          _AccountStat(label: 'Login', value: '#$login'),
          const SizedBox(width: 4),
          // Refresh button
          GestureDetector(
            onTap: onRefresh,
            child: const Icon(Icons.refresh, color: Colors.white60, size: 14),
          ),
          const SizedBox(width: 6),
          // Kill / Stop Service button
          InkWell(
            onTap: _handleStopService,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 11),
                  SizedBox(width: 2),
                  Text(
                    'Kill',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountStat extends StatelessWidget {
  final String label;
  final String value;
  const _AccountStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 9)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10.5)),
      ],
    );
  }
}

class _AccountDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 1,
      height: 20,
      color: Colors.white12,
    );
  }
}
