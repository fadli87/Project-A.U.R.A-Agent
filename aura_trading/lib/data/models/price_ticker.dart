import 'package:decimal/decimal.dart';

/// Supported asset categories across Forex, Gold, and IDX Stocks.
enum AssetCategory {
  forex,
  gold,
  idxStock,
}

/// Represents real-time price quotation and 24h market stats for an asset.
/// Follows Prinsip 1: Monetary prices use [Decimal].
class PriceTicker {
  final String symbol;
  final String name;
  final Decimal price;
  final Decimal change;
  final double changePercent;
  final Decimal high24h;
  final Decimal low24h;
  final double volume;
  final DateTime timestamp;
  final AssetCategory category;
  final String dataSource;

  bool get isPositive => change >= Decimal.zero;

  PriceTicker({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.high24h,
    required this.low24h,
    num volume = 0.0,
    required this.timestamp,
    required this.category,
    this.dataSource = 'Unknown',
  }) : volume = volume.toDouble();

  factory PriceTicker.fromJson(Map<String, dynamic> json) {
    final catName = json['category']?.toString() ?? 'forex';
    final cat = AssetCategory.values.firstWhere(
      (c) => c.name == catName,
      orElse: () => AssetCategory.forex,
    );

    return PriceTicker(
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? json['symbol']?.toString() ?? '',
      price: Decimal.parse(json['price']?.toString() ?? '0'),
      change: Decimal.parse(json['change']?.toString() ?? '0'),
      changePercent: (json['change_percent'] as num?)?.toDouble() ?? 0.0,
      high24h: Decimal.parse(json['high_24h']?.toString() ?? json['price']?.toString() ?? '0'),
      low24h: Decimal.parse(json['low_24h']?.toString() ?? json['price']?.toString() ?? '0'),
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'].toString())
          : DateTime.now(),
      category: cat,
      dataSource: json['data_source']?.toString() ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'name': name,
      'price': price.toString(),
      'change': change.toString(),
      'change_percent': changePercent,
      'high_24h': high24h.toString(),
      'low_24h': low24h.toString(),
      'volume': volume,
      'timestamp': timestamp.toIso8601String(),
      'category': category.name,
      'data_source': dataSource,
    };
  }

  @override
  String toString() =>
      'PriceTicker(symbol: $symbol, price: $price, change: $change ($changePercent%), category: ${category.name})';
}
