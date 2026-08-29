// Main entry point for aura_trading package.
// Exports data models, repositories, indicators, AI tools, providers, and shared widgets.

export 'data/models/candle.dart';
export 'data/models/price_ticker.dart';
export 'data/models/position.dart';
export 'data/models/trade_journal.dart';

export 'data/sources/yahoo_finance_api.dart';
export 'data/sources/twelve_data_api.dart';
export 'data/sources/unified/market_data_repository.dart';

export 'domain/indicators.dart';
export 'domain/position_sizer.dart';

export 'ai/prompts/trading_coach_prompt.dart';
export 'ai/trading_tools.dart';

export 'presentation/providers/market_data_provider.dart';
export 'presentation/widgets/candlestick_chart.dart';
export 'presentation/widgets/watchlist_tile.dart';
export 'presentation/widgets/risk_card.dart';
export 'presentation/widgets/session_heatmap.dart';
