import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_trading/aura_trading.dart';

void main() {
  group('PositionSizer Tests', () {
    test('calculateForexGold for XAU/USD (Gold) position sizing', () {
      final result = PositionSizer.calculateForexGold(
        equity: Decimal.fromInt(10000),
        riskPct: Decimal.fromInt(2), // $200 risk
        entryPrice: Decimal.parse('2650.0'),
        stopLoss: Decimal.parse('2630.0'), // 200 pips (20.0 price diff)
        isGold: true,
      );

      expect(result.riskAmount, equals(Decimal.fromInt(200)));
      expect(result.stopLossDistance, equals(Decimal.fromInt(200))); // 20.0 / 0.1
      expect(result.recommendedLots, equals(Decimal.parse('0.1'))); // $200 / (200 * $10) = 0.1 lot
    });

    test('calculateIDXStock for Saham IDX position sizing', () {
      final result = PositionSizer.calculateIDXStock(
        equity: Decimal.fromInt(100000000), // Rp 100jt
        riskPct: Decimal.fromInt(2), // Rp 2jt risk
        entryPrice: Decimal.fromInt(8000), // BBCA Rp 8.000
        stopLoss: Decimal.fromInt(7600), // Rp 400 risk per share
        takeProfit: Decimal.fromInt(8800),
      );

      expect(result.riskAmount, equals(Decimal.fromInt(2000000)));
      expect(result.recommendedLots, equals(Decimal.fromInt(50))); // 5,000 shares = 50 Lots
      expect(result.totalCapitalRequired, equals(Decimal.fromInt(40000000))); // 5,000 * 8,000
      // R:R = (8800-8000) / (8000-7600) = 800/400 = 2.0
      expect(result.riskRewardRatio.toDouble(), closeTo(2.0, 0.01));
    });
  });

  group('TechnicalIndicators Tests', () {
    test('calculateEMA returns correct length and values', () {
      final candles = List.generate(
        30,
        (i) => Candle(
          timestamp: DateTime.now().add(Duration(days: i)),
          open: Decimal.parse((10.0 + i).toString()),
          high: Decimal.parse((12.0 + i).toString()),
          low: Decimal.parse((9.0 + i).toString()),
          close: Decimal.parse((11.0 + i).toString()),
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
          open: Decimal.parse((100.0 + (i % 2 == 0 ? i : -i)).toString()),
          high: Decimal.parse('105.0'),
          low: Decimal.parse('95.0'),
          close: Decimal.parse(
              (100.0 + (i % 2 == 0 ? i * 0.5 : -i * 0.5)).toString()),
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
          open: Decimal.parse((1.0500 + (i * 0.001)).toStringAsFixed(4)),
          high: Decimal.parse((1.0550 + (i * 0.001)).toStringAsFixed(4)),
          low: Decimal.parse((1.0450 + (i * 0.001)).toStringAsFixed(4)),
          close: Decimal.parse((1.0510 + (i * 0.001)).toStringAsFixed(4)),
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
