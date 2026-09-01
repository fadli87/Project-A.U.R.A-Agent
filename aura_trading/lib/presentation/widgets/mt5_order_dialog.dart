import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import '../../data/sources/mt5/mt5_client.dart';
import '../../data/sources/mt5/mt5_models.dart';

/// Multi-Layer Confirmation Dialog (Prinsip 5: Human Final Trigger).
/// Displays order details and requires explicit user button tap before sending order to MT5.
class Mt5OrderDialog extends StatefulWidget {
  final String symbol;
  final String action; // 'BUY' or 'SELL'
  final Decimal volume; // Lot size
  final Decimal entryPrice;
  final Decimal stopLoss;
  final Decimal? takeProfit;
  final Decimal maxLossAmount;

  const Mt5OrderDialog({
    super.key,
    required this.symbol,
    required this.action,
    required this.volume,
    required this.entryPrice,
    required this.stopLoss,
    this.takeProfit,
    required this.maxLossAmount,
  });

  static Future<void> show(
    BuildContext context, {
    required String symbol,
    required String action,
    required Decimal volume,
    required Decimal entryPrice,
    required Decimal stopLoss,
    Decimal? takeProfit,
    required Decimal maxLossAmount,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Mt5OrderDialog(
        symbol: symbol,
        action: action,
        volume: volume,
        entryPrice: entryPrice,
        stopLoss: stopLoss,
        takeProfit: takeProfit,
        maxLossAmount: maxLossAmount,
      ),
    );
  }

  @override
  State<Mt5OrderDialog> createState() => _Mt5OrderDialogState();
}

class _Mt5OrderDialogState extends State<Mt5OrderDialog> {
  final Mt5Client _client = Mt5Client();
  bool _isSending = false;
  String? _statusMessage;
  bool _isSuccess = false;

  Future<void> _executeOrder() async {
    setState(() {
      _isSending = true;
      _statusMessage = null;
    });

    final request = Mt5OrderRequest(
      symbol: widget.symbol,
      type: widget.action,
      volume: widget.volume,
      stopLoss: widget.stopLoss,
      takeProfit: widget.takeProfit,
    );

    final result = await _client.sendOrder(request);

    if (mounted) {
      setState(() {
        _isSending = false;
        _isSuccess = result.success;
        _statusMessage = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBuy = widget.action.toUpperCase() == 'BUY';
    final actionColor = isBuy ? const Color(0xFF00E676) : const Color(0xFFFF5252);

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: actionColor.withValues(alpha: 0.5), width: 1.5),
      ),
      title: Row(
        children: [
          Icon(Icons.gavel, color: actionColor, size: 22),
          const SizedBox(width: 8),
          const Text(
            'Konfirmasi Eksekusi MT5',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: actionColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.symbol} (${widget.action.toUpperCase()})',
                    style: TextStyle(color: actionColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    '${widget.volume} Lot',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _buildDetailRow('Harga Entry', widget.entryPrice.toString()),
            _buildDetailRow('Stop Loss (SL)', widget.stopLoss.toString()),
            _buildDetailRow('Take Profit (TP)', widget.takeProfit?.toString() ?? 'N/A'),
            const Divider(height: 16, color: Colors.white10),
            _buildDetailRow('Maksimal Risiko (Loss)', '\$${widget.maxLossAmount.toStringAsFixed(2)}', color: const Color(0xFFFF5252)),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield, color: Colors.amber, size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Prinsip 5: Order hanya dikirim ke MT5 setelah Anda menekan tombol di bawah ini.',
                      style: TextStyle(color: Colors.amber, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isSuccess
                      ? const Color(0xFF00E676).withValues(alpha: 0.15)
                      : const Color(0xFFFF5252).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _isSuccess ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: actionColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isSending ? null : _executeOrder,
          icon: _isSending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send, size: 16, color: Colors.white),
          label: Text(
            _isSending ? 'Mengirim...' : '🚀 Eksekusi ke MT5',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }
}
