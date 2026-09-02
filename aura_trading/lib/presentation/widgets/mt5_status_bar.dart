import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/mt5_provider.dart';

/// Compact MT5 connection status + live balance indicator for desktop header bar.
/// Shows: 🟢 Connected / 🔴 Offline, Balance, Equity, Free Margin.
class Mt5StatusBarWidget extends ConsumerWidget {
  const Mt5StatusBarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                ref
                    .read(mt5RefreshCounterProvider.notifier)
                    .increment();
              },
            );
          },
        );
      },
    );
  }

  Widget _buildOfflineChip() {
    return _buildStatusChip(
      color: Colors.white30,
      icon: Icons.circle_outlined,
      label: 'MT5 Offline',
      sublabel: 'Bridge tidak aktif',
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
            child: const Icon(Icons.refresh, color: Colors.white38, size: 13),
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
