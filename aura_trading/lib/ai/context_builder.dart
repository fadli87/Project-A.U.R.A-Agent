import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/price_ticker.dart';
import '../data/sources/mt5/mt5_models.dart';
import '../data/sources/unified/market_data_repository.dart';
import '../presentation/providers/market_data_provider.dart';
import '../presentation/providers/mt5_provider.dart';

/// Ringkasan kondisi akun MT5 & pasar untuk dikirim ke LLM sebagai system prompt context.
class AiTradingContext {
  final Mt5AccountInfo? account;
  final List<Mt5Position> openPositions;
  final Map<String, PriceTicker> watchlistPrices;
  final String timestamp;

  const AiTradingContext({
    this.account,
    required this.openPositions,
    required this.watchlistPrices,
    required this.timestamp,
  });

  /// Format ringkas untuk system prompt (hemat token).
  /// [compact] = true menghasilkan format super hemat token untuk mobile sub-4B model.
  String toPromptContext({bool compact = false}) {
    if (compact) {
      return _toCompactPromptContext();
    }
    final sb = StringBuffer();

    // Account Summary
    if (account != null) {
      sb.writeln('=== AKUN MT5 (LIVE) ===');
      sb.writeln('Login: #${account!.login} (${account!.currency})');
      sb.writeln('Balance: \$${account!.balance.toStringAsFixed(2)}');
      sb.writeln('Equity: \$${account!.equity.toStringAsFixed(2)}');
      sb.writeln('Margin Used: \$${account!.margin.toStringAsFixed(2)}');
      sb.writeln('Free Margin: \$${account!.freeMargin.toStringAsFixed(2)}');
      sb.writeln('Margin Level: ${_marginLevel()}');
      sb.writeln('');
    } else {
      sb.writeln('=== AKUN MT5 ===');
      sb.writeln('Status: Bridge MT5 tidak terhubung / Offline');
      sb.writeln('');
    }

    // Open Positions
    if (openPositions.isNotEmpty) {
      sb.writeln('=== POSISI TERBUKA (${openPositions.length}) ===');
      for (final p in openPositions) {
        final pnlPrefix = p.profit >= Decimal.zero ? '+' : '';
        sb.writeln(
            '• Ticket #${p.ticket}: ${p.symbol} ${p.type} ${p.volume} lot @ ${p.openPrice} | SL: ${p.sl} | TP: ${p.tp} | PnL: $pnlPrefix\$${p.profit.toStringAsFixed(2)}');
      }
      sb.writeln('');
    } else if (account != null) {
      sb.writeln('=== POSISI TERBUKA ===');
      sb.writeln('Tidak ada posisi terbuka saat ini (Flat).');
      sb.writeln('');
    }

    // Watchlist Prices
    if (watchlistPrices.isNotEmpty) {
      sb.writeln('=== HARGA PASAR (WATCHLIST) ===');
      watchlistPrices.forEach((sym, tick) {
        final chgPrefix = tick.changePercent >= 0 ? '+' : '';
        sb.writeln(
            '$sym: \$${tick.price} ($chgPrefix${tick.changePercent.toStringAsFixed(2)}%)');
      });
      sb.writeln('');
    }

    sb.write('Timestamp Data: $timestamp');
    return sb.toString();
  }

  String _toCompactPromptContext() {
    final sb = StringBuffer();
    if (account != null) {
      sb.writeln(
          'AKUN: Bal: \$${account!.balance.toStringAsFixed(0)}, Eq: \$${account!.equity.toStringAsFixed(0)}, Free: \$${account!.freeMargin.toStringAsFixed(0)} | Margin Level: ${_marginLevel()}');
    }
    if (openPositions.isNotEmpty) {
      sb.writeln('POSISI (${openPositions.length}):');
      for (final p in openPositions.take(2)) {
        final pnlPrefix = p.profit >= Decimal.zero ? '+' : '';
        sb.writeln(
            '• ${p.symbol} ${p.type} ${p.volume}L @ ${p.openPrice} | PnL: $pnlPrefix\$${p.profit.toStringAsFixed(0)}');
      }
    }
    if (watchlistPrices.isNotEmpty) {
      final sample = watchlistPrices.entries.take(3).map((e) => '${e.key}: \$${e.value.price}').join(' | ');
      sb.writeln('HARGA: $sample');
    }
    return sb.toString().trim();
  }

  String _marginLevel() {
    if (account == null || account!.margin == Decimal.zero) return 'N/A';
    try {
      final marginDouble = account!.margin.toDouble();
      if (marginDouble == 0) return 'N/A';
      final ratio = (account!.equity.toDouble() / marginDouble) * 100.0;
      return '${ratio.toStringAsFixed(1)}%';
    } catch (_) {
      return 'N/A';
    }
  }
}

/// Provider yang membangun konteks gabungan untuk AI Trading Coach secara async.
final aiTradingContextProvider =
    FutureProvider.autoDispose<AiTradingContext>((ref) async {
  final repo = ref.watch(mt5RepositoryProvider);
  final marketRepo = ref.watch(marketDataRepositoryProvider);

  // Parallel fetch: account info, open positions, watchlist prices
  final results = await Future.wait([
    repo.getAccountInfo(),
    repo.getOpenPositions(),
    _fetchWatchlistPrices(marketRepo),
  ]);

  return AiTradingContext(
    account: results[0] as Mt5AccountInfo?,
    openPositions: (results[1] as List<Mt5Position>?) ?? [],
    watchlistPrices: (results[2] as Map<String, PriceTicker>?) ?? {},
    timestamp: DateTime.now().toLocal().toString().split('.')[0],
  );
});

Future<Map<String, PriceTicker>> _fetchWatchlistPrices(
    MarketDataRepository marketRepo) async {
  const symbols = [
    (symbol: 'XAU/USD', category: AssetCategory.gold),
    (symbol: 'EUR/USD', category: AssetCategory.forex),
    (symbol: 'GBP/USD', category: AssetCategory.forex),
    (symbol: 'USD/JPY', category: AssetCategory.forex),
  ];

  final prices = <String, PriceTicker>{};
  for (final s in symbols) {
    try {
      final tick = await marketRepo.getQuote(s.symbol, s.category);
      prices[s.symbol] = tick;
    } catch (_) {}
  }
  return prices;
}
