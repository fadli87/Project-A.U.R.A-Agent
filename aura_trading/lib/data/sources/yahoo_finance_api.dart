import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/candle.dart';
import '../models/price_ticker.dart';

/// Yahoo Finance API Client for Forex, Gold, and IDX Stocks (No API key needed).
class YahooFinanceClient {
  final http.Client _client;

  YahooFinanceClient({http.Client? client}) : _client = client ?? http.Client();

  /// Converts standard symbols to Yahoo Finance symbols.
  /// E.g. 'EUR/USD' -> 'EURUSD=X', 'XAU/USD' -> 'GC=F', 'BBCA' -> 'BBCA.JK'
  String _mapSymbol(String symbol, AssetCategory category) {
    final clean = symbol.trim().toUpperCase();
    if (category == AssetCategory.forex) {
      if (clean.contains('/')) {
        return '${clean.replaceAll('/', '')}=X';
      }
      if (!clean.endsWith('=X')) return '$clean=X';
      return clean;
    } else if (category == AssetCategory.gold) {
      if (clean == 'XAU/USD' || clean == 'XAUUSD' || clean == 'GOLD') return 'GC=F';
      return clean;
    } else if (category == AssetCategory.idxStock) {
      if (!clean.endsWith('.JK')) return '$clean.JK';
      return clean;
    }
    return clean;
  }

  /// Fetches real-time price quote for a symbol.
  Future<PriceTicker> getQuote(String symbol, AssetCategory category) async {
    final yahooSymbol = _mapSymbol(symbol, category);
    final url = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol?interval=1m&range=1d');

    try {
      final response = await _client.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['chart']['result'][0];
        final meta = result['meta'];

        final regularMarketPrice = (meta['regularMarketPrice'] as num).toDouble();
        final previousClose = (meta['chartPreviousClose'] as num?)?.toDouble() ?? regularMarketPrice;
        final change = regularMarketPrice - previousClose;
        final changePercent = previousClose != 0 ? (change / previousClose) * 100 : 0.0;

        return PriceTicker(
          symbol: symbol,
          name: meta['shortName'] as String? ?? meta['symbol'] as String? ?? symbol,
          price: regularMarketPrice,
          change: change,
          changePercent: changePercent,
          high24h: (meta['regularMarketDayHigh'] as num?)?.toDouble() ?? regularMarketPrice,
          low24h: (meta['regularMarketDayLow'] as num?)?.toDouble() ?? regularMarketPrice,
          volume: (meta['regularMarketVolume'] as num?)?.toDouble() ?? 0.0,
          timestamp: DateTime.now(),
          category: category,
          dataSource: 'YahooFinance',
        );
      } else {
        throw Exception('Failed to fetch Yahoo quote (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('YahooFinance quote error for $symbol: $e');
    }
  }

  /// Fetches historical candlestick (OHLCV) bars.
  /// Interval options: '1m', '5m', '15m', '1h', '1d'
  Future<List<Candle>> getCandles(
    String symbol,
    AssetCategory category, {
    String interval = '1d',
    String range = '1mo',
  }) async {
    final yahooSymbol = _mapSymbol(symbol, category);
    final url = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol?interval=$interval&range=$range');

    try {
      final response = await _client.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['chart']['result'][0];
        final timestamps = (result['timestamp'] as List?)?.cast<int>() ?? [];
        final quote = result['indicators']['quote'][0];

        final opens = (quote['open'] as List?)?.cast<num?>() ?? [];
        final highs = (quote['high'] as List?)?.cast<num?>() ?? [];
        final lows = (quote['low'] as List?)?.cast<num?>() ?? [];
        final closes = (quote['close'] as List?)?.cast<num?>() ?? [];
        final volumes = (quote['volume'] as List?)?.cast<num?>() ?? [];

        final candles = <Candle>[];
        for (int i = 0; i < timestamps.length; i++) {
          if (opens[i] == null ||
              highs[i] == null ||
              lows[i] == null ||
              closes[i] == null) {
            continue;
          }
          candles.add(Candle(
            timestamp: DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000),
            open: opens[i]!.toDouble(),
            high: highs[i]!.toDouble(),
            low: lows[i]!.toDouble(),
            close: closes[i]!.toDouble(),
            volume: (volumes.length > i && volumes[i] != null)
                ? volumes[i]!.toDouble()
                : 0.0,
          ));
        }
        return candles;
      } else {
        throw Exception('Failed to fetch candles (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('YahooFinance candle error for $symbol: $e');
    }
  }
}
