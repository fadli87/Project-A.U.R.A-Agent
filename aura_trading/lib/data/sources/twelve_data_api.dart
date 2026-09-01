import 'dart:convert';
import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;
import '../models/candle.dart';
import '../models/price_ticker.dart';

/// TwelveData REST API Client for Forex, Gold, and IDX Stocks (Requires API key).
class TwelveDataClient {
  final http.Client _client;
  String? apiKey;

  TwelveDataClient({this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  bool get hasApiKey => apiKey != null && apiKey!.trim().isNotEmpty;

  /// Fetches real-time price quote from TwelveData API.
  Future<PriceTicker> getQuote(String symbol, AssetCategory category) async {
    if (!hasApiKey) {
      throw Exception('TwelveData API key is missing.');
    }

    final url = Uri.parse(
        'https://api.twelvedata.com/quote?symbol=$symbol&apikey=$apiKey');

    final response = await _client.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'error') {
        throw Exception(data['message'] ?? 'TwelveData error');
      }

      final price = Decimal.parse(data['close'].toString());
      final change = Decimal.parse(data['change'].toString());
      final changePct = double.parse(data['percent_change'].toString());
      final high = Decimal.parse(data['high'].toString());
      final low = Decimal.parse(data['low'].toString());
      final volume = double.tryParse(data['volume']?.toString() ?? '0') ?? 0.0;

      return PriceTicker(
        symbol: symbol,
        name: data['name'] as String? ?? symbol,
        price: price,
        change: change,
        changePercent: changePct,
        high24h: high,
        low24h: low,
        volume: volume,
        timestamp: DateTime.now(),
        category: category,
        dataSource: 'TwelveData',
      );
    } else {
      throw Exception('TwelveData API request failed (${response.statusCode})');
    }
  }

  /// Fetches time series OHLC candles from TwelveData API.
  Future<List<Candle>> getCandles(
    String symbol,
    AssetCategory category, {
    String interval = '1day',
    int outputsize = 30,
  }) async {
    if (!hasApiKey) {
      throw Exception('TwelveData API key is missing.');
    }

    final url = Uri.parse(
        'https://api.twelvedata.com/time_series?symbol=$symbol&interval=$interval&outputsize=$outputsize&apikey=$apiKey');

    final response = await _client.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'error') {
        throw Exception(data['message'] ?? 'TwelveData time_series error');
      }

      final values = (data['values'] as List?) ?? [];
      final candles = <Candle>[];

      for (var v in values) {
        candles.add(Candle(
          timestamp: DateTime.parse(v['datetime'].toString()),
          open: Decimal.parse(v['open'].toString()),
          high: Decimal.parse(v['high'].toString()),
          low: Decimal.parse(v['low'].toString()),
          close: Decimal.parse(v['close'].toString()),
          volume: double.tryParse(v['volume']?.toString() ?? '0') ?? 0.0,
        ));
      }
      return candles.reversed.toList(); // Return in chronological order
    } else {
      throw Exception('TwelveData time_series request failed');
    }
  }
}
