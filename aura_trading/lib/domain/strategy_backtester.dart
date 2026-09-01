import 'dart:math';
import 'package:decimal/decimal.dart';
import '../data/models/backtest_result.dart';
import '../data/models/candle.dart';
import '../data/models/price_ticker.dart';
import '../data/models/strategy.dart';
import 'indicators.dart';
import 'position_sizer.dart';

/// Engine for backtesting rule-based trading strategies on historical OHLCV candles.
class StrategyBacktester {
  static final Decimal _d100 = Decimal.fromInt(100);
  static final Decimal _d100000 = Decimal.fromInt(100000);

  /// Executes backtest simulation on [candles] with given [strategy].
  static BacktestResult runBacktest({
    required List<Candle> candles,
    required TradingStrategy strategy,
    required Decimal initialBalance,
    required AssetCategory category,
    String symbol = 'ASSET',
  }) {
    if (candles.isEmpty) {
      return BacktestResult(
        initialBalance: initialBalance,
        finalBalance: initialBalance,
        totalTrades: 0,
        winningTrades: 0,
        losingTrades: 0,
        winRate: 0.0,
        profitFactor: 0.0,
        maxDrawdownPct: 0.0,
        maxDrawdownAmount: Decimal.zero,
        netProfit: Decimal.zero,
        netProfitPct: 0.0,
        trades: const [],
        equityCurve: const [],
      );
    }

    // 1. Calculate technical indicators
    final emaFast = TechnicalIndicators.calculateEMA(candles, strategy.fastPeriod);
    final emaSlow = TechnicalIndicators.calculateEMA(candles, strategy.slowPeriod);
    final rsi = TechnicalIndicators.calculateRSI(candles, period: strategy.rsiPeriod);

    Decimal currentBalance = initialBalance;
    Decimal peakEquity = initialBalance;
    Decimal maxDrawdownAmt = Decimal.zero;
    double maxDrawdownPct = 0.0;

    final trades = <BacktestTrade>[];
    final equityCurve = <EquityPoint>[];

    // Active position state
    bool hasPosition = false;
    String posType = 'BUY';
    Decimal posEntryPrice = Decimal.zero;
    Decimal posLots = Decimal.zero;
    DateTime posEntryTime = candles.first.timestamp;
    Decimal? posSL;
    Decimal? posTP;

    // Minimum bar index to start checking signals
    final startIdx = strategy.type == StrategyType.emaCrossover
        ? max(strategy.fastPeriod, strategy.slowPeriod)
        : strategy.rsiPeriod + 1;

    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];

      // A. Evaluate open position against SL/TP on current candle
      if (hasPosition) {
        bool closed = false;
        Decimal exitPrice = candle.close;
        String exitReason = 'SIGNAL';

        final sl = posSL;
        final tp = posTP;

        if (posType == 'BUY') {
          if (sl != null && candle.low <= sl) {
            exitPrice = sl;
            exitReason = 'SL';
            closed = true;
          } else if (tp != null && candle.high >= tp) {
            exitPrice = tp;
            exitReason = 'TP';
            closed = true;
          }
        } else {
          // SELL position
          if (sl != null && candle.high >= sl) {
            exitPrice = sl;
            exitReason = 'SL';
            closed = true;
          } else if (tp != null && candle.low <= tp) {
            exitPrice = tp;
            exitReason = 'TP';
            closed = true;
          }
        }

        if (closed) {
          final pnl = _calculatePnL(posType, posEntryPrice, exitPrice, posLots, category);
          final pnlPct = posEntryPrice != Decimal.zero
              ? (pnl.toDouble() / (posEntryPrice * posLots * _getLotMultiplier(category)).toDouble()) * 100
              : 0.0;

          trades.add(BacktestTrade(
            id: 'bt_${trades.length + 1}',
            symbol: symbol,
            type: posType,
            entryPrice: posEntryPrice,
            exitPrice: exitPrice,
            lots: posLots,
            pnl: pnl,
            pnlPercent: pnlPct,
            entryTime: posEntryTime,
            exitTime: candle.timestamp,
            exitReason: exitReason,
          ));

          currentBalance += pnl;
          hasPosition = false;
        }
      }

