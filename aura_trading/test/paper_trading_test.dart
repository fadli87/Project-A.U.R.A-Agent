import 'package:flutter_test/flutter_test.dart';
import 'package:aura_trading/aura_trading.dart';
import 'package:aura_trading/data/sources/local/trading_database.dart';
import 'package:aura_trading/domain/paper_trading_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PaperTradingEngine Tests', () {
    final engine = PaperTradingEngine();
    final db = TradingDatabase.instance;

    test('openPosition creates valid open trade and record in DB', () async {
      final trade = await engine.openPosition(
        accountId: 'forex_gold_paper',
        symbol: 'XAUUSD=X',
        category: AssetCategory.gold,
        type: 'BUY',
        entryPrice: 2650.0,
        stopLoss: 2630.0,
        takeProfit: 2700.0,
        lots: 0.1,
      );

      expect(trade['id'], isNotNull);
      expect(trade['symbol'], equals('XAUUSD=X'));
      expect(trade['type'], equals('BUY'));
      expect(trade['entry_price'], equals(2650.0));
      expect(trade['status'], equals('OPEN'));

      final openTrades = await db.getOpenPaperTrades('forex_gold_paper');
      expect(openTrades.length, greaterThanOrEqualTo(1));
    });

    test('closePosition calculates PnL correctly and updates balance', () async {
      final trade = await engine.openPosition(
        accountId: 'forex_gold_paper',
        symbol: 'EURUSD=X',
        category: AssetCategory.forex,
        type: 'BUY',
        entryPrice: 1.0800,
        stopLoss: 1.0750,
        takeProfit: 1.0900,
        lots: 1.0,
      );

      final tradeId = trade['id'] as String;
      // Close at 1.0850 (+50 pips) -> 50 pips * 1.0 lot * 100,000 = $500 PnL
      final pnl = await engine.closePosition(tradeId: tradeId, exitPrice: 1.0850);
      expect(pnl, closeTo(500.0, 0.01));

      final account = await db.getAccount('forex_gold_paper');
      expect(account, isNotNull);
      expect(account!['balance'], greaterThan(10000.0));
    });

    test('evaluateOpenPositions triggers Auto-Fill Stop Loss', () async {
      final trade = await engine.openPosition(
        accountId: 'forex_gold_paper',
        symbol: 'GBPUSD=X',
        category: AssetCategory.forex,
        type: 'BUY',
        entryPrice: 1.3000,
        stopLoss: 1.2950,
        takeProfit: 1.3100,
        lots: 0.5,
      );

      final tradeId = trade['id'] as String;

      // Price drops below SL (1.2940 <= 1.2950)
      await engine.evaluateOpenPositions(
        accountId: 'forex_gold_paper',
        currentMarketPrices: {'GBPUSD=X': 1.2940},
      );

      final openTrades = await db.getOpenPaperTrades('forex_gold_paper');
      final isStillOpen = openTrades.any((t) => t['id'] == tradeId);
      expect(isStillOpen, isFalse);
    });

    test('TradeJournal CRUD and emotion filter work correctly', () async {
      final journal = TradeJournal(
        id: 'j_${DateTime.now().millisecondsSinceEpoch}',
        symbol: 'XAUUSD=X',
        action: 'BUY',
        entryPrice: 2650.0,
        exitPrice: 2680.0,
        pnl: 300.0,
        setupReasoning: 'Breakout EMA 50 + RSI 55 + Ichimoku Kumo support',
        emotionTag: 'Discipline',
        aiReviewNote: 'Entry bagus sesuai plan.',
        createdAt: DateTime.now(),
      );

      await db.insertTradeJournal(journal);

      final journals = await db.getTradeJournals(emotionFilter: 'Discipline');
      expect(journals.isNotEmpty, isTrue);
      expect(journals.first.emotionTag, equals('Discipline'));
    });
  });
}
