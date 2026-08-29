import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../models/position.dart';
import '../../models/price_ticker.dart';
import '../../models/trade_journal.dart';

class TradingDatabase {
  static TradingDatabase? _instance;
  Database? _db;

  TradingDatabase._();

  static TradingDatabase get instance {
    _instance ??= TradingDatabase._();
    return _instance!;
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    String dbPath;
    try {
      final docsDir = await getApplicationSupportDirectory();
      dbPath = p.join(docsDir.path, 'aura_trading.db');
    } catch (_) {
      dbPath = 'aura_trading.db';
    }

    final db = sqlite3.open(dbPath);
    _createTables(db);
    _seedDefaultAccounts(db);
    return db;
  }

  void _createTables(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS virtual_accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL,
        equity REAL NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS paper_trades (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        symbol TEXT NOT NULL,
        category TEXT NOT NULL,
        type TEXT NOT NULL,
        entry_price REAL NOT NULL,
        exit_price REAL,
        stop_loss REAL,
        take_profit REAL,
        lots REAL NOT NULL,
        pnl REAL NOT NULL,
        status TEXT NOT NULL,
        open_time TEXT NOT NULL,
        close_time TEXT
      );
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS trade_journals (
        id TEXT PRIMARY KEY,
        symbol TEXT NOT NULL,
        category TEXT NOT NULL,
        trade_type TEXT NOT NULL,
        entry_price REAL NOT NULL,
        exit_price REAL NOT NULL,
        pnl REAL NOT NULL,
        setup_reasoning TEXT NOT NULL,
        emotion_tag TEXT NOT NULL,
        ai_review TEXT,
        created_at TEXT NOT NULL
      );
    ''');
  }

  void _seedDefaultAccounts(Database db) {
    final result = db.select('SELECT COUNT(*) as count FROM virtual_accounts');
    final count = result.first['count'] as int;
    if (count == 0) {
      final now = DateTime.now().toIso8601String();
      db.execute(
        'INSERT INTO virtual_accounts (id, name, type, balance, equity, created_at) VALUES (?, ?, ?, ?, ?, ?)',
        ['forex_gold_paper', 'Virtual Account Forex & Gold', 'forex', 10000.0, 10000.0, now],
      );
      db.execute(
        'INSERT INTO virtual_accounts (id, name, type, balance, equity, created_at) VALUES (?, ?, ?, ?, ?, ?)',
        ['idx_paper', 'Virtual Account Saham IDX', 'idxStock', 100000000.0, 100000000.0, now],
      );
    }
  }

  // --- Virtual Accounts CRUD ---
  Future<Map<String, dynamic>?> getAccount(String accountId) async {
    final db = await database;
    final stmt = db.prepare('SELECT * FROM virtual_accounts WHERE id = ?');
    final result = stmt.select([accountId]);
    stmt.dispose();
    if (result.isEmpty) return null;
    final row = result.first;
    return {
      'id': row['id'],
      'name': row['name'],
      'type': row['type'],
      'balance': row['balance'] as double,
      'equity': row['equity'] as double,
      'created_at': row['created_at'],
    };
  }

  Future<void> updateAccountBalance(String accountId, double balance, double equity) async {
    final db = await database;
    final stmt = db.prepare('UPDATE virtual_accounts SET balance = ?, equity = ? WHERE id = ?');
    stmt.execute([balance, equity, accountId]);
    stmt.dispose();
  }

  // --- Paper Trades CRUD ---
  Future<void> insertPaperTrade(Map<String, dynamic> trade) async {
    final db = await database;
    final stmt = db.prepare('''
      INSERT INTO paper_trades 
      (id, account_id, symbol, category, type, entry_price, exit_price, stop_loss, take_profit, lots, pnl, status, open_time, close_time)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      trade['id'],
      trade['account_id'],
      trade['symbol'],
      trade['category'],
      trade['type'],
      trade['entry_price'],
      trade['exit_price'],
      trade['stop_loss'],
      trade['take_profit'],
      trade['lots'],
      trade['pnl'],
      trade['status'],
      trade['open_time'],
      trade['close_time'],
    ]);
    stmt.dispose();
  }

  Future<List<Map<String, dynamic>>> getOpenPaperTrades(String accountId) async {
    final db = await database;
    final stmt = db.prepare('SELECT * FROM paper_trades WHERE account_id = ? AND status = ? ORDER BY open_time DESC');
    final result = stmt.select([accountId, 'OPEN']);
    stmt.dispose();
    return result.map((row) => {
      'id': row['id'],
      'account_id': row['account_id'],
      'symbol': row['symbol'],
      'category': row['category'],
      'type': row['type'],
      'entry_price': row['entry_price'] as double,
      'exit_price': row['exit_price'] as double?,
      'stop_loss': row['stop_loss'] as double?,
      'take_profit': row['take_profit'] as double?,
      'lots': row['lots'] as double,
      'pnl': row['pnl'] as double,
      'status': row['status'],
      'open_time': row['open_time'],
      'close_time': row['close_time'],
    }).toList();
  }

  Future<void> updatePaperTradeStatus(String tradeId, String status, double exitPrice, double pnl, String closeTime) async {
    final db = await database;
    final stmt = db.prepare('UPDATE paper_trades SET status = ?, exit_price = ?, pnl = ?, close_time = ? WHERE id = ?');
    stmt.execute([status, exitPrice, pnl, closeTime, tradeId]);
    stmt.dispose();
  }

  // --- Trade Journals CRUD ---
  Future<void> insertTradeJournal(TradeJournal journal) async {
    final db = await database;
    final stmt = db.prepare('''
      INSERT INTO trade_journals
      (id, symbol, category, trade_type, entry_price, exit_price, pnl, setup_reasoning, emotion_tag, ai_review, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      journal.id,
      journal.symbol,
      journal.category.name,
      journal.tradeType,
      journal.entryPrice,
      journal.exitPrice,
      journal.pnl,
      journal.setupReasoning,
      journal.emotionTag,
      journal.aiReview,
      journal.createdAt.toIso8601String(),
    ]);
    stmt.dispose();
  }

  Future<List<TradeJournal>> getTradeJournals({String? emotionFilter, String? symbolFilter}) async {
    final db = await database;
    String sql = 'SELECT * FROM trade_journals';
    final params = <dynamic>[];
    final conditions = <String>[];

    if (emotionFilter != null && emotionFilter.isNotEmpty && emotionFilter != 'ALL') {
      conditions.add('emotion_tag = ?');
      params.add(emotionFilter);
    }
    if (symbolFilter != null && symbolFilter.isNotEmpty && symbolFilter != 'ALL') {
      conditions.add('symbol = ?');
      params.add(symbolFilter);
    }

    if (conditions.isNotEmpty) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }
    sql += ' ORDER BY created_at DESC';

    final stmt = db.prepare(sql);
    final result = stmt.select(params);
    stmt.dispose();

    final list = <TradeJournal>[];
    for (final row in result) {
      final catStr = row['category'] as String;
      final category = AssetCategory.values.firstWhere(
        (c) => c.name == catStr,
        orElse: () => AssetCategory.forex,
      );
      list.add(TradeJournal(
        id: row['id'] as String,
        symbol: row['symbol'] as String,
        category: category,
        action: row['trade_type'] as String,
        entryPrice: row['entry_price'] as double,
        exitPrice: row['exit_price'] as double,
        pnl: row['pnl'] as double,
        setupReasoning: row['setup_reasoning'] as String,
        emotionTag: row['emotion_tag'] as String,
        aiReviewNote: row['ai_review'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      ));
    }
    return list;
  }

  Future<void> updateJournalAiReview(String journalId, String aiReview) async {
    final db = await database;
    final stmt = db.prepare('UPDATE trade_journals SET ai_review = ? WHERE id = ?');
    stmt.execute([aiReview, journalId]);
    stmt.dispose();
  }

  void close() {
    _db?.dispose();
    _db = null;
  }
}
