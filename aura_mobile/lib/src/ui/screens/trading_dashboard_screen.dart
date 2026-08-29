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
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contextual Greeting Card
              _buildGreetingCard(),
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
                height: 280,
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

              // Risk & Lot Calculator
              const RiskCardWidget(),
              const SizedBox(height: 24),

              // Watchlist Section
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
              const SizedBox(height: 80), // Padding for FAB
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF6C63FF)),
                  const SizedBox(width: 10),
                  Text(
                    'AURA Trading Coach (${selectedAsset.symbol})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Tanyakan sesuatu tentang analisa teknikal, strategi risk management, atau berita fundamental:',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPromptChip('Apa tren & support RSI ${selectedAsset.symbol}?'),
                  _buildPromptChip('Berapa Lot ideal dengan risk 2% modal \$10.000?'),
                  _buildPromptChip('Jelaskan korelasi DXY vs Gold hari ini.'),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
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
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pertanyaan dikirim ke AI Coach!'),
                          backgroundColor: Color(0xFF6C63FF),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPromptChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      onPressed: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pertanyaan: "$text" dikirim ke AI Coach!'),
            backgroundColor: const Color(0xFF6C63FF),
          ),
        );
      },
    );
  }
}
