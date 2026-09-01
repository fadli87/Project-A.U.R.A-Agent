import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import '../../data/models/price_ticker.dart';
import '../../data/models/trade_journal.dart';
import '../../data/sources/local/trading_database.dart';

class TradeJournalWidget extends StatefulWidget {
  const TradeJournalWidget({super.key});

  @override
  State<TradeJournalWidget> createState() => _TradeJournalWidgetState();
}

class _TradeJournalWidgetState extends State<TradeJournalWidget> {
  final TradingDatabase _db = TradingDatabase.instance;
  List<TradeJournal> _journals = [];
  bool _isLoading = true;
  String _selectedEmotionFilter = 'ALL';

  final List<String> _emotionOptions = [
    'ALL',
    'Discipline',
    'FOMO',
    'Revenge',
    'Fear',
    'Greed',
  ];

  @override
  void initState() {
    super.initState();
    _loadJournals();
  }

  Future<void> _loadJournals() async {
    setState(() => _isLoading = true);
    final data = await _db.getTradeJournals(emotionFilter: _selectedEmotionFilter);
    if (mounted) {
      setState(() {
        _journals = data;
        _isLoading = false;
      });
    }
  }

  void _showAddJournalDialog() {
    final symbolController = TextEditingController(text: 'XAUUSD=X');
    final entryController = TextEditingController(text: '2650.0');
    final exitController = TextEditingController(text: '2670.0');
    final pnlController = TextEditingController(text: '200.0');
    final reasoningController = TextEditingController();
    String selectedAction = 'BUY';
    String selectedEmotion = 'Discipline';
    AssetCategory selectedCategory = AssetCategory.gold;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit_note, color: Color(0xFF6C63FF)),
              SizedBox(width: 8),
              Text('Tambah Jurnal Trading', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: symbolController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Symbol',
                              labelStyle: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: selectedAction,
                          dropdownColor: const Color(0xFF1E1E2C),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          items: ['BUY', 'SELL']
                              .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedAction = val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: entryController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Entry Price',
                              labelStyle: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: exitController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Exit Price',
                              labelStyle: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: pnlController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Profit / Loss (\$ / Rp)',
                        labelStyle: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Emosi Saat Trade:', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    Wrap(
                      spacing: 6,
                      children: ['Discipline', 'FOMO', 'Revenge', 'Fear', 'Greed'].map((tag) {
                        final isSelected = selectedEmotion == tag;
                        return ChoiceChip(
                          label: Text(tag, style: const TextStyle(fontSize: 10)),
                          selected: isSelected,
                          selectedColor: const Color(0xFF6C63FF),
                          onSelected: (_) {
                            setDialogState(() => selectedEmotion = tag);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasoningController,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: 'Alasan Setup / Perasaan',
                        labelStyle: TextStyle(color: Colors.white60, fontSize: 11),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
              onPressed: () async {
                final symbol = symbolController.text.trim();
                final entry = Decimal.tryParse(entryController.text) ?? Decimal.zero;
                final exit = Decimal.tryParse(exitController.text) ?? Decimal.zero;
                final pnl = Decimal.tryParse(pnlController.text) ?? Decimal.zero;
                final reasoning = reasoningController.text.trim();

                if (symbol.isNotEmpty) {
                  final newJournal = TradeJournal(
                    id: 'j_${DateTime.now().millisecondsSinceEpoch}',
                    symbol: symbol,
                    category: selectedCategory,
                    action: selectedAction,
                    entryPrice: entry,
                    exitPrice: exit,
                    pnl: pnl,
                    setupReasoning: reasoning.isEmpty ? 'Trade tanpa catatan.' : reasoning,
                    emotionTag: selectedEmotion,
                    aiReviewNote: null,
                    createdAt: DateTime.now(),
                  );
                  await _db.insertTradeJournal(newJournal);
                  if (context.mounted) Navigator.pop(context);
                  _loadJournals();
                }
              },
              child: const Text('Simpan Jurnal', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runAiReview(TradeJournal journal) async {
    // Generate AI Review note based on emotion & risk analysis
    String reviewText;
    if (journal.emotionTag == 'FOMO' || journal.emotionTag == 'Revenge') {
      reviewText =
          '⚠️ Refleksi AI Coach: Trade ini dipicu oleh emosi ${journal.emotionTag}. Memasuki pasar tanpa konfirmasi setup teknikal meningkatkan risiko drawdown secara signifikan. Disiplinkan diri untuk selalu menunggu sinyal EMA/Ichimoku yang valid.';
    } else if (journal.emotionTag == 'Discipline') {
      reviewText =
          '✅ Refleksi AI Coach: Sangat baik! Eksekusi sesuai rencana trading disiplin. Pertahankan rasio Risk/Reward dan pembatasan Lot aman ini secara berkesinambungan.';
    } else {
      reviewText =
          'ℹ️ Refleksi AI Coach: Trade selesai dengan P&L \$${journal.pnl.toStringAsFixed(2)}. Selalu catat evaluasi pasca-exit untuk memperkuat pertahanan risiko portofolio Anda.';
    }

    await _db.updateJournalAiReview(journal.id, reviewText);
    _loadJournals();
  }

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.menu_book, color: Color(0xFF6C63FF), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Jurnal & Evaluasi',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddJournalDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.add, size: 14, color: Colors.white),
                label: const Text('Catat', style: TextStyle(fontSize: 10.5, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Emotion Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _emotionOptions.map((tag) {
                final isSelected = _selectedEmotionFilter == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(tag, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.white60)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF6C63FF).withValues(alpha: 0.8),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    onSelected: (_) {
                      setState(() => _selectedEmotionFilter = tag);
                      _loadJournals();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Journals List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : _journals.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada entri jurnal trading.\nKlik "Catat Jurnal" untuk memulai.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _journals.length,
                        itemBuilder: (context, index) {
                          final item = _journals[index];
                          final isProfit = item.pnl >= Decimal.zero;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E2C),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${item.symbol} (${item.action})',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    _buildEmotionBadge(item.emotionTag),
                                    const Spacer(),
                                    Text(
                                      '${isProfit ? '+' : ''}\$${item.pnl.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: isProfit ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.setupReasoning,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                                const SizedBox(height: 6),

                                // AI Review Section
                                if (item.aiReview != null)
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      item.aiReview!,
                                      style: const TextStyle(color: Colors.white, fontSize: 10.5),
                                    ),
                                  )
                                else
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () => _runAiReview(item),
                                      icon: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF6C63FF)),
                                      label: const Text('AI Review', style: TextStyle(fontSize: 10, color: Color(0xFF6C63FF))),
                                    ),
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

  Widget _buildEmotionBadge(String emotion) {
    Color bg;
    switch (emotion) {
      case 'Discipline':
        bg = const Color(0xFF00E676);
        break;
      case 'FOMO':
      case 'Revenge':
        bg = const Color(0xFFFF5252);
        break;
      default:
        bg = Colors.amber;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bg.withValues(alpha: 0.5)),
      ),
      child: Text(
        emotion,
        style: TextStyle(color: bg, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}
