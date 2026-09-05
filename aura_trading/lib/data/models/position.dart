import 'package:decimal/decimal.dart';
import 'price_ticker.dart';

/// Represents a trading position (either simulated paper trading or tracked broker position).
/// Follows Prinsip 1: All prices, volume, lots, and PnL use [Decimal].
class Position {
  final String id;
  final String symbol;
  final AssetCategory category;
  final String type; // 'BUY' or 'SELL'
  final Decimal entryPrice;
  final Decimal? currentPrice;
  final Decimal? stopLoss;
  final Decimal? takeProfit;
  final Decimal lots;
  final Decimal pnl;
  final String status; // 'OPEN' or 'CLOSED'
  final DateTime openTime;
  final DateTime? closeTime;

  const Position({
    required this.id,
    required this.symbol,
    required this.category,
    required this.type,
    required this.entryPrice,
    this.currentPrice,
    this.stopLoss,
    this.takeProfit,
    required this.lots,
    required this.pnl,
    required this.status,
    required this.openTime,
    this.closeTime,
  });

  factory Position.fromMap(Map<String, dynamic> map) {
    return Position(
      id: map['id']?.toString() ?? '',
      symbol: map['symbol']?.toString() ?? '',
      category: AssetCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => AssetCategory.forex,
      ),
      type: map['type']?.toString() ?? 'BUY',
      entryPrice: Decimal.parse(map['entry_price']?.toString() ?? '0'),
      currentPrice: map['current_price'] != null
          ? Decimal.parse(map['current_price'].toString())
          : null,
      stopLoss: map['stop_loss'] != null
          ? Decimal.parse(map['stop_loss'].toString())
          : null,
      takeProfit: map['take_profit'] != null
          ? Decimal.parse(map['take_profit'].toString())
          : null,
      lots: Decimal.parse(map['lots']?.toString() ?? '0'),
      pnl: Decimal.parse(map['pnl']?.toString() ?? '0'),
      status: map['status']?.toString() ?? 'OPEN',
      openTime: map['open_time'] != null
          ? DateTime.parse(map['open_time'].toString())
          : DateTime.now(),
      closeTime: map['close_time'] != null
          ? DateTime.parse(map['close_time'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'symbol': symbol,
      'category': category.name,
      'type': type,
      'entry_price': entryPrice.toString(),
      'current_price': currentPrice?.toString(),
      'stop_loss': stopLoss?.toString(),
      'take_profit': takeProfit?.toString(),
      'lots': lots.toString(),
      'pnl': pnl.toString(),
      'status': status,
      'open_time': openTime.toIso8601String(),
      'close_time': closeTime?.toIso8601String(),
    };
  }
}
