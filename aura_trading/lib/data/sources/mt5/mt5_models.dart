import 'package:decimal/decimal.dart';

/// Account information retrieved from MT5 Terminal.
class Mt5AccountInfo {
  final int login;
  final Decimal balance;
  final Decimal equity;
  final Decimal margin;
  final Decimal freeMargin;
  final String currency;
  final String server;
  final String company;

  const Mt5AccountInfo({
    required this.login,
    required this.balance,
    required this.equity,
    required this.margin,
    required this.freeMargin,
    required this.currency,
    required this.server,
    required this.company,
  });

  factory Mt5AccountInfo.fromJson(Map<String, dynamic> json) {
    return Mt5AccountInfo(
      login: (json['login'] as num?)?.toInt() ?? 0,
      balance: Decimal.parse((json['balance'] ?? '0').toString()),
      equity: Decimal.parse((json['equity'] ?? '0').toString()),
      margin: Decimal.parse((json['margin'] ?? '0').toString()),
      freeMargin: Decimal.parse((json['free_margin'] ?? '0').toString()),
      currency: json['currency']?.toString() ?? 'USD',
      server: json['server']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
    );
  }
}

/// Represents an open position in MT5.
class Mt5Position {
  final int ticket;
  final String symbol;
  final String type; // 'BUY' or 'SELL'
  final Decimal volume;
  final Decimal openPrice;
  final Decimal currentPrice;
  final Decimal sl;
  final Decimal tp;
  final Decimal profit;
  final int timestamp;

  const Mt5Position({
    required this.ticket,
    required this.symbol,
    required this.type,
    required this.volume,
    required this.openPrice,
    required this.currentPrice,
    required this.sl,
    required this.tp,
    required this.profit,
    required this.timestamp,
  });

  factory Mt5Position.fromJson(Map<String, dynamic> json) {
    return Mt5Position(
      ticket: (json['ticket'] as num?)?.toInt() ?? 0,
      symbol: json['symbol']?.toString() ?? '',
      type: json['type']?.toString().toUpperCase() ?? 'BUY',
      volume: Decimal.parse((json['volume'] ?? '0').toString()),
      openPrice: Decimal.parse((json['open_price'] ?? '0').toString()),
      currentPrice: Decimal.parse((json['current_price'] ?? '0').toString()),
      sl: Decimal.parse((json['sl'] ?? '0').toString()),
      tp: Decimal.parse((json['tp'] ?? '0').toString()),
      profit: Decimal.parse((json['profit'] ?? '0').toString()),
      timestamp: (json['time'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Request structure for placing an order in MT5.
class Mt5OrderRequest {
  final String symbol;
  final String type; // 'BUY' or 'SELL'
  final Decimal volume;
  final Decimal? stopLoss;
  final Decimal? takeProfit;

  const Mt5OrderRequest({
    required this.symbol,
    required this.type,
    required this.volume,
    this.stopLoss,
    this.takeProfit,
  });

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'type': type.toUpperCase(),
      'volume': volume.toString(),
      if (stopLoss != null) 'sl': stopLoss.toString(),
      if (takeProfit != null) 'tp': takeProfit.toString(),
    };
  }
}

/// Result of an order placement attempt in MT5.
class Mt5OrderResult {
  final bool success;
  final String orderId;
  final Decimal executedPrice;
  final Decimal volume;
  final String message;

  const Mt5OrderResult({
    required this.success,
    required this.orderId,
    required this.executedPrice,
    required this.volume,
    required this.message,
  });

  factory Mt5OrderResult.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() == 'success';
    return Mt5OrderResult(
      success: status,
      orderId: json['order_id']?.toString() ?? '',
      executedPrice: Decimal.parse((json['executed_price'] ?? '0').toString()),
      volume: Decimal.parse((json['volume'] ?? '0').toString()),
      message: json['message']?.toString() ?? '',
    );
  }
}
