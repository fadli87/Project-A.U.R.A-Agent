import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import '../../data/models/backtest_result.dart';
import '../../data/models/candle.dart';
import '../../data/models/price_ticker.dart';
import '../../data/models/strategy.dart';
import '../../domain/strategy_backtester.dart';
import 'equity_curve_chart.dart';

class BacktestPanelWidget extends StatefulWidget {
  final List<Candle> candles;
  final AssetCategory category;
  final String symbol;

  const BacktestPanelWidget({
    super.key,
    required this.candles,
    this.category = AssetCategory.forex,
    this.symbol = 'XAU/USD',
  });

  @override
  State<BacktestPanelWidget> createState() => _BacktestPanelWidgetState();
}

class _BacktestPanelWidgetState extends State<BacktestPanelWidget> {
  StrategyType _selectedStrategy = StrategyType.emaCrossover;
  final _initialBalanceController = TextEditingController(text: '10000');
  final _riskPctController = TextEditingController(text: '2.0');

  // EMA Crossover params
  final _fastPeriodController = TextEditingController(text: '20');
  final _slowPeriodController = TextEditingController(text: '50');

  // RSI params
  final _rsiPeriodController = TextEditingController(text: '14');
  final _rsiOversoldController = TextEditingController(text: '30');
  final _rsiOverboughtController = TextEditingController(text: '70');

  BacktestResult? _result;

  void _runBacktest() {
    if (widget.candles.isEmpty) return;

    final initialBalance =
        Decimal.tryParse(_initialBalanceController.text) ?? Decimal.fromInt(10000);
    final riskPct = Decimal.tryParse(_riskPctController.text) ?? Decimal.fromInt(2);

    TradingStrategy strategy;
    if (_selectedStrategy == StrategyType.emaCrossover) {
      final fastP = int.tryParse(_fastPeriodController.text) ?? 20;
      final slowP = int.tryParse(_slowPeriodController.text) ?? 50;
      strategy = TradingStrategy.emaCrossover(
        fastPeriod: fastP,
        slowPeriod: slowP,
        riskPct: riskPct,
      );
    } else {
      final rsiP = int.tryParse(_rsiPeriodController.text) ?? 14;
      final rsiOs = double.tryParse(_rsiOversoldController.text) ?? 30.0;
      final rsiOb = double.tryParse(_rsiOverboughtController.text) ?? 70.0;
      strategy = TradingStrategy.rsiReversion(
        rsiPeriod: rsiP,
        rsiOversold: rsiOs,
        rsiOverbought: rsiOb,
        riskPct: riskPct,
      );
    }

    final res = StrategyBacktester.runBacktest(
      candles: widget.candles,
      strategy: strategy,
      initialBalance: initialBalance,
      category: widget.category,
      symbol: widget.symbol,
    );

    setState(() {
      _result = res;
    });
  }

  @override
  void initState() {
    super.initState();
    _runBacktest();
  }

  @override
  void didUpdateWidget(covariant BacktestPanelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candles != widget.candles) {
      _runBacktest();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Color(0xFF6C63FF), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Strategy Backtester',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              SegmentedButton<StrategyType>(
                segments: const [
                  ButtonSegment(
                    value: StrategyType.emaCrossover,
                    label: Text('EMA Cross', style: TextStyle(fontSize: 10)),
                  ),
                  ButtonSegment(
                    value: StrategyType.rsiReversion,
                    label: Text('RSI Mean', style: TextStyle(fontSize: 10)),
                  ),
                ],
                selected: {_selectedStrategy},
                onSelectionChanged: (set) {
                  setState(() {
                    _selectedStrategy = set.first;
                  });
                  _runBacktest();
                },
                style: ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Params Input Row
          Row(
            children: [
              Expanded(
                child: _buildTextField('Saldo Awal (\$)', _initialBalanceController),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildTextField('Risk (%)', _riskPctController),
              ),
              const SizedBox(width: 6),
              if (_selectedStrategy == StrategyType.emaCrossover) ...[
                Expanded(
                  child: _buildTextField('EMA Fast', _fastPeriodController),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildTextField('EMA Slow', _slowPeriodController),
                ),
              ] else ...[
                Expanded(
                  child: _buildTextField('RSI Period', _rsiPeriodController),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildTextField('Oversold', _rsiOversoldController),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _runBacktest,
              icon: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
              label: const Text(
                'Jalankan Backtest',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Results Section
          if (_result != null) ...[
            // Summary Metrics Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Net Profit',
                    '${_result!.netProfit >= Decimal.zero ? '+' : ''}\$${_result!.netProfit.toStringAsFixed(2)}',
                    _result!.netProfit >= Decimal.zero
                        ? const Color(0xFF00E676)
                        : const Color(0xFFFF5252),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMetricCard(
                    'Win Rate',
                    '${_result!.winRate.toStringAsFixed(1)}%',
                    _result!.winRate >= 50 ? const Color(0xFF00E676) : Colors.amber,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMetricCard(
                    'Profit Factor',
                    _result!.profitFactor.toStringAsFixed(2),
                    _result!.profitFactor >= 1.5 ? const Color(0xFF00E676) : Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMetricCard(
                    'Max DD',
                    '-${_result!.maxDrawdownPct.toStringAsFixed(1)}%',
                    const Color(0xFFFF5252),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Equity Curve Chart
            EquityCurveChartWidget(
              equityCurve: _result!.equityCurve,
              height: 180,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
          ),
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
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9),
        ),
        const SizedBox(height: 2),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 11),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
        ),
      ],
    );
  }
}
