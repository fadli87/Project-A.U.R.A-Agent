import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import '../../domain/position_sizer.dart';
import 'mt5_order_dialog.dart';

class RiskCardWidget extends StatefulWidget {
  const RiskCardWidget({super.key});

  @override
  State<RiskCardWidget> createState() => _RiskCardWidgetState();
}

class _RiskCardWidgetState extends State<RiskCardWidget> {
  final _equityController = TextEditingController(text: '10000');
  final _riskPctController = TextEditingController(text: '2.0');
  final _entryController = TextEditingController(text: '2650.0');
  final _slController = TextEditingController(text: '2630.0');
  PositionSizeResult? _calcResult;

  void _calculate() {
    final equity = Decimal.tryParse(_equityController.text) ?? Decimal.fromInt(10000);
    final riskPct = Decimal.tryParse(_riskPctController.text) ?? Decimal.fromInt(2);
    final entry = Decimal.tryParse(_entryController.text) ?? Decimal.zero;
    final sl = Decimal.tryParse(_slController.text) ?? Decimal.zero;

    if (entry > Decimal.zero && sl > Decimal.zero && entry != sl) {
      setState(() {
        _calcResult = PositionSizer.calculateForexGold(
          equity: equity,
          riskPct: riskPct,
          entryPrice: entry,
          stopLoss: sl,
          isGold: true,
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFFFF5252), size: 20),
              SizedBox(width: 8),
              Text(
                'Risk & Lot Calculator',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField('Equity (\$) ', _equityController),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField('Risk (%)', _riskPctController),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTextField('Entry Price', _entryController),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField('Stop Loss', _slController),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _calculate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(Icons.calculate, size: 18),
              label: const Text('Hitung Lot Safe', style: TextStyle(fontSize: 13)),
            ),
          ),
          if (_calcResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          'Rekomendasi Lot:',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_calcResult!.recommendedLots} Lot',
                        style: const TextStyle(
                          color: Color(0xFF00E676),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          'Maksimal Resiko \$:',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '\$${_calcResult!.maxLoss.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFFFF5252),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00E676)),
                        foregroundColor: const Color(0xFF00E676),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        final entry = Decimal.tryParse(_entryController.text) ?? Decimal.zero;
                        final sl = Decimal.tryParse(_slController.text) ?? Decimal.zero;
                        final action = entry >= sl ? 'BUY' : 'SELL';

                        Mt5OrderDialog.show(
                          context,
                          symbol: 'XAUUSD',
                          action: action,
                          volume: _calcResult!.recommendedLots,
                          entryPrice: entry,
                          stopLoss: sl,
                          maxLossAmount: _calcResult!.maxLoss,
                        );
                      },
                      icon: const Icon(Icons.send_to_mobile, size: 14),
                      label: const Text(
                        'Kirim ke MT5',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
        ),
      ],
    );
  }
}
