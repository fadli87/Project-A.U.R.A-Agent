import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_trading/aura_trading.dart';

void main() {
  group('MT5 Integration Tests', () {
    test('Mt5AccountInfo.fromJson parses numeric values into Decimal correctly', () {
      final json = {
        'status': 'success',
        'login': 12345678,
        'balance': '10000.50',
        'equity': '10250.75',
        'margin': '200.00',
        'free_margin': '10050.75',
        'currency': 'USD',
        'server': 'ICMarketsSC-Demo',
        'company': 'Raw Trading Ltd',
      };

      final acc = Mt5AccountInfo.fromJson(json);
      expect(acc.login, equals(12345678));
      expect(acc.balance, equals(Decimal.parse('10000.50')));
      expect(acc.equity, equals(Decimal.parse('10250.75')));
      expect(acc.margin, equals(Decimal.parse('200.00')));
      expect(acc.freeMargin, equals(Decimal.parse('10050.75')));
      expect(acc.currency, equals('USD'));
      expect(acc.server, equals('ICMarketsSC-Demo'));
    });

    test('Mt5Position.fromJson parses open position correctly', () {
      final json = {
        'ticket': 987654,
        'symbol': 'XAUUSD',
        'type': 'BUY',
        'volume': '0.10',
        'open_price': '2650.50',
        'current_price': '2665.20',
        'sl': '2630.00',
        'tp': '2690.00',
        'profit': '147.00',
        'time': 1767225600,
      };

      final pos = Mt5Position.fromJson(json);
      expect(pos.ticket, equals(987654));
      expect(pos.symbol, equals('XAUUSD'));
      expect(pos.type, equals('BUY'));
      expect(pos.volume, equals(Decimal.parse('0.10')));
      expect(pos.openPrice, equals(Decimal.parse('2650.50')));
      expect(pos.sl, equals(Decimal.parse('2630.00')));
      expect(pos.profit, equals(Decimal.parse('147.00')));
    });

    test('Mt5OrderRequest.toJson formats volume and price fields as strings', () {
      final req = Mt5OrderRequest(
        symbol: 'EURUSD',
        type: 'BUY',
        volume: Decimal.parse('0.05'),
        stopLoss: Decimal.parse('1.0800'),
        takeProfit: Decimal.parse('1.0950'),
      );

      final json = req.toJson();
      expect(json['symbol'], equals('EURUSD'));
      expect(json['type'], equals('BUY'));
      expect(json['volume'], equals('0.05'));
      expect(json['sl'], equals('1.08'));
      expect(json['tp'], equals('1.095'));
    });

    test('Mt5Client checkHealth returns false when bridge service is offline', () async {
      final client = Mt5Client(baseUrl: 'http://127.0.0.1:59999'); // invalid port
      final isOnline = await client.checkHealth();
      expect(isOnline, isFalse);
    });
  });
}
