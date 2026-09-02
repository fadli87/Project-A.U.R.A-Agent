import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_trading/aura_trading.dart';

class TradingDashboardScreen extends ConsumerStatefulWidget {
  const TradingDashboardScreen({super.key});

  @override
  ConsumerState<TradingDashboardScreen> createState() =>
      _TradingDashboardScreenState();
}

class _TradingDashboardScreenState
    extends ConsumerState<TradingDashboardScreen> {
  final bool _showEMA20 = true;
  final bool _showEMA50 = true;
  int _selectedTab = 0; // 0: Watchlist & Risk, 1: Trade Journal, 2: Risk Dashboard, 3: MT5

  @override
  Widget build(BuildContext context) {
    final selectedAsset = ref.watch(selectedAssetProvider);
    final selectedTimeframe = ref.watch(selectedTimeframeProvider);
    final watchlistAsync = ref.watch(watchlistProvider);
    final candlesAsync = ref.watch(candleHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.candlestick_chart,
                color: Color(0xFF6C63FF),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'AURA Trading Lab',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              ref.invalidate(watchlistProvider);
              ref.invalidate(candleHistoryProvider);
              ref.read(mt5RefreshCounterProvider.notifier).increment();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAiCoachSheet,
        backgroundColor: const Color(0xFF6C63FF),
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: const Text('AI Trading Coach',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(watchlistProvider);
          ref.invalidate(candleHistoryProvider);
          ref.read(mt5RefreshCounterProvider.notifier).increment();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contextual Greeting Card
              _buildGreetingCard(),
              const SizedBox(height: 12),

              // ── MT5 Live Status Bar ──────────────────────────────
              const SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Mt5StatusBarWidget(),
              ),
              const SizedBox(height: 16),

              // Trading Sessions Heatmap
              const SessionHeatmapWidget(),
              const SizedBox(height: 20),

              // Chart Header & Timeframe Picker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedAsset.symbol,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        selectedAsset.category.name.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: ['15m', '1h', '1d'].map((tf) {
                      final isSelected = tf == selectedTimeframe;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text(tf.toUpperCase()),
                          selected: isSelected,
                          onSelected: (_) {
                            ref.read(selectedTimeframeProvider.notifier).setTimeframe(tf);
                          },
                          selectedColor: const Color(0xFF6C63FF),
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Interactive Chart Widget
              SizedBox(
                height: 260,
                child: candlesAsync.when(
                  data: (candles) => CandlestickChartWidget(
                    candles: candles,
                    showEMA20: _showEMA20,
                    showEMA50: _showEMA50,
                  ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  ),
                  error: (err, stack) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2C),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        'Gagal memuat chart: $err\n(Menggunakan data cache/offline jika ada)',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Mobile Segmented Tab Switcher (Watchlist, Jurnal, Dashboard, MT5)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildTabButton(0, Icons.show_chart, 'Watchlist'),
                    _buildTabButton(1, Icons.menu_book, 'Jurnal'),
                    _buildTabButton(2, Icons.shield, 'Dashboard'),
                    _buildTabButton(3, Icons.swap_vert, 'MT5'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Active Tab Content
              if (_selectedTab == 0) ...[
                const RiskCardWidget(),
                const SizedBox(height: 20),
                const Text(
                  'Market Watchlist',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                watchlistAsync.when(
                  data: (tickers) {
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tickers.length,
                      itemBuilder: (context, index) {
                        final item = tickers[index];
                        final isSelected = item.symbol == selectedAsset.symbol;
                        return WatchlistTile(
                          ticker: item,
                          isSelected: isSelected,
                          onTap: () {
                            ref.read(selectedAssetProvider.notifier).select((
                              symbol: item.symbol,
                              category: item.category,
                            ));
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                    ),
                  ),
                  error: (err, stack) => Text(
                    'Error loading watchlist: $err',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ] else if (_selectedTab == 1) ...[
                const TradeJournalWidget(),
              ] else if (_selectedTab == 2) ...[
                const RiskDashboardWidget(),
              ] else if (_selectedTab == 3) ...[
                const Mt5PositionsWidget(),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.2)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFF6C63FF), size: 14),
                          SizedBox(width: 6),
                          Text(
                            'Informasi MT5 Bridge Mobile',
                            style: TextStyle(
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Jalankan MT5 Terminal & Bridge Service di PC (http://127.0.0.1:8088).\n'
                        '2. Data posisi & balance terhubung otomatis via local network / adb reverse.\n'
                        '3. Penutupan posisi membutuhkan konfirmasi eksplisit (Prinsip 5).',
                        style: TextStyle(color: Colors.white60, fontSize: 10, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 80), // Padding for FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: isSelected ? Colors.white : Colors.white60),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingCard() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Selamat Pagi, Trader 🌅';
    } else if (hour < 18) {
      greeting = 'Selamat Siang, Trader ☀️';
    } else {
      greeting = 'Selamat Malam, Trader 🌙';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3F3D56)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Siap menganalisis Forex, Gold, & Saham IDX dengan disiplin risk-first hari ini?',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showAiCoachSheet() {
    final selectedAsset = ref.read(selectedAssetProvider);
    final selectedTimeframe = ref.read(selectedTimeframeProvider);
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFF6C63FF)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'AURA Trading Coach (${selectedAsset.symbol})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'AI Coach berfokus pada Risk-First. Tanya tentang indikator, lot size aman, atau posisi MT5 live:',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPromptChip(
                          'Bagaimana posisi & akun MT5 saya saat ini?',
                          textController,
                        ),
                        _buildPromptChip(
                          'Berapa lot ideal risk 2% modal \$10.000?',
                          textController,
                        ),
                        _buildPromptChip(
                          'Cek indikator teknikal ${selectedAsset.symbol}',
                          textController,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ketik pertanyaan trading...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send, color: Color(0xFF6C63FF)),
                          onPressed: () async {
                            final query = textController.text.trim();
                            if (query.isEmpty) return;
                            Navigator.pop(context);

                            // Execute grounding query using TradingTools & live context
                            final tools = TradingTools();
                            String reply = '';
                            final lower = query.toLowerCase();

                            if (lower.contains('posisi') ||
                                lower.contains('akun') ||
                                lower.contains('mt5') ||
                                lower.contains('balance')) {
                              reply = await tools.getAccountContext({});
                            } else if (lower.contains('indikator') || lower.contains('rsi')) {
                              reply = await tools.getTechnicalIndicators({
                                'symbol': selectedAsset.symbol,
                                'category': selectedAsset.category.name,
                                'timeframe': selectedTimeframe,
                              });
                            } else {
                              final price = await tools.getCurrentPrice({
                                'symbol': selectedAsset.symbol,
                                'category': selectedAsset.category.name,
                              });
                              reply = '📊 Harga ${selectedAsset.symbol}:\n$price';
                            }

                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1E2C),
                                  title: const Row(
                                    children: [
                                      Icon(Icons.auto_awesome, color: Color(0xFF6C63FF), size: 20),
                                      SizedBox(width: 8),
                                      Text('AURA Coach', style: TextStyle(color: Colors.white, fontSize: 16)),
                                    ],
                                  ),
                                  content: Text(reply, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('OK', style: TextStyle(color: Color(0xFF6C63FF))),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPromptChip(String text, TextEditingController controller) {
    return ActionChip(
      label: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      onPressed: () {
        controller.text = text;
      },
    );
  }
}
