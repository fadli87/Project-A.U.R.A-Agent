import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/sources/unified/market_data_repository.dart';
import '../../data/models/price_ticker.dart';
import '../../data/models/candle.dart';
import '../../data/models/economic_event.dart';
import '../../data/sources/news/forex_factory_calendar.dart';

final marketDataRepositoryProvider = Provider<MarketDataRepository>((ref) {
  return MarketDataRepository();
});

/// Default watchlist items
final defaultWatchlistSymbolsProvider = Provider<List<({String symbol, AssetCategory category})>>((ref) {
  return const [
    (symbol: 'XAU/USD', category: AssetCategory.gold),
    (symbol: 'EUR/USD', category: AssetCategory.forex),
    (symbol: 'GBP/USD', category: AssetCategory.forex),
    (symbol: 'USD/JPY', category: AssetCategory.forex),
    (symbol: 'BBCA', category: AssetCategory.idxStock),
    (symbol: 'BBRI', category: AssetCategory.idxStock),
    (symbol: 'TLKM', category: AssetCategory.idxStock),
    (symbol: 'ASII', category: AssetCategory.idxStock),
  ];
});

/// Watchlist quotes provider
final watchlistProvider = FutureProvider.autoDispose<List<PriceTicker>>((ref) async {
  final repo = ref.watch(marketDataRepositoryProvider);
  final symbols = ref.watch(defaultWatchlistSymbolsProvider);
  return repo.getWatchlist(symbols);
});

/// Currently selected asset for Chart & Detail view
class SelectedAssetNotifier extends Notifier<({String symbol, AssetCategory category})> {
  @override
  ({String symbol, AssetCategory category}) build() {
    return (symbol: 'XAU/USD', category: AssetCategory.gold);
  }

  void select(({String symbol, AssetCategory category}) asset) {
    state = asset;
  }
}

final selectedAssetProvider =
    NotifierProvider<SelectedAssetNotifier, ({String symbol, AssetCategory category})>(
  SelectedAssetNotifier.new,
);

/// Selected timeframe provider ('1d', '1h', '15m', '5m')
class SelectedTimeframeNotifier extends Notifier<String> {
  @override
  String build() => '1d';

  void setTimeframe(String tf) {
    state = tf;
  }
}

final selectedTimeframeProvider =
    NotifierProvider<SelectedTimeframeNotifier, String>(
  SelectedTimeframeNotifier.new,
);


/// Candle history provider for selected asset & timeframe
final candleHistoryProvider = FutureProvider.autoDispose<List<Candle>>((ref) async {
  final repo = ref.watch(marketDataRepositoryProvider);
  final asset = ref.watch(selectedAssetProvider);
  final timeframe = ref.watch(selectedTimeframeProvider);
  return repo.getCandles(asset.symbol, asset.category, interval: timeframe);
});

/// Economic Calendar Provider
final economicCalendarProvider =
    FutureProvider.autoDispose<List<EconomicEvent>>((ref) async {
  final calendar = ForexFactoryCalendar();
  return calendar.fetchCalendar();
});
