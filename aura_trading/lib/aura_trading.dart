// Main entry point for aura_trading package.
// Exports data models, repositories, indicators, AI tools, providers, and shared widgets.

export 'package:decimal/decimal.dart';

export 'data/models/candle.dart';
export 'data/models/price_ticker.dart';
export 'data/models/position.dart';
export 'data/models/trade_journal.dart';
export 'data/models/strategy.dart';
export 'data/models/backtest_result.dart';

export 'data/sources/yahoo_finance_api.dart';
export 'data/sources/twelve_data_api.dart';
export 'data/sources/local/trading_database.dart';
export 'data/sources/unified/market_data_repository.dart';
export 'data/sources/mt5/mt5_models.dart';
export 'data/sources/mt5/mt5_client.dart';
export 'data/sources/mt5/mt5_repository.dart';

export 'domain/indicators.dart';
export 'domain/position_sizer.dart';
export 'domain/paper_trading_engine.dart';
export 'domain/strategy_backtester.dart';

export 'ai/prompts/trading_coach_prompt.dart';
export 'ai/trading_tools.dart';
export 'ai/context_builder.dart';

export 'presentation/providers/market_data_provider.dart';
export 'presentation/providers/mt5_provider.dart';
export 'presentation/widgets/candlestick_chart.dart';
export 'presentation/widgets/watchlist_tile.dart';
export 'presentation/widgets/risk_card.dart';
export 'presentation/widgets/session_heatmap.dart';
export 'presentation/widgets/trade_journal_widget.dart';
export 'presentation/widgets/risk_dashboard_widget.dart';
export 'presentation/widgets/equity_curve_chart.dart';
export 'presentation/widgets/backtest_panel_widget.dart';
export 'presentation/widgets/mt5_order_dialog.dart';
export 'presentation/widgets/mt5_positions_widget.dart';
export 'presentation/widgets/mt5_status_bar.dart';
