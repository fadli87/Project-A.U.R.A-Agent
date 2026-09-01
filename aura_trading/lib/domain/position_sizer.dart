import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

/// Extension helper: converts division result (Rational) to Decimal.
extension RationalDecimalExt on Rational {
  Decimal toD([int scale = 8]) => toDecimal(scaleOnInfinitePrecision: scale);
}

/// Holds the result of a position size calculation.
/// All monetary fields use [Decimal] for financial precision (Prinsip 1).
class PositionSizeResult {
  final Decimal riskAmount;
  final Decimal calculatedLots;
  final Decimal recommendedLots;
  final Decimal stopLossDistance; // pips at risk
  final Decimal maxLoss;
  final Decimal totalCapitalRequired;
  final Decimal riskRewardRatio;
  final String notes;

  const PositionSizeResult({
    required this.riskAmount,
    required this.calculatedLots,
    required this.recommendedLots,
    required this.stopLossDistance,
    required this.maxLoss,
    required this.totalCapitalRequired,
    required this.riskRewardRatio,
    required this.notes,
  });
}

class PositionSizer {
  static final Decimal _d100 = Decimal.fromInt(100);
  static final Decimal _d10 = Decimal.fromInt(10);
  static final Decimal _d100000 = Decimal.fromInt(100000);

  /// Position size calculator for Forex and Gold (XAU/USD).
  static PositionSizeResult calculateForexGold({
    required Decimal equity,
    required Decimal riskPct,
    required Decimal entryPrice,
    required Decimal stopLoss,
    Decimal? takeProfit,
    bool isGold = false,
  }) {
    // equity * riskPct is Decimal; / _d100 gives Rational → convert to Decimal
    final riskAmount = (equity * riskPct / _d100).toD(2);
    final priceDiff = (entryPrice - stopLoss).abs();

    if (priceDiff == Decimal.zero) {
      throw ArgumentError('Entry price and Stop Loss cannot be equal.');
    }

    // 1 pip: Gold = 0.1 price units, Forex = 0.0001
    final pipSize = isGold ? Decimal.parse('0.1') : Decimal.parse('0.0001');
    final pipValuePerStandardLot = _d10;

    // priceDiff / pipSize → Rational → toDecimal
    final pipsAtRisk = (priceDiff / pipSize).toD(8);
    // pipsAtRisk * pipValuePerStandardLot is Decimal; / that → Rational
    final calculatedLots =
        (riskAmount / (pipsAtRisk * pipValuePerStandardLot)).toD(8);

    // Round down to 0.01 lot precision
    final scale2 = Decimal.parse('0.01');
    // calculatedLots / scale2 → Rational; floor gives Rational; * scale2 → Rational → toD
    final recommendedLotsRaw =
        ((calculatedLots / scale2).toD(2).floor()) * scale2;
    final recommendedLots = recommendedLotsRaw < scale2 ? scale2 : recommendedLotsRaw;

    final maxLoss = pipsAtRisk * pipValuePerStandardLot * recommendedLots;
    // leverage 1:100
    final capitalRequired =
        (recommendedLots * _d100000 * entryPrice / _d100).toD(2);

    Decimal rrRatio = Decimal.zero;
    if (takeProfit != null && takeProfit != entryPrice) {
      final tpDistance = (takeProfit - entryPrice).abs();
      rrRatio = (tpDistance / priceDiff).toD(4);
    }

    final pipsStr = pipsAtRisk.toStringAsFixed(0);
    final lotsStr = recommendedLots.toStringAsFixed(2);
    final maxLossStr = maxLoss.toStringAsFixed(2);

    return PositionSizeResult(
      riskAmount: riskAmount,
      calculatedLots: calculatedLots,
      recommendedLots: recommendedLots,
      stopLossDistance: pipsAtRisk,
      maxLoss: maxLoss,
      totalCapitalRequired: capitalRequired,
      riskRewardRatio: rrRatio,
      notes: isGold
          ? 'XAU/USD: $pipsStr pips at risk ($lotsStr Lot = ~\$$maxLossStr risk)'
          : 'Forex: $pipsStr pips at risk ($lotsStr Lot = ~\$$maxLossStr risk)',
    );
  }

  /// Position size calculator for Saham IDX (Indonesian Stocks).
  static PositionSizeResult calculateIDXStock({
    required Decimal equity,
    required Decimal riskPct,
    required Decimal entryPrice,
    required Decimal stopLoss,
    Decimal? takeProfit,
  }) {
    final riskAmount = (equity * riskPct / _d100).toD(2);
    final riskPerShare = (entryPrice - stopLoss).abs();

    if (riskPerShare == Decimal.zero) {
      throw ArgumentError('Entry price and Stop Loss cannot be equal.');
    }

    final totalSharesRaw = (riskAmount / riskPerShare).toD(4);
    // 1 Lot Saham IDX = 100 lembar saham
    final calculatedLots = (totalSharesRaw / _d100).toD(4);

    // Round down to whole lot; minimum 1 lot
    final recommendedLots =
        calculatedLots.floor() < Decimal.one ? Decimal.one : calculatedLots.floor();

    final actualShares = recommendedLots * _d100;
    final totalCapitalRequired = actualShares * entryPrice;
    final maxLoss = actualShares * riskPerShare;

    Decimal rrRatio = Decimal.zero;
    if (takeProfit != null && takeProfit != entryPrice) {
      final rewardPerShare = (takeProfit - entryPrice).abs();
      rrRatio = (rewardPerShare / riskPerShare).toD(4);
    }

    final lotsStr = recommendedLots.toStringAsFixed(0);
    final sharesStr = actualShares.toStringAsFixed(0);
    final capitalStr = totalCapitalRequired.toStringAsFixed(0);
    final maxLossStr = maxLoss.toStringAsFixed(0);

    return PositionSizeResult(
      riskAmount: riskAmount,
      calculatedLots: calculatedLots,
      recommendedLots: recommendedLots,
      stopLossDistance: riskPerShare,
      maxLoss: maxLoss,
      totalCapitalRequired: totalCapitalRequired,
      riskRewardRatio: rrRatio,
      notes:
          'IDX: $lotsStr Lot ($sharesStr lembar) = Rp $capitalStr modal (Max Loss: Rp $maxLossStr)',
    );
  }
}
