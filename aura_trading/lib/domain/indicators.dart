import 'dart:math';
import '../data/models/candle.dart';

class IndicatorResult {
  final List<double?> values;
  final String name;

  IndicatorResult({required this.name, required this.values});
}

class MacdResult {
  final List<double?> macdLine;
  final List<double?> signalLine;
  final List<double?> histogram;

  MacdResult({
    required this.macdLine,
    required this.signalLine,
    required this.histogram,
  });
}

class BollingerBandsResult {
  final List<double?> upper;
  final List<double?> middle;
  final List<double?> lower;

  BollingerBandsResult({
    required this.upper,
    required this.middle,
    required this.lower,
  });
}

class IchimokuResult {
  final List<double?> tenkanSen; // Conversion Line (9)
  final List<double?> kijunSen; // Base Line (26)
  final List<double?> senkouSpanA; // Leading Span A
  final List<double?> senkouSpanB; // Leading Span B (52)
  final List<double?> chikouSpan; // Lagging Span (26)

  IchimokuResult({
    required this.tenkanSen,
    required this.kijunSen,
    required this.senkouSpanA,
    required this.senkouSpanB,
    required this.chikouSpan,
  });
}


/// Technical Analysis Indicators calculation helper.
class TechnicalIndicators {
  /// Calculates Exponential Moving Average (EMA).
  static List<double?> calculateEMA(List<Candle> candles, int period) {
    if (candles.length < period) {
      return List.filled(candles.length, null);
    }

    final result = List<double?>.filled(candles.length, null);
    final multiplier = 2 / (period + 1);

    // Initial SMA for first EMA seed
    double sum = 0;
    for (int i = 0; i < period; i++) {
      sum += candles[i].close;
    }
    double ema = sum / period;
    result[period - 1] = ema;

    for (int i = period; i < candles.length; i++) {
      ema = (candles[i].close - ema) * multiplier + ema;
      result[i] = ema;
    }

    return result;
  }

  /// Calculates Relative Strength Index (RSI).
  static List<double?> calculateRSI(List<Candle> candles, {int period = 14}) {
    if (candles.length <= period) {
      return List.filled(candles.length, null);
    }

    final result = List<double?>.filled(candles.length, null);
    double gainSum = 0;
    double lossSum = 0;

    for (int i = 1; i <= period; i++) {
      final change = candles[i].close - candles[i - 1].close;
      if (change >= 0) {
        gainSum += change;
      } else {
        lossSum += change.abs();
      }
    }

    double avgGain = gainSum / period;
    double avgLoss = lossSum / period;

    if (avgLoss == 0) {
      result[period] = 100.0;
    } else {
      final rs = avgGain / avgLoss;
      result[period] = 100.0 - (100.0 / (1.0 + rs));
    }

    for (int i = period + 1; i < candles.length; i++) {
      final change = candles[i].close - candles[i - 1].close;
      final gain = change >= 0 ? change : 0.0;
      final loss = change < 0 ? change.abs() : 0.0;

      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;

      if (avgLoss == 0) {
        result[i] = 100.0;
      } else {
        final rs = avgGain / avgLoss;
        result[i] = 100.0 - (100.0 / (1.0 + rs));
      }
    }

    return result;
  }

  /// Calculates MACD (12, 26, 9).
  static MacdResult calculateMACD(
    List<Candle> candles, {
    int fastPeriod = 12,
    int slowPeriod = 26,
    int signalPeriod = 9,
  }) {
    final emaFast = calculateEMA(candles, fastPeriod);
    final emaSlow = calculateEMA(candles, slowPeriod);

    final macdLine = List<double?>.filled(candles.length, null);
    for (int i = 0; i < candles.length; i++) {
      if (emaFast[i] != null && emaSlow[i] != null) {
        macdLine[i] = emaFast[i]! - emaSlow[i]!;
      }
    }

    // Signal Line is EMA of macdLine
    final validMacd = <double>[];
    for (var m in macdLine) {
      if (m != null) validMacd.add(m);
    }

    final signalLine = List<double?>.filled(candles.length, null);
    final histogram = List<double?>.filled(candles.length, null);

    if (validMacd.length >= signalPeriod) {
      final startIndex = candles.length - validMacd.length;
      final multiplier = 2 / (signalPeriod + 1);

      double sum = 0;
      for (int i = 0; i < signalPeriod; i++) {
        sum += validMacd[i];
      }
      double signal = sum / signalPeriod;
      signalLine[startIndex + signalPeriod - 1] = signal;
      histogram[startIndex + signalPeriod - 1] =
          macdLine[startIndex + signalPeriod - 1]! - signal;

      for (int i = signalPeriod; i < validMacd.length; i++) {
        final currentIndex = startIndex + i;
        signal = (validMacd[i] - signal) * multiplier + signal;
        signalLine[currentIndex] = signal;
        histogram[currentIndex] = macdLine[currentIndex]! - signal;
      }
    }

    return MacdResult(
      macdLine: macdLine,
      signalLine: signalLine,
      histogram: histogram,
    );
  }

