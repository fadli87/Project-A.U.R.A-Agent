import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../data/models/backtest_result.dart';

class EquityCurveChartWidget extends StatelessWidget {
  final List<EquityPoint> equityCurve;
  final double height;

  const EquityCurveChartWidget({
    super.key,
    required this.equityCurve,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (equityCurve.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        child: const Text(
          'Tidak ada data kurva ekuitas.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    final initialEquity = equityCurve.first.equity.toDouble();
    final finalEquity = equityCurve.last.equity.toDouble();
    final isProfitable = finalEquity >= initialEquity;
    final lineColor = isProfitable ? const Color(0xFF00E676) : const Color(0xFFFF5252);

    double minY = initialEquity;
    double maxY = initialEquity;

    final spots = <FlSpot>[];
    for (int i = 0; i < equityCurve.length; i++) {
      final eq = equityCurve[i].equity.toDouble();
      if (eq < minY) minY = eq;
      if (eq > maxY) maxY = eq;
      spots.add(FlSpot(i.toDouble(), eq));
    }

    final padding = (maxY - minY) * 0.1;
    minY -= padding > 0 ? padding : 10;
    maxY += padding > 0 ? padding : 10;

    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: Color(0xFF6C63FF), size: 18),
              const SizedBox(width: 6),
              const Text(
                'Kurva Ekuitas (Equity Curve)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                'Awal: \$${initialEquity.toStringAsFixed(0)} → Akhir: \$${finalEquity.toStringAsFixed(0)}',
                style: TextStyle(
                  color: lineColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (equityCurve.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: initialEquity,
                      color: Colors.white38,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ],
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 55,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value >= 1000
                              ? '\$${(value / 1000).toStringAsFixed(1)}k'
                              : '\$${value.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 18,
                      interval: (equityCurve.length / 4).clamp(1, 100).toDouble(),
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < equityCurve.length) {
                          final dt = equityCurve[idx].timestamp;
                          return Text(
                            '${dt.day}/${dt.month}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 9,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: lineColor,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: lineColor.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
