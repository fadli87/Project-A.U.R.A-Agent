import 'package:flutter_test/flutter_test.dart';
import 'package:aura_trading/aura_trading.dart';

void main() {
  group('PositionSizer Tests', () {
    test('calculateForexGold for XAU/USD (Gold) position sizing', () {
      final result = PositionSizer.calculateForexGold(
        equity: 10000,
        riskPct: 2.0, // $200 risk
        entryPrice: 2650.0,
        stopLoss: 2630.0, // 200 pips (20.0 price diff)
        isGold: true,
      );

      expect(result.riskAmount, equals(200.0));
      expect(result.stopLossDistance, equals(200.0)); // 20.0 / 0.1
      expect(result.recommendedLots, equals(0.1)); // $200 / (200 * $10) = 0.1 lot
    });

    test('calculateIDXStock for Saham IDX position sizing', () {
      final result = PositionSizer.calculateIDXStock(
        equity: 100000000, // Rp 100jt
        riskPct: 2.0, // Rp 2jt risk
        entryPrice: 8000, // BBCA Rp 8.000
        stopLoss: 7600, // Rp 400 risk per share
        takeProfit: 8800,
      );

      expect(result.riskAmount, equals(2000000.0));
      expect(result.recommendedLots, equals(50.0)); // 5,000 shares = 50 Lots
      expect(result.totalCapitalRequired, equals(40000000.0)); // 5,000 * 8,000
      expect(result.riskRewardRatio, closeTo(2.0, 0.01));
    });
  });

  group('TechnicalIndicators Tests', () {
    test('calculateEMA returns correct length and values', () {
      final candles = List.generate(
        30,
        (i) => Candle(
          timestamp: DateTime.now().add(Duration(days: i)),
          open: 10.0 + i,
          high: 12.0 + i,
          low: 9.0 + i,
          close: 11.0 + i,
          volume: 100,
        ),
      );

      final ema20 = TechnicalIndicators.calculateEMA(candles, 20);
      expect(ema20.length, equals(30));
      expect(ema20[18], isNull);
      expect(ema20[19], isNotNull);
      expect(ema20[29], isNotNull);
    });

    test('calculateRSI returns values bounded between 0 and 100', () {
      final candles = List.generate(
        30,
        (i) => Candle(
          timestamp: DateTime.now().add(Duration(days: i)),
          open: 100.0 + (i % 2 == 0 ? i : -i),
          high: 105.0,
          low: 95.0,
          close: 100.0 + (i % 2 == 0 ? i * 0.5 : -i * 0.5),
          volume: 500,
        ),
      );

      final rsi = TechnicalIndicators.calculateRSI(candles, period: 14);
      expect(rsi.length, equals(30));
      if (rsi[29] != null) {
        expect(rsi[29]!, greaterThanOrEqualTo(0.0));
        expect(rsi[29]!, lessThanOrEqualTo(100.0));
      }
    });

    test('calculateIchimoku returns Tenkan-sen and Kijun-sen correctly', () {
      final candles = List.generate(
        60,
        (i) => Candle(
          timestamp: DateTime.now().add(Duration(days: i)),
          open: 1.0500 + (i * 0.001),
          high: 1.0550 + (i * 0.001),
          low: 1.0450 + (i * 0.001),
          close: 1.0510 + (i * 0.001),
          volume: 1000,
        ),
      );

      final ichimoku = TechnicalIndicators.calculateIchimoku(candles);
      expect(ichimoku.tenkanSen.length, equals(60));
      expect(ichimoku.kijunSen.length, equals(60));

      // Tenkan-sen (9 periods): bar 8 (index 8) should be valid
      expect(ichimoku.tenkanSen[7], isNull);
      expect(ichimoku.tenkanSen[8], isNotNull);

      // Kijun-sen (26 periods): bar 25 (index 25) should be valid
      expect(ichimoku.kijunSen[24], isNull);
      expect(ichimoku.kijunSen[25], isNotNull);
      expect(ichimoku.senkouSpanA[25], isNotNull);
      expect(ichimoku.senkouSpanB[51], isNotNull);
    });
  });
}

