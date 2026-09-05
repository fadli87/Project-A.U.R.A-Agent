import 'package:decimal/decimal.dart';

class EquityPoint {
  final DateTime timestamp;
  final Decimal equity;
  final double drawdownPct;

  const EquityPoint({
    required this.timestamp,
    required this.equity,
    required this.drawdownPct,
  });
}

class BacktestTrade {
  final String id;
  final String symbol;
  final String type; // 'BUY' or 'SELL'
  final Decimal entryPrice;
  final Decimal exitPrice;
  final Decimal lots;
  final Decimal pnl;
  final double pnlPercent;
  final DateTime entryTime;
  final DateTime exitTime;
  final String exitReason; // 'SL', 'TP', 'SIGNAL', 'END_OF_DATA'

  const BacktestTrade({
    required this.id,
    required this.symbol,
    required this.type,
    required this.entryPrice,
    required this.exitPrice,
    required this.lots,
    required this.pnl,
    required this.pnlPercent,
    required this.entryTime,
    required this.exitTime,
    required this.exitReason,
  });

  bool get isProfit => pnl > Decimal.zero;
}

class BacktestResult {
  final Decimal initialBalance;
  final Decimal finalBalance;
  final int totalTrades;
  final int winningTrades;
  final int losingTrades;
  final double winRate;
  final double profitFactor;
  final double maxDrawdownPct;
  final Decimal maxDrawdownAmount;
  final Decimal netProfit;
  final double netProfitPct;
  final List<BacktestTrade> trades;
  final List<EquityPoint> equityCurve;

  const BacktestResult({
    required this.initialBalance,
    required this.finalBalance,
    required this.totalTrades,
    required this.winningTrades,
    required this.losingTrades,
    required this.winRate,
    required this.profitFactor,
    required this.maxDrawdownPct,
    required this.maxDrawdownAmount,
    required this.netProfit,
    required this.netProfitPct,
    required this.trades,
    required this.equityCurve,
  });
}
