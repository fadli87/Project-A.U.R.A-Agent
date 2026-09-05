import 'package:decimal/decimal.dart';
import 'price_ticker.dart';

/// Represents a trading journal entry with emotions, setup reasoning, and AI feedback.
/// Follows Prinsip 1: All prices and PnL use [Decimal].
class TradeJournal {
  final String id;
  final String symbol;
  final AssetCategory category;
  final String action; // 'BUY' or 'SELL'
  final Decimal entryPrice;
  final Decimal exitPrice;
  final Decimal pnl;
  final String setupReasoning;
  final String emotionTag;
  final String? aiReviewNote;
  final DateTime createdAt;

  String get tradeType => action;
  String? get aiReview => aiReviewNote;

  TradeJournal({
    required this.id,
    required this.symbol,
    this.category = AssetCategory.forex,
    required this.action,
    required this.entryPrice,
    required this.exitPrice,
    required this.pnl,
    required this.setupReasoning,
    required this.emotionTag,
    this.aiReviewNote,
    required this.createdAt,
  });

  factory TradeJournal.fromJson(Map<String, dynamic> json) {
    return TradeJournal(
      id: json['id']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      category: AssetCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => AssetCategory.forex,
      ),
      action: json['action']?.toString() ?? json['trade_type']?.toString() ?? 'BUY',
      entryPrice: Decimal.parse(json['entry_price']?.toString() ?? '0'),
      exitPrice: Decimal.parse(json['exit_price']?.toString() ?? '0'),
      pnl: Decimal.parse(json['pnl']?.toString() ?? '0'),
      setupReasoning: json['setup_reasoning']?.toString() ?? '',
      emotionTag: json['emotion_tag']?.toString() ?? 'Discipline',
      aiReviewNote: json['ai_review']?.toString() ?? json['ai_review_note']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'category': category.name,
      'action': action,
      'entry_price': entryPrice.toString(),
      'exit_price': exitPrice.toString(),
      'pnl': pnl.toString(),
      'setup_reasoning': setupReasoning,
      'emotion_tag': emotionTag,
      'ai_review': aiReviewNote,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
