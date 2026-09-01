import 'dart:math';
import 'package:decimal/decimal.dart';
import '../data/models/price_ticker.dart';
import '../data/sources/local/trading_database.dart';

class PaperTradingEngine {
  final TradingDatabase _db = TradingDatabase.instance;

  static final Decimal _d100000 = Decimal.fromInt(100000);
  static final Decimal _d100 = Decimal.fromInt(100);

  /// Opens a new paper trading position.
  Future<Map<String, dynamic>> openPosition({
    required String accountId,
    required String symbol,
    required AssetCategory category,
    required String type, // 'BUY' or 'SELL'
    required Decimal entryPrice,
    Decimal? stopLoss,
    Decimal? takeProfit,
    required Decimal lots,
  }) async {
    final account = await _db.getAccount(accountId);
    if (account == null) {
      throw Exception('Account not found: $accountId');
    }

    final tradeId = 'trade_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}';
    final nowStr = DateTime.now().toIso8601String();

    final trade = {
      'id': tradeId,
      'account_id': accountId,
      'symbol': symbol,
      'category': category.name,
      'type': type.toUpperCase(),
      'entry_price': entryPrice.toString(),
      'exit_price': null,
      'stop_loss': stopLoss?.toString(),
      'take_profit': takeProfit?.toString(),
      'lots': lots.toString(),
      'pnl': '0',
      'status': 'OPEN',
      'open_time': nowStr,
      'close_time': null,
    };

    await _db.insertPaperTrade(trade);
    return trade;
  }

  /// Closes an open paper trading position.
  Future<Decimal> closePosition({
    required String tradeId,
    required Decimal exitPrice,
  }) async {
    final db = await _db.database;
    final stmt = db.prepare('SELECT * FROM paper_trades WHERE id = ?');
    final result = stmt.select([tradeId]);
    stmt.dispose();

    if (result.isEmpty) {
      throw Exception('Trade not found: $tradeId');
    }

    final row = result.first;
    final accountId = row['account_id'] as String;
    final type = row['type'] as String;
    final entryPrice = Decimal.parse(row['entry_price'].toString());
    final lots = Decimal.parse(row['lots'].toString());
    final categoryStr = row['category'] as String;

    final category = AssetCategory.values.firstWhere(
      (c) => c.name == categoryStr,
      orElse: () => AssetCategory.forex,
    );

    final pnl = calculatePnL(
      category: category,
      type: type,
      entryPrice: entryPrice,
      exitPrice: exitPrice,
      lots: lots,
    );

    final nowStr = DateTime.now().toIso8601String();
    await _db.updatePaperTradeStatus(tradeId, 'CLOSED', exitPrice, pnl, nowStr);

    // Update Account Balance & Equity
    final account = await _db.getAccount(accountId);
    if (account != null) {
      final currentBalance = account['balance'] as Decimal;
      final newBalance = currentBalance + pnl;
      await _db.updateAccountBalance(accountId, newBalance, newBalance);
    }

    return pnl;
  }

  /// Calculates Realized or Floating P&L for a trade.
  Decimal calculatePnL({
    required AssetCategory category,
    required String type, // 'BUY' or 'SELL'
    required Decimal entryPrice,
    required Decimal exitPrice,
    required Decimal lots,
  }) {
    final isBuy = type.toUpperCase() == 'BUY';
    final priceDiff = isBuy ? (exitPrice - entryPrice) : (entryPrice - exitPrice);

    switch (category) {
      case AssetCategory.forex:
        // Standard Forex: 1 Lot = 100,000 units base currency
        return priceDiff * lots * _d100000;
      case AssetCategory.gold:
        // Gold (XAU/USD): 1 Lot = 100 oz ($100 per 1.0 price move per lot)
        return priceDiff * lots * _d100;
      case AssetCategory.idxStock:
        // Saham IDX: 1 Lot = 100 lembar saham
        return priceDiff * lots * _d100;
    }
  }

  /// Evaluates open positions against live market prices and triggers SL/TP auto-fill.
  Future<void> evaluateOpenPositions({
    required String accountId,
    required Map<String, Decimal> currentMarketPrices,
  }) async {
    final openTrades = await _db.getOpenPaperTrades(accountId);
    Decimal totalFloatingPnL = Decimal.zero;

    for (final trade in openTrades) {
      final tradeId = trade['id'] as String;
      final symbol = trade['symbol'] as String;
      final type = trade['type'] as String;
      final entryPrice = trade['entry_price'] as Decimal;
      final stopLoss = trade['stop_loss'] as Decimal?;
      final takeProfit = trade['take_profit'] as Decimal?;
      final lots = trade['lots'] as Decimal;
      final categoryStr = trade['category'] as String;

      final category = AssetCategory.values.firstWhere(
        (c) => c.name == categoryStr,
        orElse: () => AssetCategory.forex,
      );

      final currentPrice = currentMarketPrices[symbol];
      if (currentPrice == null) continue;

      final isBuy = type == 'BUY';

      // Check Stop Loss Trigger
      bool hitSL = false;
      if (stopLoss != null) {
        if (isBuy && currentPrice <= stopLoss) hitSL = true;
        if (!isBuy && currentPrice >= stopLoss) hitSL = true;
      }

      // Check Take Profit Trigger
      bool hitTP = false;
      if (takeProfit != null) {
        if (isBuy && currentPrice >= takeProfit) hitTP = true;
        if (!isBuy && currentPrice <= takeProfit) hitTP = true;
      }

      if (hitSL || hitTP) {
        final exitPrice = hitSL ? (stopLoss ?? currentPrice) : (takeProfit ?? currentPrice);
        await closePosition(tradeId: tradeId, exitPrice: exitPrice);
      } else {
        final floatingPnL = calculatePnL(
          category: category,
          type: type,
          entryPrice: entryPrice,
          exitPrice: currentPrice,
          lots: lots,
        );
        totalFloatingPnL += floatingPnL;
      }
    }

    // Update Account Equity with Total Floating PnL
    final account = await _db.getAccount(accountId);
    if (account != null) {
      final balance = account['balance'] as Decimal;
      final currentEquity = balance + totalFloatingPnL;
      await _db.updateAccountBalance(accountId, balance, currentEquity);
    }
  }
}