  /// Calculates Average True Range (ATR).
  static List<double?> calculateATR(List<Candle> candles, {int period = 14}) {
    if (candles.length <= period) {
      return List.filled(candles.length, null);
    }

    final trList = <double>[0.0];
    for (int i = 1; i < candles.length; i++) {
      final highLow = candles[i].high - candles[i].low;
      final highPrevClose = (candles[i].high - candles[i - 1].close).abs();
      final lowPrevClose = (candles[i].low - candles[i - 1].close).abs();
      trList.add(max(highLow, max(highPrevClose, lowPrevClose)));
    }

    final atr = List<double?>.filled(candles.length, null);
    double sum = 0;
    for (int i = 1; i <= period; i++) {
      sum += trList[i];
    }
    double currentAtr = sum / period;
    atr[period] = currentAtr;

    for (int i = period + 1; i < candles.length; i++) {
      currentAtr = (currentAtr * (period - 1) + trList[i]) / period;
      atr[i] = currentAtr;
    }

    return atr;
  }

  /// Calculates Ichimoku Kinko Hyo (9, 26, 52).
  static IchimokuResult calculateIchimoku(
    List<Candle> candles, {
    int tenkanPeriod = 9,
    int kijunPeriod = 26,
    int senkouBPeriod = 52,
    int displacement = 26,
  }) {
    final len = candles.length;
    final tenkanSen = List<double?>.filled(len, null);
    final kijunSen = List<double?>.filled(len, null);
    final senkouSpanA = List<double?>.filled(len, null);
    final senkouSpanB = List<double?>.filled(len, null);
    final chikouSpan = List<double?>.filled(len, null);

    double getHighestHigh(int start, int end) {
      double maxH = candles[start].high;
      for (int i = start + 1; i <= end; i++) {
        if (candles[i].high > maxH) maxH = candles[i].high;
      }
      return maxH;
    }

    double getLowestLow(int start, int end) {
      double minL = candles[start].low;
      for (int i = start + 1; i <= end; i++) {
        if (candles[i].low < minL) minL = candles[i].low;
      }
      return minL;
    }

    for (int i = 0; i < len; i++) {
      // Tenkan-sen (9)
      if (i >= tenkanPeriod - 1) {
        final high = getHighestHigh(i - tenkanPeriod + 1, i);
        final low = getLowestLow(i - tenkanPeriod + 1, i);
        tenkanSen[i] = (high + low) / 2;
      }

      // Kijun-sen (26)
      if (i >= kijunPeriod - 1) {
        final high = getHighestHigh(i - kijunPeriod + 1, i);
        final low = getLowestLow(i - kijunPeriod + 1, i);
        kijunSen[i] = (high + low) / 2;
      }

      // Senkou Span A (Leading Span A)
      if (tenkanSen[i] != null && kijunSen[i] != null) {
        senkouSpanA[i] = (tenkanSen[i]! + kijunSen[i]!) / 2;
      }

      // Senkou Span B (Leading Span B, 52)
      if (i >= senkouBPeriod - 1) {
        final high = getHighestHigh(i - senkouBPeriod + 1, i);
        final low = getLowestLow(i - senkouBPeriod + 1, i);
        senkouSpanB[i] = (high + low) / 2;
      }

      // Chikou Span (Lagging Span, 26)
      if (i >= displacement) {
        chikouSpan[i - displacement] = candles[i].close;
      }
    }

    return IchimokuResult(
      tenkanSen: tenkanSen,
      kijunSen: kijunSen,
      senkouSpanA: senkouSpanA,
      senkouSpanB: senkouSpanB,
      chikouSpan: chikouSpan,
    );
  }
}

