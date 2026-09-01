import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../data/models/candle.dart';
import '../../domain/indicators.dart';

class CandlestickChartWidget extends StatefulWidget {
  final List<Candle> candles;
  final bool showEMA20;
  final bool showEMA50;

  const CandlestickChartWidget({
    super.key,
    required this.candles,
    this.showEMA20 = true,
    this.showEMA50 = true,
  });

  @override
  State<CandlestickChartWidget> createState() => _CandlestickChartWidgetState();
}

class _CandlestickChartWidgetState extends State<CandlestickChartWidget> {
  List<double?> _ema20 = [];
  List<double?> _ema50 = [];

  @override
  void initState() {
    super.initState();
    _recalculateIndicators();
  }

  @override
  void didUpdateWidget(covariant CandlestickChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candles != widget.candles) {
      _recalculateIndicators();
    }
  }

  void _recalculateIndicators() {
    if (widget.candles.isNotEmpty) {
      _ema20 = TechnicalIndicators.calculateEMA(widget.candles, 20);
      _ema50 = TechnicalIndicators.calculateEMA(widget.candles, 50);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candles.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada data chart',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final candles = widget.candles;
    double minY = candles.first.low.toDouble();
    double maxY = candles.first.high.toDouble();

    for (var c in candles) {
      final lo = c.low.toDouble();
      final hi = c.high.toDouble();
      if (lo < minY) minY = lo;
      if (hi > maxY) maxY = hi;
    }

    // Add padding to Y range
    final padding = (maxY - minY) * 0.05;
    minY -= padding;
    maxY += padding;

    final lineBarsData = <LineChartBarData>[];

    // Close prices line chart
    final closePoints = <FlSpot>[];
    for (int i = 0; i < candles.length; i++) {
      closePoints.add(FlSpot(i.toDouble(), candles[i].close.toDouble()));
    }

    lineBarsData.add(
      LineChartBarData(
        spots: closePoints,
        isCurved: false,
        color: const Color(0xFF6C63FF),
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
        ),
      ),
    );

    // EMA 20 Line (Amber)
    if (widget.showEMA20 && _ema20.length == candles.length) {
      final ema20Points = <FlSpot>[];
      for (int i = 0; i < _ema20.length; i++) {
        if (_ema20[i] != null) {
          ema20Points.add(FlSpot(i.toDouble(), _ema20[i]!));
        }
      }
      if (ema20Points.isNotEmpty) {
        lineBarsData.add(
          LineChartBarData(
            spots: ema20Points,
            isCurved: true,
            color: Colors.amberAccent,
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
          ),
        );
      }
    }

    // EMA 50 Line (Cyan)
    if (widget.showEMA50 && _ema50.length == candles.length) {
      final ema50Points = <FlSpot>[];
      for (int i = 0; i < _ema50.length; i++) {
        if (_ema50[i] != null) {
          ema50Points.add(FlSpot(i.toDouble(), _ema50[i]!));
        }
      }
      if (ema50Points.isNotEmpty) {
        lineBarsData.add(
          LineChartBarData(
            spots: ema50Points,
            isCurved: true,
            color: Colors.cyanAccent,
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: Color(0xFF6C63FF), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Price & Trend (EMA 20/50)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (widget.showEMA20)
                _buildIndicatorBadge('EMA 20', Colors.amberAccent),
              const SizedBox(width: 6),
              if (widget.showEMA50)
                _buildIndicatorBadge('EMA 50', Colors.cyanAccent),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (candles.length - 1).toDouble(),
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
                              ? value.toStringAsFixed(0)
                              : value.toStringAsFixed(2),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: (candles.length / 4).clamp(1, 100).toDouble(),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < candles.length) {
                          final dt = candles[index].timestamp;
                          return Text(
                            '${dt.day}/${dt.month}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: lineBarsData,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
