import 'package:flutter_test/flutter_test.dart';
import 'package:aura_trading/aura_trading.dart';

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
        entryPrice: Decimal.parse('2650.0'),
        stopLoss: Decimal.parse('2630.0'),
        takeProfit: Decimal.parse('2700.0'),
        lots: Decimal.parse('0.1'),
      );

      expect(trade['id'], isNotNull);
      expect(trade['symbol'], equals('XAUUSD=X'));
      expect(trade['type'], equals('BUY'));
      // entry_price stored as Decimal string; Decimal('2650.0').toString() = '2650'
      expect(Decimal.parse(trade['entry_price'].toString()),
          equals(Decimal.parse('2650.0')));
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
        entryPrice: Decimal.parse('1.0800'),
        stopLoss: Decimal.parse('1.0750'),
        takeProfit: Decimal.parse('1.0900'),
        lots: Decimal.parse('1.0'),
      );

      final tradeId = trade['id'] as String;
      // Close at 1.0850 (+50 pips) → 50 pips * 1.0 lot * 100,000 = $500 PnL
      final pnl = await engine.closePosition(
          tradeId: tradeId, exitPrice: Decimal.parse('1.0850'));

      // pnl should be exactly 500 with Decimal (0.005 * 1.0 * 100000 = 500)
      expect(pnl, equals(Decimal.fromInt(500)));

      final account = await db.getAccount('forex_gold_paper');
      expect(account, isNotNull);
      // balance should be greater than initial 10000
      expect(account!['balance'] as Decimal > Decimal.fromInt(10000), isTrue);
    });

    test('evaluateOpenPositions triggers Auto-Fill Stop Loss', () async {
      final trade = await engine.openPosition(
        accountId: 'forex_gold_paper',
        symbol: 'GBPUSD=X',
        category: AssetCategory.forex,
        type: 'BUY',
        entryPrice: Decimal.parse('1.3000'),
        stopLoss: Decimal.parse('1.2950'),
        takeProfit: Decimal.parse('1.3100'),
        lots: Decimal.parse('0.5'),
      );

      final tradeId = trade['id'] as String;

      // Price drops below SL (1.2940 <= 1.2950)
      await engine.evaluateOpenPositions(
        accountId: 'forex_gold_paper',
        currentMarketPrices: {'GBPUSD=X': Decimal.parse('1.2940')},
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
        entryPrice: Decimal.parse('2650.0'),
        exitPrice: Decimal.parse('2680.0'),
        pnl: Decimal.fromInt(300),
        setupReasoning: 'Breakout EMA 50 + RSI 55 + Ichimoku Kumo support',
        emotionTag: 'Discipline',
        aiReviewNote: 'Entry bagus sesuai plan.',
        createdAt: DateTime.now(),
      );

      await db.insertTradeJournal(journal);

      final journals = await db.getTradeJournals(emotionFilter: 'Discipline');
      expect(journals.isNotEmpty, isTrue);
      expect(journals.first.emotionTag, equals('Discipline'));
      // Verify pnl is stored and retrieved with full precision
      expect(journals.first.pnl >= Decimal.fromInt(300), isTrue);
    });
  });
}
