import 'package:decimal/decimal.dart';

/// Represents a single OHLCV (Open, High, Low, Close, Volume) candlestick bar.
/// Follows Prinsip 1: All price values use [Decimal] for exact financial precision.
class Candle {
  final DateTime timestamp;
  final Decimal open;
  final Decimal high;
  final Decimal low;
  final Decimal close;
  final double volume;

  Candle({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    num volume = 0,
  }) : volume = volume.toDouble();

  factory Candle.fromJson(Map<String, dynamic> json) {
    return Candle(
      timestamp: json['timestamp'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : DateTime.parse(json['timestamp'].toString()),
      open: Decimal.parse(json['open'].toString()),
      high: Decimal.parse(json['high'].toString()),
      low: Decimal.parse(json['low'].toString()),
      close: Decimal.parse(json['close'].toString()),
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'open': open.toString(),
      'high': high.toString(),
      'low': low.toString(),
      'close': close.toString(),
      'volume': volume,
    };
  }

  @override
  String toString() =>
      'Candle(time: $timestamp, O: $open, H: $high, L: $low, C: $close, V: $volume)';
}
