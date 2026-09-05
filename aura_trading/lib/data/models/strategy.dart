import 'package:decimal/decimal.dart';

enum StrategyType {
  emaCrossover,
  rsiReversion,
}

class TradingStrategy {
  final String name;
  final StrategyType type;
  final int fastPeriod;
  final int slowPeriod;
  final int rsiPeriod;
  final double rsiOversold;
  final double rsiOverbought;
  final Decimal riskPctPerTrade;
  final Decimal? stopLossPips;
  final Decimal? takeProfitPips;

  const TradingStrategy({
    required this.name,
    required this.type,
    this.fastPeriod = 20,
    this.slowPeriod = 50,
    this.rsiPeriod = 14,
    this.rsiOversold = 30.0,
    this.rsiOverbought = 70.0,
    required this.riskPctPerTrade,
    this.stopLossPips,
    this.takeProfitPips,
  });

  factory TradingStrategy.emaCrossover({
    int fastPeriod = 20,
    int slowPeriod = 50,
    Decimal? riskPct,
    Decimal? stopLossPips,
    Decimal? takeProfitPips,
  }) {
    return TradingStrategy(
      name: 'EMA Crossover ($fastPeriod / $slowPeriod)',
      type: StrategyType.emaCrossover,
      fastPeriod: fastPeriod,
      slowPeriod: slowPeriod,
      riskPctPerTrade: riskPct ?? Decimal.parse('2.0'),
      stopLossPips: stopLossPips,
      takeProfitPips: takeProfitPips,
    );
  }

  factory TradingStrategy.rsiReversion({
    int rsiPeriod = 14,
    double rsiOversold = 30.0,
    double rsiOverbought = 70.0,
    Decimal? riskPct,
    Decimal? stopLossPips,
    Decimal? takeProfitPips,
  }) {
    return TradingStrategy(
      name: 'RSI Mean Reversion ($rsiPeriod)',
      type: StrategyType.rsiReversion,
      rsiPeriod: rsiPeriod,
      rsiOversold: rsiOversold,
      rsiOverbought: rsiOverbought,
      riskPctPerTrade: riskPct ?? Decimal.parse('2.0'),
      stopLossPips: stopLossPips,
      takeProfitPips: takeProfitPips,
    );
  }
}
