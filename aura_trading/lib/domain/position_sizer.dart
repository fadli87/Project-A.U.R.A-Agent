class PositionSizeResult {
  final double riskAmount;
  final double calculatedLots;
  final double recommendedLots;
  final double stopLossDistance;
  final double maxLoss;
  final double totalCapitalRequired;
  final double riskRewardRatio;
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
  /// Position size calculator for Forex and Gold (XAU/USD).
  /// [equity]: Account balance in USD (e.g. $10,000)
  /// [riskPct]: Risk percentage per trade (e.g. 1.0% or 2.0%)
  /// [entryPrice]: Intended entry price
  /// [stopLoss]: Stop loss price
  /// [takeProfit]: Optional take profit price for R:R calculation
  static PositionSizeResult calculateForexGold({
    required double equity,
    required double riskPct,
    required double entryPrice,
    required double stopLoss,
    double? takeProfit,
    bool isGold = false,
  }) {
    final riskAmount = equity * (riskPct / 100);
    final priceDiff = (entryPrice - stopLoss).abs();

    if (priceDiff == 0) {
      throw ArgumentError('Entry price and Stop Loss cannot be equal.');
    }

    double pipSize = isGold ? 0.1 : 0.0001; // 1 pip for Gold = 0.1, Forex = 0.0001
    double pipValuePerStandardLot = isGold ? 10.0 : 10.0; // $10 per pip per 1.0 Lot

    double pipsAtRisk = priceDiff / pipSize;
    double calculatedLots = riskAmount / (pipsAtRisk * pipValuePerStandardLot);
    
    // Round to 2 decimal places (standard micro-lot precision 0.01)
    double recommendedLots = (calculatedLots * 100).floorToDouble() / 100;
    if (recommendedLots < 0.01) recommendedLots = 0.01;

    double maxLoss = pipsAtRisk * pipValuePerStandardLot * recommendedLots;
    double capitalRequired = recommendedLots * 100000 * entryPrice / 100; // Assuming leverage 1:100

    double rrRatio = 0.0;
    if (takeProfit != null && takeProfit != entryPrice) {
      final tpDistance = (takeProfit - entryPrice).abs();
      rrRatio = tpDistance / priceDiff;
    }

    return PositionSizeResult(
      riskAmount: riskAmount,
      calculatedLots: calculatedLots,
      recommendedLots: recommendedLots,
      stopLossDistance: pipsAtRisk,
      maxLoss: maxLoss,
      totalCapitalRequired: capitalRequired,
      riskRewardRatio: rrRatio,
      notes: isGold
          ? 'XAU/USD: $pipsAtRisk pips at risk ($recommendedLots Lot = ~\$${maxLoss.toStringAsFixed(2)} risk)'
          : 'Forex: $pipsAtRisk pips at risk ($recommendedLots Lot = ~\$${maxLoss.toStringAsFixed(2)} risk)',
    );
  }

  /// Position size calculator for Saham IDX (Indonesian Stocks).
  /// [equity]: Account balance in IDR (e.g. Rp 100.000.000)
  /// [riskPct]: Risk percentage per trade (e.g. 2.0%)
  /// [entryPrice]: Entry price per share (e.g. Rp 8.000 for BBCA)
  /// [stopLoss]: Stop loss price per share (e.g. Rp 7.750)
  /// [takeProfit]: Take profit price per share (e.g. Rp 8.500)
  static PositionSizeResult calculateIDXStock({
    required double equity,
    required double riskPct,
    required double entryPrice,
    required double stopLoss,
    double? takeProfit,
  }) {
    final riskAmount = equity * (riskPct / 100);
    final riskPerShare = (entryPrice - stopLoss).abs();

    if (riskPerShare == 0) {
      throw ArgumentError('Entry price and Stop Loss cannot be equal.');
    }

    final totalSharesRaw = riskAmount / riskPerShare;
    // 1 Lot Saham IDX = 100 lembar saham
    final calculatedLots = totalSharesRaw / 100;
    int recommendedLots = calculatedLots.floor();
    if (recommendedLots < 1) recommendedLots = 1;

    final actualShares = recommendedLots * 100;
    final totalCapitalRequired = actualShares * entryPrice;
    final maxLoss = actualShares * riskPerShare;

    double rrRatio = 0.0;
    if (takeProfit != null && takeProfit != entryPrice) {
      final rewardPerShare = (takeProfit - entryPrice).abs();
      rrRatio = rewardPerShare / riskPerShare;
    }

    return PositionSizeResult(
      riskAmount: riskAmount,
      calculatedLots: calculatedLots,
      recommendedLots: recommendedLots.toDouble(),
      stopLossDistance: riskPerShare,
      maxLoss: maxLoss,
      totalCapitalRequired: totalCapitalRequired,
      riskRewardRatio: rrRatio,
      notes:
          'IDX: $recommendedLots Lot (${actualShares} lembar) = Rp ${totalCapitalRequired.toStringAsFixed(0)} modal (Max Loss: Rp ${maxLoss.toStringAsFixed(0)})',
    );
  }
}
