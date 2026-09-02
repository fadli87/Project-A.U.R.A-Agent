import 'dart:convert';
import 'package:decimal/decimal.dart';
import '../data/sources/unified/market_data_repository.dart';
import '../data/models/price_ticker.dart';
import '../domain/indicators.dart';
import '../domain/position_sizer.dart';

/// Trading Tools wrapper to expose functions to AURA Core Agent tool calling system.
class TradingTools {
  final MarketDataRepository _repository;

  TradingTools({MarketDataRepository? repository})
      : _repository = repository ?? MarketDataRepository();

  /// Gets current price for a symbol.
  Future<String> getCurrentPrice(Map<String, dynamic> args) async {
    final symbol = args['symbol']?.toString() ?? 'EURUSD';
    final catString = args['category']?.toString() ?? 'forex';

    final category = AssetCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == catString.toLowerCase(),
      orElse: () => AssetCategory.forex,
    );

    try {
      final ticker = await _repository.getQuote(symbol, category);
      return jsonEncode({
        'status': 'success',
        'symbol': ticker.symbol,
        'price': ticker.price,
        'change': ticker.change,
        'changePercent': '${ticker.changePercent.toStringAsFixed(2)}%',
        'high24h': ticker.high24h,
        'low24h': ticker.low24h,
        'dataSource': ticker.dataSource,
      });
    } catch (e) {
      return jsonEncode({'status': 'error', 'message': e.toString()});
    }
  }

  /// Calculates technical indicators (RSI, MACD, EMA) for a symbol.
  Future<String> getTechnicalIndicators(Map<String, dynamic> args) async {
    final symbol = args['symbol']?.toString() ?? 'EURUSD';
    final catString = args['category']?.toString() ?? 'forex';
    final timeframe = args['timeframe']?.toString() ?? '1d';

    final category = AssetCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == catString.toLowerCase(),
      orElse: () => AssetCategory.forex,
    );

    try {
      final candles = await _repository.getCandles(symbol, category, interval: timeframe);
      if (candles.isEmpty) {
        return jsonEncode({'status': 'error', 'message': 'No candle data available'});
      }

      final rsi = TechnicalIndicators.calculateRSI(candles);
      final ema20 = TechnicalIndicators.calculateEMA(candles, 20);
      final ema50 = TechnicalIndicators.calculateEMA(candles, 50);
      final macd = TechnicalIndicators.calculateMACD(candles);
      final atr = TechnicalIndicators.calculateATR(candles);
      final ichimoku = TechnicalIndicators.calculateIchimoku(candles);

      final lastIdx = candles.length - 1;
      final currentPrice = candles[lastIdx].close;

      return jsonEncode({
        'status': 'success',
        'symbol': symbol,
        'price': currentPrice,
        'timeframe': timeframe,
        'indicators': {
          'rsi_14': rsi[lastIdx]?.toStringAsFixed(2) ?? 'N/A',
          'ema_20': ema20[lastIdx]?.toStringAsFixed(4) ?? 'N/A',
          'ema_50': ema50[lastIdx]?.toStringAsFixed(4) ?? 'N/A',
          'macd_line': macd.macdLine[lastIdx]?.toStringAsFixed(4) ?? 'N/A',
          'macd_signal': macd.signalLine[lastIdx]?.toStringAsFixed(4) ?? 'N/A',
          'macd_histogram': macd.histogram[lastIdx]?.toStringAsFixed(4) ?? 'N/A',
          'atr_14': atr[lastIdx]?.toStringAsFixed(4) ?? 'N/A',
          'ichimoku_tenkan': ichimoku.tenkanSen[lastIdx]?.toStringAsFixed(4) ?? 'N/A',
          'ichimoku_kijun': ichimoku.kijunSen[lastIdx]?.toStringAsFixed(4) ?? 'N/A',
          'ichimoku_senkou_a': ichimoku.senkouSpanA[lastIdx]?.toStringAsFixed(4) ?? 'N/A',
          'ichimoku_senkou_b': ichimoku.senkouSpanB[lastIdx]?.toStringAsFixed(4) ?? 'N/A',
        }
      });
    } catch (e) {
      return jsonEncode({'status': 'error', 'message': e.toString()});
    }
  }

  /// Calculates risk-managed position size.
  Future<String> calculatePositionSize(Map<String, dynamic> args) async {
    final equity = Decimal.parse((args['equity'] ?? 10000).toString());
    final riskPct = Decimal.parse((args['riskPct'] ?? 2.0).toString());
    final entryPrice = Decimal.parse((args['entryPrice'] ?? 0).toString());
    final stopLoss = Decimal.parse((args['stopLoss'] ?? 0).toString());
    final takeProfit = args['takeProfit'] != null
        ? Decimal.parse(args['takeProfit'].toString())
        : null;
    final assetType = args['assetType']?.toString().toLowerCase() ?? 'forex';

    if (entryPrice <= Decimal.zero || stopLoss <= Decimal.zero) {
      return jsonEncode({
        'status': 'error',
        'message': 'Please provide valid positive entryPrice and stopLoss.'
      });
    }

    try {
      PositionSizeResult result;
      if (assetType == 'idx' || assetType == 'stock') {
        result = PositionSizer.calculateIDXStock(
          equity: equity,
          riskPct: riskPct,
          entryPrice: entryPrice,
          stopLoss: stopLoss,
          takeProfit: takeProfit,
        );
      } else {
        final isGold = assetType == 'gold' || args['symbol']?.toString().contains('XAU') == true;
        result = PositionSizer.calculateForexGold(
          equity: equity,
          riskPct: riskPct,
          entryPrice: entryPrice,
          stopLoss: stopLoss,
          takeProfit: takeProfit,
          isGold: isGold,
        );
      }

      return jsonEncode({
        'status': 'success',
        'riskAmount': result.riskAmount.toString(),
        'recommendedLots': result.recommendedLots.toString(),
        'pipsOrPriceRisk': result.stopLossDistance.toString(),
        'maxLossAmount': result.maxLoss.toString(),
        'capitalRequired': result.totalCapitalRequired.toString(),
        'riskRewardRatio': result.riskRewardRatio != Decimal.zero
            ? '1:${result.riskRewardRatio.toStringAsFixed(2)}'
            : 'N/A',
        'summaryNote': result.notes,
      });
    } catch (e) {
      return jsonEncode({'status': 'error', 'message': e.toString()});
    }
  }

  /// Returns current MT5 account summary & open positions context for AI tool calling.
  Future<String> getAccountContext(Map<String, dynamic> args) async {
    try {
      final account = await _repository.getMt5Account();
      final positions = await _repository.getMt5Positions();
      return jsonEncode({
        'status': 'success',
        'account': account != null
            ? {
                'login': account.login,
                'balance': account.balance.toString(),
                'equity': account.equity.toString(),
                'freeMargin': account.freeMargin.toString(),
                'currency': account.currency,
              }
            : 'Bridge MT5 Offline',
        'openPositions': positions
            .map((p) => {
                  'ticket': p.ticket,
                  'symbol': p.symbol,
                  'type': p.type,
                  'volume': p.volume.toString(),
                  'openPrice': p.openPrice.toString(),
                  'sl': p.sl.toString(),
                  'tp': p.tp.toString(),
                  'profit': p.profit.toString(),
                })
            .toList(),
      });
    } catch (e) {
      return jsonEncode({'status': 'error', 'message': e.toString()});
    }
  }

  /// Dispatch tool execution by tool name and arguments.
  Future<String> execute(String toolName, Map<String, dynamic> args) async {
    switch (toolName) {
      case 'getCurrentPrice':
        return getCurrentPrice(args);
      case 'getTechnicalIndicators':
        return getTechnicalIndicators(args);
      case 'calculatePositionSize':
        return calculatePositionSize(args);
      case 'getAccountContext':
        return getAccountContext(args);
      default:
        return jsonEncode({'status': 'error', 'message': 'Unknown tool: $toolName'});
    }
  }

  /// Parses and executes simplified non-JSON tool call format:
  /// TOOL: calculatePositionSize
  /// equity: 10000
  /// riskPct: 2.0
  Future<String> parseAndExecute(String raw) async {
    final lines = raw.split('\n');
    final toolLine = lines.firstWhere((l) => l.trim().startsWith('TOOL:'), orElse: () => '');
    if (toolLine.isEmpty) {
      return jsonEncode({'status': 'error', 'message': 'Format tool call tidak valid'});
    }

    final toolName = toolLine.replaceFirst('TOOL:', '').trim();
    final params = <String, dynamic>{};

    for (final line in lines) {
      if (line.trim().startsWith('TOOL:')) continue;
      if (line.contains(':')) {
        final parts = line.split(':');
        final key = parts[0].trim();
        final val = parts.sublist(1).join(':').trim();

        if (val.toLowerCase() == 'true') {
          params[key] = true;
        } else if (val.toLowerCase() == 'false') {
          params[key] = false;
        } else if (double.tryParse(val) != null) {
          params[key] = double.parse(val);
        } else {
          params[key] = val;
        }
      }
    }

    return execute(toolName, params);
  }
}

