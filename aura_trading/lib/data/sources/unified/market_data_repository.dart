import '../twelve_data_api.dart';
import '../yahoo_finance_api.dart';
import '../../models/candle.dart';
import '../../models/price_ticker.dart';

abstract class IMarketDataRepository {
  Future<PriceTicker> getQuote(String symbol, AssetCategory category);
  Future<List<Candle>> getCandles(
    String symbol,
    AssetCategory category, {
    String interval = '1d',
    String range = '1mo',
  });
  Future<List<PriceTicker>> getWatchlist(List<({String symbol, AssetCategory category})> items);
}

class MarketDataRepository implements IMarketDataRepository {
  final YahooFinanceClient _yahooClient;
  final TwelveDataClient _twelveDataClient;

  // In-memory cache for tickers and candles
  final Map<String, PriceTicker> _tickerCache = {};
  final Map<String, List<Candle>> _candleCache = {};

  MarketDataRepository({
    YahooFinanceClient? yahooClient,
    TwelveDataClient? twelveDataClient,
  })  : _yahooClient = yahooClient ?? YahooFinanceClient(),
        _twelveDataClient = twelveDataClient ?? TwelveDataClient();

  void setTwelveDataApiKey(String? key) {
    _twelveDataClient.apiKey = key;
  }

  @override
  Future<PriceTicker> getQuote(String symbol, AssetCategory category) async {
    final cacheKey = '$symbol:${category.name}';

    // Try TwelveData if API Key available
    if (_twelveDataClient.hasApiKey) {
      try {
        final ticker = await _twelveDataClient.getQuote(symbol, category);
        _tickerCache[cacheKey] = ticker;
        return ticker;
      } catch (_) {
        // Fallback to Yahoo Finance on error
      }
    }

    // Fallback / Primary default: Yahoo Finance
    try {
      final ticker = await _yahooClient.getQuote(symbol, category);
      _tickerCache[cacheKey] = ticker;
      return ticker;
    } catch (e) {
      // Return cached ticker if available on network failure
      if (_tickerCache.containsKey(cacheKey)) {
        return _tickerCache[cacheKey]!;
      }
      rethrow;
    }
  }

  @override
  Future<List<Candle>> getCandles(
    String symbol,
    AssetCategory category, {
    String interval = '1d',
    String range = '1mo',
  }) async {
    final cacheKey = '$symbol:$interval:$range';

    if (_twelveDataClient.hasApiKey) {
      try {
        final candles = await _twelveDataClient.getCandles(symbol, category);
        _candleCache[cacheKey] = candles;
        return candles;
      } catch (_) {
        // Fallback on error
      }
    }

    try {
      final candles = await _yahooClient.getCandles(
        symbol,
        category,
        interval: interval,
        range: range,
      );
      _candleCache[cacheKey] = candles;
      return candles;
    } catch (e) {
      if (_candleCache.containsKey(cacheKey)) {
        return _candleCache[cacheKey]!;
      }
      rethrow;
    }
  }

  @override
  Future<List<PriceTicker>> getWatchlist(
      List<({String symbol, AssetCategory category})> items) async {
    final results = <PriceTicker>[];
    for (final item in items) {
      try {
        final ticker = await getQuote(item.symbol, item.category);
        results.add(ticker);
      } catch (e) {
        // Return dummy / cached placeholder if failed
        results.add(PriceTicker(
          symbol: item.symbol,
          name: item.symbol,
          price: 0.0,
          change: 0.0,
          changePercent: 0.0,
          high24h: 0.0,
          low24h: 0.0,
          volume: 0.0,
          timestamp: DateTime.now(),
          category: item.category,
          dataSource: 'Offline/Failed',
        ));
      }
    }
    return results;
  }
}
