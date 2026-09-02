import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_trading/aura_trading.dart';
import '../providers/desktop_chat_provider.dart';
import '../services/local_llm_service.dart';

class DesktopTradingScreen extends ConsumerStatefulWidget {
  const DesktopTradingScreen({super.key});

  @override
  ConsumerState<DesktopTradingScreen> createState() => _DesktopTradingScreenState();
}

class _DesktopTradingScreenState extends ConsumerState<DesktopTradingScreen> {
  final TextEditingController _chatInputController = TextEditingController();
  final List<({String sender, String text, DateTime time})> _chatMessages = [];
  bool _isAiReplying = false;
  final bool _showEMA20 = true;
  final bool _showEMA50 = true;
  int _selectedMiddleTab = 0; // 0: Watchlist & Risk, 1: Trade Journal, 2: Risk Dashboard

  @override
  void initState() {
    super.initState();
    // Initial welcome message from AI Trading Coach
    _chatMessages.add((
      sender: 'AURA Coach',
      text:
          'Selamat datang di AURA Desktop Trading Lab! Saya pendamping AI Trading Anda. Saya siap membantu menganalisis teknikal (RSI, MACD, Ichimoku), kalkulasi Lot, dan berita pasar.',
      time: DateTime.now(),
    ));
  }

  void _sendChatMessage() async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty || _isAiReplying) return;

    setState(() {
      _chatMessages.add((sender: 'You', text: text, time: DateTime.now()));
      _chatInputController.clear();
      _isAiReplying = true;
    });

    final tools = TradingTools();
    final selectedAsset = ref.read(selectedAssetProvider);
    final selectedTimeframe = ref.read(selectedTimeframeProvider);
    final chatState = ref.read(desktopChatProvider);

    String aiReply = '';
    try {
      final lowerText = text.toLowerCase();

      // 0. Fetch live MT5 & market context for prompt injection
      String liveContextStr = '';
      try {
        final aiContext = await ref.read(aiTradingContextProvider.future);
        liveContextStr = aiContext.toPromptContext();
      } catch (_) {}

      // 1. Try Local LLM Inference if local server is connected
      if (chatState.isServerConnected && chatState.activeModel.isNotEmpty) {
        try {
          final systemPromptWithContext =
              '${TradingCoachPrompt.systemPrompt}\n\n=== LIVE ACCOUNT & MARKET CONTEXT ===\n$liveContextStr';

          final llmRes = await LocalLlmService.generateChatReply(
            baseUrl: chatState.baseUrl,
            apiType: chatState.apiType,
            model: chatState.activeModel,
            messages: [
              {'role': 'system', 'content': systemPromptWithContext},
              {
                'role': 'user',
                'content':
                    '[Konteks Trading Lab - Aset: ${selectedAsset.symbol} (${selectedAsset.category.name.toUpperCase()}), Timeframe: $selectedTimeframe]\n$text'
              },
            ],
          );
          final content = llmRes['content']?.toString().trim();
          if (content != null && content.isNotEmpty) {
            aiReply = content;
          }
        } catch (e) {
          debugPrint('Local LLM error in Trading Coach panel: $e');
        }
      }

      // 2. Intelligent Tool & Conversational Fallback
      if (aiReply.isEmpty) {
        if (lowerText.contains('posisi') ||
            lowerText.contains('akun') ||
            lowerText.contains('balance') ||
            lowerText.contains('equity') ||
            lowerText.contains('mt5')) {
          final accJson = await tools.getAccountContext({});
          aiReply = '💼 Data Akun & Posisi MT5 Live:\n$accJson';
        } else if (lowerText.contains('harga') ||
            lowerText.contains('price') ||
            lowerText.contains('quote') ||
            lowerText.contains('berapa')) {
          final priceJson = await tools.getCurrentPrice({
            'symbol': selectedAsset.symbol,
            'category': selectedAsset.category.name,
          });
          aiReply = '📊 Data harga terkini untuk ${selectedAsset.symbol}:\n$priceJson';
        } else if (lowerText.contains('indikator') ||
            lowerText.contains('rsi') ||
            lowerText.contains('ichimoku') ||
            lowerText.contains('macd') ||
            lowerText.contains('ema') ||
            lowerText.contains('trend')) {
          final indJson = await tools.getTechnicalIndicators({
            'symbol': selectedAsset.symbol,
            'category': selectedAsset.category.name,
            'timeframe': selectedTimeframe,
          });
          aiReply =
              '📈 Hasil analisis indikator teknikal (${selectedAsset.symbol} - $selectedTimeframe):\n$indJson';
        } else if (lowerText.contains('lot') ||
            lowerText.contains('risk') ||
            lowerText.contains('hitung') ||
            lowerText.contains('kalkulasi')) {
          final lotJson = await tools.calculatePositionSize({
            'equity': 10000,
            'riskPct': 2.0,
            'entryPrice': 2650.0,
            'stopLoss': 2630.0,
            'symbol': selectedAsset.symbol,
            'assetType': selectedAsset.category.name,
          });
          aiReply = '🛡️ Kalkulasi risiko & Lot ideal:\n$lotJson';
        } else if (lowerText.contains('halo') ||
            lowerText.contains('hi') ||
            lowerText.contains('pagi') ||
            lowerText.contains('siang') ||
            lowerText.contains('malam') ||
            lowerText.contains('hey')) {
          aiReply =
              'Halo! Saya AURA Trading Coach. Siap mendampingi Anda menganalisis pasar ${selectedAsset.symbol}. Ada yang ingin Anda tanyakan seputar indikator teknikal, posisi MT5, kalkulasi lot, atau strategi backtest?';
        } else if (lowerText == 'ok' ||
            lowerText == 'oke' ||
            lowerText == 'siap' ||
            lowerText == 'baik' ||
            lowerText == 'sip' ||
            lowerText == 'mantap' ||
            lowerText.contains('terima kasih') ||
            lowerText.contains('thanks') ||
            lowerText.contains('makasih')) {
          aiReply =
              'Sip! Selalu utamakan manajemen risiko sebelum membuka posisi (Stop Loss & Risk/Reward 1:1.5+). Tanyakan kapan saja bila Anda membutuhkan analisis harga atau indikator.';
        } else if (lowerText.contains('backtest') || lowerText.contains('strategi')) {
          aiReply =
              '💡 Anda dapat menguji strategi (EMA Crossover & RSI Mean Reversion) secara langsung di Middle Panel! Pilihlah parameter yang Anda inginkan lalu klik "Jalankan Backtest" untuk melihat Win Rate % dan Equity Curve.';
        } else {
          aiReply =
              'Saya AURA Trading Coach (Risk-First). Untuk instrumen ${selectedAsset.symbol}, Anda bisa menanyakan:\n- "posisi" / "akun" : Cek balance & posisi MT5 live\n- "harga" : Cek quote real-time\n- "indikator" : Cek RSI, MACD, Ichimoku, EMA 20/50\n- "lot" / "risk" : Hitung ukuran lot aman\n- "backtest" : Petunjuk simulasi strategi\n\nAtau aktifkan Server LLM Lokal di tab AI Chat agar kita dapat berdiskusi secara bebas tanpa batas!';
        }
      }
    } catch (e) {
      aiReply = '⚠️ Analisis AI Coach: $e';
    }

    if (mounted) {
      setState(() {
        _chatMessages.add((sender: 'AURA Coach', text: aiReply, time: DateTime.now()));
        _isAiReplying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedAsset = ref.watch(selectedAssetProvider);
    final selectedTimeframe = ref.watch(selectedTimeframeProvider);
    final watchlistAsync = ref.watch(watchlistProvider);
    final candlesAsync = ref.watch(candleHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Column(
        children: [
          // Desktop Top Header Bar
          _buildDesktopHeader(selectedAsset, selectedTimeframe),
          const Divider(height: 1, color: Colors.white10),

          // 3-Panel Main Layout
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PANEL 1 (LEFT 42%): Interactive Real Candlestick Chart
                Expanded(
                  flex: 42,
                  child: _buildChartPanel(candlesAsync, selectedAsset),
                ),
                const VerticalDivider(width: 1, color: Colors.white10),

                // PANEL 2 (MIDDLE 38%): Watchlist, Risk, Jurnal, MT5, Kalender
                Expanded(
                  flex: 38,
                  child: _buildWatchlistAndRiskPanel(watchlistAsync, selectedAsset),
                ),
                const VerticalDivider(width: 1, color: Colors.white10),

                // PANEL 3 (RIGHT 20%): AI Trading Coach Panel
                Expanded(
                  flex: 20,
                  child: _buildAiCoachPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(
    ({String symbol, AssetCategory category}) selectedAsset,
    String selectedTimeframe,
  ) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF161624),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side controls
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.candlestick_chart, color: Color(0xFF6C63FF), size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'AURA Desktop Trading Lab',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Selected Symbol Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          '${selectedAsset.symbol} (${selectedAsset.category.name.toUpperCase()})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Timeframe Selector
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: ['15m', '1h', '1d'].map((tf) {
                          final isSelected = tf == selectedTimeframe;
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
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
                                fontSize: 10.5,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Right side indicators (MT5 Status Bar + Session Heatmap)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Mt5StatusBarWidget(),
                      const SizedBox(width: 12),
                      const FittedBox(
                        child: SessionHeatmapWidget(isCompact: true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// MT5 Tab panel — shows live open positions + tips.
  Widget _buildMt5Panel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      'Cara pakai MT5 Bridge',
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
                  '1. Pastikan MT5 Terminal sudah terbuka di Windows.\n'
                  '2. Klik tombol "Run Service" di header bar atas (atau jalankan script python tools/mt5_bridge/mt5_service.py).\n'
                  '3. Bridge berjalan di http://127.0.0.1:8088.\n'
                  '4. Untuk mematikan, klik tombol "Kill" di header bar atas.',
                  style: TextStyle(color: Colors.white60, fontSize: 10, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartPanel(
    AsyncValue<List<Candle>> candlesAsync,
    ({String symbol, AssetCategory category}) selectedAsset,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: candlesAsync.when(
              data: (candles) => CandlestickChartWidget(
                candles: candles,
                showEMA20: _showEMA20,
                showEMA50: _showEMA50,
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
              ),
              error: (err, stack) => Center(
                child: Text('Chart Error: $err', style: const TextStyle(color: Colors.white70)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Indicators Overview Bar (EMA, RSI, MACD, Ichimoku)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricItem('EMA 20/50', 'Bullish Cross', Colors.amberAccent),
                  const SizedBox(width: 20),
                  _buildMetricItem('RSI (14)', '54.2 (Netral)', Colors.cyanAccent),
                  const SizedBox(width: 20),
                  _buildMetricItem('MACD', '+0.0012 (Up)', const Color(0xFF00E676)),
                  const SizedBox(width: 20),
                  _buildMetricItem('Ichimoku', 'Above Kumo Cloud', const Color(0xFF6C63FF)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildWatchlistAndRiskPanel(
    AsyncValue<List<PriceTicker>> watchlistAsync,
    ({String symbol, AssetCategory category}) selectedAsset,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Middle Panel Tab Header Switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2C),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMiddleTabButton(0, Icons.show_chart, 'Watchlist'),
                  _buildMiddleTabButton(1, Icons.menu_book, 'Jurnal'),
                  _buildMiddleTabButton(2, Icons.shield, 'Dashboard'),
                  _buildMiddleTabButton(3, Icons.swap_vert, 'MT5'),
                  _buildMiddleTabButton(4, Icons.calendar_month, 'Kalender'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Tab View Body
          Expanded(
            child: _selectedMiddleTab == 1
                ? const TradeJournalWidget()
                : _selectedMiddleTab == 2
                    ? const RiskDashboardWidget()
                    : _selectedMiddleTab == 3
                        ? _buildMt5Panel()
                        : _selectedMiddleTab == 4
                            ? const SingleChildScrollView(child: EconomicCalendarWidget())
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const RiskCardWidget(),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Market Watchlist',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: watchlistAsync.when(
                                      data: (tickers) {
                                        return ListView.builder(
                                          itemCount: tickers.length,
                                          itemBuilder: (context, index) {
                                            final item = tickers[index];
                                            return WatchlistTile(
                                              ticker: item,
                                              isSelected: item.symbol == selectedAsset.symbol,
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
                                        child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                                      ),
                                      error: (err, stack) => Text('Watchlist Error: $err',
                                          style: const TextStyle(color: Colors.redAccent)),
                                    ),
                                  ),
                                ],
                              ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleTabButton(int index, IconData icon, String label) {
    final isSelected = _selectedMiddleTab == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => setState(() => _selectedMiddleTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: isSelected ? Colors.white : Colors.white60),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiCoachPanel() {
    return Container(
      color: const Color(0xFF161622),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome, color: Color(0xFF6C63FF), size: 18),
              SizedBox(width: 8),
              Text(
                'AI Trading Coach',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 10),

          // Messages List
          Expanded(
            child: ListView.builder(
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final msg = _chatMessages[index];
                final isUser = msg.sender == 'You';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF6C63FF).withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isUser
                            ? const Color(0xFF6C63FF)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: const TextStyle(color: Colors.white, fontSize: 11.5),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isAiReplying)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)),
                  ),
                  SizedBox(width: 8),
                  Text('AI Coach menganalisis...', style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),

          // Chat Input Box
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatInputController,
                  onSubmitted: (_) => _sendChatMessage(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Tanyakan AI Coach...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF6C63FF), size: 18),
                onPressed: _sendChatMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