      // B. Evaluate Strategy Signals for Entry/Exit if past warm-up index
      if (i >= startIdx) {
        if (strategy.type == StrategyType.emaCrossover) {
          final fPrev = emaFast[i - 1];
          final fCurr = emaFast[i];
          final sPrev = emaSlow[i - 1];
          final sCurr = emaSlow[i];

          if (fPrev != null && fCurr != null && sPrev != null && sCurr != null) {
            final bullishCross = (fPrev <= sPrev) && (fCurr > sCurr);
            final bearishCross = (fPrev >= sPrev) && (fCurr < sCurr);

            if (bullishCross) {
              if (hasPosition && posType == 'SELL') {
                // Close SELL position
                final pnl = _calculatePnL('SELL', posEntryPrice, candle.close, posLots, category);
                trades.add(BacktestTrade(
                  id: 'bt_${trades.length + 1}',
                  symbol: symbol,
                  type: 'SELL',
                  entryPrice: posEntryPrice,
                  exitPrice: candle.close,
                  lots: posLots,
                  pnl: pnl,
                  pnlPercent: (pnl.toDouble() / (posEntryPrice * posLots * _getLotMultiplier(category)).toDouble()) * 100,
                  entryTime: posEntryTime,
                  exitTime: candle.timestamp,
                  exitReason: 'SIGNAL',
                ));
                currentBalance += pnl;
                hasPosition = false;
              }

              if (!hasPosition) {
                // Open BUY position
                posType = 'BUY';
                posEntryPrice = candle.close;
                posEntryTime = candle.timestamp;
                posLots = _calculateLots(currentBalance, strategy.riskPctPerTrade, candle.close, category);
                posSL = strategy.stopLossPips != null
                    ? candle.close - _pipsToPrice(strategy.stopLossPips!, category)
                    : null;
                posTP = strategy.takeProfitPips != null
                    ? candle.close + _pipsToPrice(strategy.takeProfitPips!, category)
                    : null;
                hasPosition = true;
              }
            } else if (bearishCross) {
              if (hasPosition && posType == 'BUY') {
                // Close BUY position
                final pnl = _calculatePnL('BUY', posEntryPrice, candle.close, posLots, category);
                trades.add(BacktestTrade(
                  id: 'bt_${trades.length + 1}',
                  symbol: symbol,
                  type: 'BUY',
                  entryPrice: posEntryPrice,
                  exitPrice: candle.close,
                  lots: posLots,
                  pnl: pnl,
                  pnlPercent: (pnl.toDouble() / (posEntryPrice * posLots * _getLotMultiplier(category)).toDouble()) * 100,
                  entryTime: posEntryTime,
                  exitTime: candle.timestamp,
                  exitReason: 'SIGNAL',
                ));
                currentBalance += pnl;
                hasPosition = false;
              }

              if (!hasPosition) {
                // Open SELL position
                posType = 'SELL';
                posEntryPrice = candle.close;
                posEntryTime = candle.timestamp;
                posLots = _calculateLots(currentBalance, strategy.riskPctPerTrade, candle.close, category);
                posSL = strategy.stopLossPips != null
                    ? candle.close + _pipsToPrice(strategy.stopLossPips!, category)
                    : null;
                posTP = strategy.takeProfitPips != null
                    ? candle.close - _pipsToPrice(strategy.takeProfitPips!, category)
                    : null;
                hasPosition = true;
              }
            }
          }
        } else if (strategy.type == StrategyType.rsiReversion) {
          final rsiVal = rsi[i];
          if (rsiVal != null) {
            if (rsiVal < strategy.rsiOversold) {
              if (hasPosition && posType == 'SELL') {
                final pnl = _calculatePnL('SELL', posEntryPrice, candle.close, posLots, category);
                trades.add(BacktestTrade(
                  id: 'bt_${trades.length + 1}',
                  symbol: symbol,
                  type: 'SELL',
                  entryPrice: posEntryPrice,
                  exitPrice: candle.close,
                  lots: posLots,
                  pnl: pnl,
                  pnlPercent: (pnl.toDouble() / (posEntryPrice * posLots * _getLotMultiplier(category)).toDouble()) * 100,
                  entryTime: posEntryTime,
                  exitTime: candle.timestamp,
                  exitReason: 'SIGNAL',
                ));
                currentBalance += pnl;
                hasPosition = false;
              }

              if (!hasPosition) {
                posType = 'BUY';
                posEntryPrice = candle.close;
                posEntryTime = candle.timestamp;
                posLots = _calculateLots(currentBalance, strategy.riskPctPerTrade, candle.close, category);
                posSL = strategy.stopLossPips != null
                    ? candle.close - _pipsToPrice(strategy.stopLossPips!, category)
                    : null;
                posTP = strategy.takeProfitPips != null
                    ? candle.close + _pipsToPrice(strategy.takeProfitPips!, category)
                    : null;
                hasPosition = true;
              }
            } else if (rsiVal > strategy.rsiOverbought) {
              if (hasPosition && posType == 'BUY') {
                final pnl = _calculatePnL('BUY', posEntryPrice, candle.close, posLots, category);
                trades.add(BacktestTrade(
                  id: 'bt_${trades.length + 1}',
                  symbol: symbol,
                  type: 'BUY',
                  entryPrice: posEntryPrice,
                  exitPrice: candle.close,
                  lots: posLots,
                  pnl: pnl,
                  pnlPercent: (pnl.toDouble() / (posEntryPrice * posLots * _getLotMultiplier(category)).toDouble()) * 100,
                  entryTime: posEntryTime,
                  exitTime: candle.timestamp,
                  exitReason: 'SIGNAL',
                ));
                currentBalance += pnl;
                hasPosition = false;
              }

              if (!hasPosition) {
                posType = 'SELL';
                posEntryPrice = candle.close;
                posEntryTime = candle.timestamp;
                posLots = _calculateLots(currentBalance, strategy.riskPctPerTrade, candle.close, category);
                posSL = strategy.stopLossPips != null
                    ? candle.close + _pipsToPrice(strategy.stopLossPips!, category)
                    : null;
                posTP = strategy.takeProfitPips != null
                    ? candle.close - _pipsToPrice(strategy.takeProfitPips!, category)
                    : null;
                hasPosition = true;
              }
            }
          }
        }
      }

