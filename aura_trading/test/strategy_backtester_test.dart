import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_trading/aura_trading.dart';

void main() {
  group('StrategyBacktester Tests', () {
    test('runBacktest handles empty candles gracefully', () {
      final strategy = TradingStrategy.emaCrossover();
      final result = StrategyBacktester.runBacktest(
        candles: const [],
        strategy: strategy,
        initialBalance: Decimal.fromInt(10000),
        category: AssetCategory.forex,
      );

      expect(result.totalTrades, equals(0));
      expect(result.finalBalance, equals(Decimal.fromInt(10000)));
      expect(result.netProfit, equals(Decimal.zero));
      expect(result.winRate, equals(0.0));
      expect(result.equityCurve, isEmpty);
    });

    test('runBacktest EMA Crossover strategy on trending candles', () {
      // Generate 100 candles: first 50 flat/downtrend, next 50 strong uptrend
      final candles = <Candle>[];
      final baseDate = DateTime(2026, 1, 1);

      for (int i = 0; i < 100; i++) {
        double closePrice;
        if (i < 50) {
          closePrice = 1.0800 - (i * 0.0002); // downtrend
        } else {
          closePrice = 1.0700 + ((i - 50) * 0.0010); // strong uptrend trigger EMA cross
        }

        candles.add(Candle(
          timestamp: baseDate.add(Duration(days: i)),
          open: Decimal.parse((closePrice - 0.0005).toStringAsFixed(4)),
          high: Decimal.parse((closePrice + 0.0010).toStringAsFixed(4)),
          low: Decimal.parse((closePrice - 0.0010).toStringAsFixed(4)),
          close: Decimal.parse(closePrice.toStringAsFixed(4)),
          volume: 1000,
        ));
      }

      final strategy = TradingStrategy.emaCrossover(
        fastPeriod: 10,
        slowPeriod: 20,
        riskPct: Decimal.parse('2.0'),
      );

      final result = StrategyBacktester.runBacktest(
        candles: candles,
        strategy: strategy,
        initialBalance: Decimal.fromInt(10000),
        category: AssetCategory.forex,
        symbol: 'EUR/USD',
      );

      expect(result.equityCurve.length, equals(100));
      expect(result.totalTrades, greaterThanOrEqualTo(1));
      expect(result.finalBalance, isA<Decimal>());
      expect(result.netProfit, isA<Decimal>());
      expect(result.winRate, greaterThanOrEqualTo(0.0));
      expect(result.winRate, lessThanOrEqualTo(100.0));
      expect(result.maxDrawdownPct, greaterThanOrEqualTo(0.0));
    });

    test('runBacktest RSI Mean Reversion strategy on oscillating candles', () {
      final candles = <Candle>[];
      final baseDate = DateTime(2026, 1, 1);

      for (int i = 0; i < 60; i++) {
        // Oscillation between 2600 and 2700
        final priceVal = 2650.0 + (i % 2 == 0 ? 40.0 : -40.0);
        candles.add(Candle(
          timestamp: baseDate.add(Duration(days: i)),
          open: Decimal.parse('2650.0'),
          high: Decimal.parse((priceVal + 10.0).toStringAsFixed(1)),
          low: Decimal.parse((priceVal - 10.0).toStringAsFixed(1)),
          close: Decimal.parse(priceVal.toStringAsFixed(1)),
          volume: 500,
        ));
      }

      final strategy = TradingStrategy.rsiReversion(
        rsiPeriod: 14,
        rsiOversold: 35.0,
        rsiOverbought: 65.0,
      );

      final result = StrategyBacktester.runBacktest(
        candles: candles,
        strategy: strategy,
        initialBalance: Decimal.fromInt(10000),
        category: AssetCategory.gold,
        symbol: 'XAU/USD',
      );

      expect(result.equityCurve.length, equals(60));
      expect(result.profitFactor, greaterThanOrEqualTo(0.0));
    });
  });
}
