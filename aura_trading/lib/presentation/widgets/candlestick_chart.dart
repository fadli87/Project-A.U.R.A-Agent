import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/candle.dart';
import '../../domain/indicators.dart';

enum ChartType { candlestick, line }

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
  ChartType _chartType = ChartType.candlestick;
  late int _visibleCount;
  int _scrollOffset = 0; // 0 means anchored to latest candle
  int? _hoveredIndex;

  List<double?> _ema20 = [];
  List<double?> _ema50 = [];

  @override
  void initState() {
    super.initState();
    _visibleCount = min(35, widget.candles.isEmpty ? 35 : widget.candles.length);
    _recalculateIndicators();
  }

  @override
  void didUpdateWidget(covariant CandlestickChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candles != widget.candles) {
      _recalculateIndicators();
      _scrollOffset = 0;
      _visibleCount = min(35, widget.candles.isEmpty ? 35 : widget.candles.length);
    }
  }

  void _recalculateIndicators() {
    if (widget.candles.isNotEmpty) {
      _ema20 = TechnicalIndicators.calculateEMA(widget.candles, 20);
      _ema50 = TechnicalIndicators.calculateEMA(widget.candles, 50);
    }
  }

  void _zoomIn() {
    setState(() {
      if (_visibleCount > 12) {
        _visibleCount = max(10, _visibleCount - 8);
      }
    });
  }

  void _zoomOut() {
    setState(() {
      if (_visibleCount < widget.candles.length) {
        _visibleCount = min(widget.candles.length, _visibleCount + 10);
      }
    });
  }

  void _resetZoom() {
    setState(() {
      _visibleCount = min(35, widget.candles.length);
      _scrollOffset = 0;
      _hoveredIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: const Center(
          child: Text('Tidak ada data chart', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    // Determine slice of visible candles
    final total = widget.candles.length;
    final maxOffset = max(0, total - _visibleCount);
    final currentOffset = _scrollOffset.clamp(0, maxOffset);

    final startIndex = max(0, total - _visibleCount - currentOffset);
    final endIndex = min(total, startIndex + _visibleCount);
    final visibleCandles = widget.candles.sublist(startIndex, endIndex);

    // Selected or latest candle for info bar
    final activeCandle = _hoveredIndex != null &&
            _hoveredIndex! >= 0 &&
            _hoveredIndex! < visibleCandles.length
        ? visibleCandles[_hoveredIndex!]
        : visibleCandles.last;

    final isBullish = activeCandle.close >= activeCandle.open;
    final change = (activeCandle.close - activeCandle.open).toDouble();
    final changePct = activeCandle.open.toDouble() > 0
        ? (change / activeCandle.open.toDouble()) * 100
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161626).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Bar: Title + Indicators + Zoom Controls ─────────
          Row(
            children: [
              Icon(
                _chartType == ChartType.candlestick
                    ? Icons.candlestick_chart_rounded
                    : Icons.show_chart_rounded,
                color: const Color(0xFF6C63FF),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Candlestick Pro',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 10),

              // Mode Toggle (Candles / Line)
              InkWell(
                onTap: () {
                  setState(() {
                    _chartType = _chartType == ChartType.candlestick
                        ? ChartType.line
                        : ChartType.candlestick;
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _chartType == ChartType.candlestick
                            ? Icons.bar_chart
                            : Icons.timeline,
                        size: 13,
                        color: const Color(0xFF00E676),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _chartType == ChartType.candlestick ? 'Candles' : 'Line',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Zoom Controls
              _buildZoomButton(Icons.zoom_in_rounded, 'Zoom In', _zoomIn),
              const SizedBox(width: 4),
              _buildZoomButton(Icons.zoom_out_rounded, 'Zoom Out', _zoomOut),
              const SizedBox(width: 4),
              _buildZoomButton(Icons.restart_alt_rounded, 'Reset Zoom', _resetZoom),
            ],
          ),
          const SizedBox(height: 8),

          // ── Live Candle Stats (OHLC + Change) ──────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildOhlcStat('O', activeCandle.open.toDouble()),
                _buildOhlcStat('H', activeCandle.high.toDouble()),
                _buildOhlcStat('L', activeCandle.low.toDouble()),
                _buildOhlcStat('C', activeCandle.close.toDouble(),
                    highlightColor:
                        isBullish ? const Color(0xFF00E676) : const Color(0xFFFF5252)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isBullish
                            ? const Color(0xFF00E676)
                            : const Color(0xFFFF5252))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${isBullish ? "+" : ""}${changePct.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: isBullish
                          ? const Color(0xFF00E676)
                          : const Color(0xFFFF5252),
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (widget.showEMA20)
                  _buildEmaLegend('EMA 20', Colors.amberAccent),
                const SizedBox(width: 8),
                if (widget.showEMA50)
                  _buildEmaLegend('EMA 50', Colors.cyanAccent),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Main Candlestick CustomPainter with Pan & Tap ──────────
          Expanded(
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  // Drag left scrolls back in time, drag right scrolls forward
                  if (details.primaryDelta != null) {
                    final delta = (details.primaryDelta! / 8).round();
                    _scrollOffset = (_scrollOffset + delta).clamp(0, maxOffset);
                  }
                });
              },
              onTapDown: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  final width = box.size.width - 65; // minus right axis
                  final x = details.localPosition.dx.clamp(0.0, width);
                  final candleWidth = width / visibleCandles.length;
                  final index = (x / candleWidth).floor().clamp(0, visibleCandles.length - 1);
                  setState(() => _hoveredIndex = index);
                }
              },
              child: CustomPaint(
                size: Size.infinite,
                painter: _ProfessionalCandlePainter(
                  candles: visibleCandles,
                  startIndex: startIndex,
                  fullEma20: _ema20,
                  fullEma50: _ema50,
                  showEMA20: widget.showEMA20,
                  showEMA50: widget.showEMA50,
                  chartType: _chartType,
                  hoveredIndex: _hoveredIndex,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, String tooltip, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, color: Colors.white70, size: 15),
      ),
    );
  }

  Widget _buildOhlcStat(String label, double val, {Color? highlightColor}) {
    String formatted;
    if (val >= 1000) {
      formatted = val.toStringAsFixed(1);
    } else if (val >= 10) {
      formatted = val.toStringAsFixed(2);
    } else {
      formatted = val.toStringAsFixed(4);
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
          Text(
            formatted,
            style: TextStyle(
              color: highlightColor ?? Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmaLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 2, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ProfessionalCandlePainter extends CustomPainter {
  final List<Candle> candles;
  final int startIndex;
  final List<double?> fullEma20;
  final List<double?> fullEma50;
  final bool showEMA20;
  final bool showEMA50;
  final ChartType chartType;
  final int? hoveredIndex;

  _ProfessionalCandlePainter({
    required this.candles,
    required this.startIndex,
    required this.fullEma20,
    required this.fullEma50,
    required this.showEMA20,
    required this.showEMA50,
    required this.chartType,
    required this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final rightMargin = 60.0; // Space for Y-axis labels
    final bottomMargin = 22.0; // Space for X-axis timestamps
    final chartWidth = size.width - rightMargin;
    final chartHeight = size.height - bottomMargin;

    // Find Min and Max Y values in visible window
    double minY = candles.first.low.toDouble();
    double maxY = candles.first.high.toDouble();

    for (final c in candles) {
      final lo = c.low.toDouble();
      final hi = c.high.toDouble();
      if (lo < minY) minY = lo;
      if (hi > maxY) maxY = hi;
    }

    // Add 8% vertical breathing space
    final range = max(0.00001, maxY - minY);
    minY -= range * 0.05;
    maxY += range * 0.05;
    final effectiveRange = maxY - minY;

    double toY(double price) {
      return chartHeight - ((price - minY) / effectiveRange) * chartHeight;
    }

    // ── 1. Draw Horizontal Grid Lines & Right Price Labels ──────────
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    final gridSteps = 5;
    for (int i = 0; i <= gridSteps; i++) {
      final price = minY + (effectiveRange / gridSteps) * i;
      final y = toY(price);

      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);

      // Price text on right
      String priceStr = price >= 1000
          ? price.toStringAsFixed(1)
          : (price >= 10 ? price.toStringAsFixed(2) : price.toStringAsFixed(4));

      final textSpan = TextSpan(
        text: priceStr,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(chartWidth + 6, y - tp.height / 2));
    }

    // ── 2. Draw Candlesticks or Line ────────────────────────────────
    final candleCount = candles.length;
    final stepX = chartWidth / candleCount;
    final candleWidth = max(2.5, stepX * 0.65);

    final bullishPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.fill;
    final bullishWickPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..strokeWidth = 1.2;

    final bearishPaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..style = PaintingStyle.fill;
    final bearishWickPaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..strokeWidth = 1.2;

    final linePath = Path();

    for (int i = 0; i < candleCount; i++) {
      final c = candles[i];
      final x = (i + 0.5) * stepX;

      final openY = toY(c.open.toDouble());
      final closeY = toY(c.close.toDouble());
      final highY = toY(c.high.toDouble());
      final lowY = toY(c.low.toDouble());

      final isBullish = c.close >= c.open;
      final bodyPaint = isBullish ? bullishPaint : bearishPaint;
      final wickPaint = isBullish ? bullishWickPaint : bearishWickPaint;

      if (chartType == ChartType.candlestick) {
        // Upper & Lower Wicks
        canvas.drawLine(Offset(x, highY), Offset(x, lowY), wickPaint);

        // Candle Body
        final top = min(openY, closeY);
        final bottom = max(openY, closeY);
        final height = max(1.5, bottom - top);

        final rect = Rect.fromCenter(
          center: Offset(x, top + height / 2),
          width: candleWidth,
          height: height,
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
          bodyPaint,
        );
      } else {
        // Line chart point
        if (i == 0) {
          linePath.moveTo(x, closeY);
        } else {
          linePath.lineTo(x, closeY);
        }
      }

      // X-Axis Date labels (sampled every 6 candles)
      if (i % max(1, (candleCount / 5).floor()) == 0) {
        final dt = c.timestamp;
        final dateText = '${dt.day}/${dt.month}';
        final textSpan = TextSpan(
          text: dateText,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 9,
          ),
        );
        final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, chartHeight + 6));
      }
    }

    if (chartType == ChartType.line) {
      final linePaint = Paint()
        ..color = const Color(0xFF6C63FF)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawPath(linePath, linePaint);
    }

    // ── 3. Draw EMA Overlays ────────────────────────────────────────
    void drawEmaLine(List<double?> fullEma, Color color) {
      final emaPath = Path();
      bool started = false;

      for (int i = 0; i < candleCount; i++) {
        final globalIdx = startIndex + i;
        if (globalIdx >= 0 && globalIdx < fullEma.length) {
          final emaVal = fullEma[globalIdx];
          if (emaVal != null) {
            final x = (i + 0.5) * stepX;
            final y = toY(emaVal);
            if (!started) {
              emaPath.moveTo(x, y);
              started = true;
            } else {
              emaPath.lineTo(x, y);
            }
          }
        }
      }

      if (started) {
        final paint = Paint()
          ..color = color
          ..strokeWidth = 1.3
          ..style = PaintingStyle.stroke;
        canvas.drawPath(emaPath, paint);
      }
    }

    if (showEMA20 && fullEma20.isNotEmpty) {
      drawEmaLine(fullEma20, Colors.amberAccent);
    }
    if (showEMA50 && fullEma50.isNotEmpty) {
      drawEmaLine(fullEma50, Colors.cyanAccent);
    }

    // ── 4. Draw Crosshair on Hover/Tap ──────────────────────────────
    if (hoveredIndex != null && hoveredIndex! >= 0 && hoveredIndex! < candleCount) {
      final hx = (hoveredIndex! + 0.5) * stepX;
      final hy = toY(candles[hoveredIndex!].close.toDouble());

      final crosshairPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(hx, 0), Offset(hx, chartHeight), crosshairPaint);
      canvas.drawLine(Offset(0, hy), Offset(chartWidth, hy), crosshairPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProfessionalCandlePainter oldDelegate) {
    return true;
  }
}
