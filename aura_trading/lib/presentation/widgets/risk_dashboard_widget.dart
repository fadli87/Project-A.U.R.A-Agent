import 'package:flutter/material.dart';
import '../../data/sources/local/trading_database.dart';
import '../../domain/paper_trading_engine.dart';

class RiskDashboardWidget extends StatefulWidget {
  final String accountId;
  const RiskDashboardWidget({super.key, this.accountId = 'forex_gold_paper'});

  @override
  State<RiskDashboardWidget> createState() => _RiskDashboardWidgetState();
}

class _RiskDashboardWidgetState extends State<RiskDashboardWidget> {
  final TradingDatabase _db = TradingDatabase.instance;
  final PaperTradingEngine _engine = PaperTradingEngine();

  Map<String, dynamic>? _account;
  List<Map<String, dynamic>> _openTrades = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final acc = await _db.getAccount(widget.accountId);
    final trades = await _db.getOpenPaperTrades(widget.accountId);

    if (mounted) {
      setState(() {
        _account = acc;
        _openTrades = trades;
        _isLoading = false;
      });
    }
  }

  Future<void> _closePosition(String tradeId, double currentEntryPrice) async {
    await _engine.closePosition(tradeId: tradeId, exitPrice: currentEntryPrice);
    _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)));
    }

    final balance = _account?['balance'] as double? ?? 10000.0;
    final equity = _account?['equity'] as double? ?? 10000.0;
    final drawdownPct = ((equity - balance) / balance) * 100;
    final maxDailyLossPct = 3.0; // 3% max daily risk rule
    final isLossLimitExceeded = drawdownPct <= -maxDailyLossPct;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield, color: Color(0xFFFF5252), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Risk & Paper Trading',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white54, size: 18),
                onPressed: _loadDashboardData,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Daily Loss Limit Alert Banner
          if (isLossLimitExceeded)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFF5252)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PERINGATAN: Kerugian harian melebihi batas 3%! Hentikan trading dan evaluasi psikologi Anda.',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // Account Metrics Cards Row
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Balance',
                  '\$${balance.toStringAsFixed(2)}',
                  Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  'Equity',
                  '\$${equity.toStringAsFixed(2)}',
                  equity >= balance ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  'Floating P/L',
                  '${drawdownPct >= 0 ? '+' : ''}${drawdownPct.toStringAsFixed(2)}%',
                  drawdownPct >= 0 ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          const Text(
            'Posisi Terbuka (Paper Trades)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),

          // Open Trades List
          Expanded(
            child: _openTrades.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada posisi aktif saat ini.',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: _openTrades.length,
                    itemBuilder: (context, index) {
                      final item = _openTrades[index];
                      final tradeId = item['id'] as String;
                      final symbol = item['symbol'] as String;
                      final type = item['type'] as String;
                      final entryPrice = item['entry_price'] as double;
                      final lots = item['lots'] as double;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2C),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$symbol ($type $lots Lot)',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Entry: $entryPrice',
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5252).withValues(alpha: 0.8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => _closePosition(tradeId, entryPrice),
                              child: const Text('Tutup',
                                  style: TextStyle(color: Colors.white, fontSize: 10)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
