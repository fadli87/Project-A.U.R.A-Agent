import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/sources/mt5/mt5_models.dart';
import '../providers/mt5_provider.dart';

/// Widget that displays live MT5 open positions with close capability.
/// Uses [mt5PositionsRefreshableProvider] for manual + periodic refresh.
class Mt5PositionsWidget extends ConsumerWidget {
  const Mt5PositionsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionsAsync = ref.watch(mt5PositionsRefreshableProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Row(
              children: [
                const Icon(Icons.open_in_new, color: Color(0xFF00E676), size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Posisi Terbuka (MT5)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                // Manual refresh button
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white54, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Refresh posisi',
                  onPressed: () {
                    ref.read(mt5RefreshCounterProvider.notifier).increment();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // ── Body ────────────────────────────────────────────────
          positionsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF6C63FF),
                  ),
                ),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: Colors.white38, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'MT5 tidak terhubung',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            data: (positions) {
              if (positions.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18, horizontal: 14),
                  child: Row(
                    children: [
                      Icon(Icons.inbox_outlined, color: Colors.white24, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Tidak ada posisi terbuka',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: positions.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Colors.white10),
                itemBuilder: (context, i) =>
                    _PositionTile(position: positions[i]),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Individual Position Tile ─────────────────────────────────────

class _PositionTile extends ConsumerWidget {
  final Mt5Position position;
  const _PositionTile({required this.position});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBuy = position.type.toUpperCase() == 'BUY';
    final actionColor =
        isBuy ? const Color(0xFF00E676) : const Color(0xFFFF5252);
    final profitColor = position.profit >= Decimal.zero
        ? const Color(0xFF00E676)
        : const Color(0xFFFF5252);
    final profitPrefix = position.profit >= Decimal.zero ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Direction badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              position.type,
              style: TextStyle(
                color: actionColor,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Symbol + volume
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  position.symbol,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${position.volume} lot @ ${position.openPrice}',
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),

          // Profit
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$profitPrefix\$${position.profit.toStringAsFixed(2)}',
                style: TextStyle(
                  color: profitColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                'SL: ${position.sl}',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(width: 6),

          // Close button
          _ClosePositionButton(position: position),
        ],
      ),
    );
  }
}

// ── Close Position Button with confirmation ───────────────────────

class _ClosePositionButton extends ConsumerStatefulWidget {
  final Mt5Position position;
  const _ClosePositionButton({required this.position});

  @override
  ConsumerState<_ClosePositionButton> createState() =>
      _ClosePositionButtonState();
}

class _ClosePositionButtonState extends ConsumerState<_ClosePositionButton> {
  bool _isClosing = false;

  Future<void> _confirmAndClose() async {
    // Prinsip 5: Konfirmasi eksplisit sebelum close
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFFF5252), width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 20),
            SizedBox(width: 8),
            Text(
              'Tutup Posisi MT5',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ],
        ),
        content: Text(
          'Yakin ingin menutup posisi #${widget.position.ticket} '
          '(${widget.position.type} ${widget.position.symbol} '
          '@ ${widget.position.volume} lot)?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('✅ Tutup Posisi',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isClosing = true);
    try {
      final repo = ref.read(mt5RepositoryProvider);
      final success = await repo.closePosition(widget.position.ticket);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: success
                ? const Color(0xFF00E676).withValues(alpha: 0.9)
                : const Color(0xFFFF5252).withValues(alpha: 0.9),
            content: Text(
              success
                  ? '✅ Posisi #${widget.position.ticket} berhasil ditutup.'
                  : '❌ Gagal menutup posisi. Cek koneksi MT5.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
        if (success) {
          // Trigger refresh
          ref
              .read(mt5RefreshCounterProvider.notifier)
              .increment();
        }
      }
    } finally {
      if (mounted) setState(() => _isClosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: _isClosing
          ? const CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFFFF5252))
          : IconButton(
              icon: const Icon(Icons.close, color: Color(0xFFFF5252), size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Tutup posisi',
              onPressed: _confirmAndClose,
            ),
    );
  }
}