      // C. Calculate current equity and equity curve snapshot
      Decimal floatingPnL = Decimal.zero;
      if (hasPosition) {
        floatingPnL = _calculatePnL(posType, posEntryPrice, candle.close, posLots, category);
      }
      final currentEquity = currentBalance + floatingPnL;

      if (currentEquity > peakEquity) {
        peakEquity = currentEquity;
      }

      final ddAmt = peakEquity - currentEquity;
      if (ddAmt > maxDrawdownAmt) {
        maxDrawdownAmt = ddAmt;
      }

      final ddPct = peakEquity != Decimal.zero
          ? (ddAmt.toDouble() / peakEquity.toDouble()) * 100
          : 0.0;
      if (ddPct > maxDrawdownPct) {
        maxDrawdownPct = ddPct;
      }

      equityCurve.add(EquityPoint(
        timestamp: candle.timestamp,
        equity: currentEquity,
        drawdownPct: ddPct,
      ));
    }

    // Close remaining open position at end of backtest data
    if (hasPosition) {
      final lastCandle = candles.last;
      final pnl = _calculatePnL(posType, posEntryPrice, lastCandle.close, posLots, category);
      trades.add(BacktestTrade(
        id: 'bt_${trades.length + 1}',
        symbol: symbol,
        type: posType,
        entryPrice: posEntryPrice,
        exitPrice: lastCandle.close,
        lots: posLots,
        pnl: pnl,
        pnlPercent: (pnl.toDouble() / (posEntryPrice * posLots * _getLotMultiplier(category)).toDouble()) * 100,
        entryTime: posEntryTime,
        exitTime: lastCandle.timestamp,
        exitReason: 'END_OF_DATA',
      ));
      currentBalance += pnl;
    }

    // Summary calculation
    final finalBalance = currentBalance;
    final netProfit = finalBalance - initialBalance;
    final netProfitPct = initialBalance != Decimal.zero
        ? (netProfit.toDouble() / initialBalance.toDouble()) * 100
        : 0.0;

    final totalTrades = trades.length;
    final winningTrades = trades.where((t) => t.isProfit).length;
    final losingTrades = trades.where((t) => !t.isProfit).length;
    final winRate = totalTrades > 0 ? (winningTrades / totalTrades) * 100 : 0.0;

    Decimal grossProfit = Decimal.zero;
    Decimal grossLoss = Decimal.zero;
    for (var t in trades) {
      if (t.isProfit) {
        grossProfit += t.pnl;
      } else {
        grossLoss += t.pnl.abs();
      }
    }

    double profitFactor = 0.0;
    if (grossLoss > Decimal.zero) {
      profitFactor = grossProfit.toDouble() / grossLoss.toDouble();
    } else if (grossProfit > Decimal.zero) {
      profitFactor = 999.0;
    }

    return BacktestResult(
      initialBalance: initialBalance,
      finalBalance: finalBalance,
      totalTrades: totalTrades,
      winningTrades: winningTrades,
      losingTrades: losingTrades,
      winRate: winRate,
      profitFactor: profitFactor,
      maxDrawdownPct: maxDrawdownPct,
      maxDrawdownAmount: maxDrawdownAmt,
      netProfit: netProfit,
      netProfitPct: netProfitPct,
      trades: trades,
      equityCurve: equityCurve,
    );
  }

  static Decimal _calculatePnL(
    String type,
    Decimal entryPrice,
    Decimal exitPrice,
    Decimal lots,
    AssetCategory category,
  ) {
    final isBuy = type.toUpperCase() == 'BUY';
    final priceDiff = isBuy ? (exitPrice - entryPrice) : (entryPrice - exitPrice);
    final multiplier = _getLotMultiplier(category);
    return priceDiff * lots * multiplier;
  }

  static Decimal _getLotMultiplier(AssetCategory category) {
    switch (category) {
      case AssetCategory.forex:
        return _d100000;
      case AssetCategory.gold:
        return Decimal.fromInt(100);
      case AssetCategory.idxStock:
        return Decimal.fromInt(100);
    }
  }

  static Decimal _calculateLots(
    Decimal balance,
    Decimal riskPct,
    Decimal price,
    AssetCategory category,
  ) {
    if (category == AssetCategory.idxStock) {
      // 1 Lot = 100 shares. Risk 2% of capital
      final riskAmount = (balance * riskPct / _d100).toD(2);
      final shares = (riskAmount / price).toD(0).floor();
      final lots = (shares / Decimal.fromInt(100)).toD(0).floor();
      return lots < Decimal.one ? Decimal.one : lots;
    } else if (category == AssetCategory.gold) {
      // 0.1 lot default for gold if fixed risk
      return Decimal.parse('0.1');
    } else {
      // 0.01 micro lot default for forex
      return Decimal.parse('0.01');
    }
  }

  static Decimal _pipsToPrice(Decimal pips, AssetCategory category) {
    if (category == AssetCategory.gold) {
      return pips * Decimal.parse('0.1');
    } else if (category == AssetCategory.forex) {
      return pips * Decimal.parse('0.0001');
    } else {
      return pips; // IDR per share
    }
  }
}
