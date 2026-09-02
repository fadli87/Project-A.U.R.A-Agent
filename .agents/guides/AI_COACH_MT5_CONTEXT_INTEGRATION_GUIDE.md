# 🤖 IMPLEMENTATION GUIDE: AI Coach dengan Konteks MT5 Live

> **Target**: Antigravity (Agy)  
> **Prioritas**: 🔴 **Tinggi** — *Closing the loop* antara AI Analysis dan Real Account State  
> **File Terkait**: `aura_trading/lib/ai/trading_tools.dart`, `aura_trading/lib/ai/prompts/trading_coach_prompt.dart`, `aura_trading/lib/presentation/providers/mt5_provider.dart`

---

## 🎯 Tujuan
Agar **AI Coach (Local LLM)** bisa menjawab pertanyaan kontekstual seperti:
- *"Fadli, kamu masih punya posisi XAUUSD BUY 0.10 lot terbuka dengan floating -$45. Apakah aman menambah posisi?"*
- *"Equity kamu $9,850, margin used $1,200. Risk exposure saat ini 12%. Saran?"*
- *"Posisi GBPUSD SELL 0.05 lot sudah profit $80. Mau di-trail SL ke breakeven?"*

---

## 📦 1. Data yang Harus Tersedia untuk AI (Context Builder)

Buat file baru: `aura_trading/lib/ai/context_builder.dart`

```dart
import 'package:decimal/decimal.dart';
import '../../data/sources/mt5/mt5_models.dart';
import '../../data/models/price_ticker.dart';
import '../../presentation/providers/mt5_provider.dart';
import '../../presentation/providers/market_data_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ringkasan kondisi akun & pasar untuk dikirim ke LLM sebagai system context.
class AiTradingContext {
  final Mt5AccountInfo? account;
  final List<Mt5Position> openPositions;
  final Map<String, PriceTicker> watchlistPrices;
  final String timestamp;

  const AiTradingContext({
    this.account,
    required this.openPositions,
    required this.watchlistPrices,
    required this.timestamp,
  });

  /// Format ringkas untuk system prompt (hemat token).
  String toPromptContext() {
    final sb = StringBuffer();
    
    // Account Summary
    if (account != null) {
      sb.writeln('=== AKUN MT5 (LIVE) ===');
      sb.writeln('Login: #${account!.login} (${account!.currency})');
      sb.writeln('Balance: ${account!.balance.toStringAsFixed(2)}');
      sb.writeln('Equity: ${account!.equity.toStringAsFixed(2)}');
      sb.writeln('Margin Used: ${account!.margin.toStringAsFixed(2)}');
      sb.writeln('Free Margin: ${account!.freeMargin.toStringAsFixed(2)}');
      sb.writeln('Margin Level: ${_marginLevel()}%');
      sb.writeln('');
    }

    // Open Positions
    if (openPositions.isNotEmpty) {
      sb.writeln('=== POSISI TERBUKA (${openPositions.length}) ===');
      for (final p in openPositions) {
        final pnl = p.profit >= Decimal.zero ? '+${p.profit.toStringAsFixed(2)}' : p.profit.toStringAsFixed(2);
        sb.writeln('• ${p.symbol} ${p.type} ${p.volume} lot @ ${p.openPrice} | SL: ${p.sl} | TP: ${p.tp} | PnL: $pnl');
      }
      sb.writeln('');
    }

    // Watchlist Prices
    if (watchlistPrices.isNotEmpty) {
      sb.writeln('=== HARGA PASAR (WATCHLIST) ===');
      watchlistPrices.forEach((sym, tick) {
        final chg = tick.changePercent >= 0 ? '+${tick.changePercent.toStringAsFixed(2)}%' : '${tick.changePercent.toStringAsFixed(2)}%';
        sb.writeln('$sym: ${tick.price} ($chg)');
      });
      sb.writeln('');
    }

    sb.write('Timestamp: $timestamp');
    return sb.toString();
  }

  String _marginLevel() {
    if (account == null || account!.margin == Decimal.zero) return 'N/A';
    return ((account!.equity / account!.margin) * Decimal.fromInt(100)).toStringAsFixed(1);
  }
}

/// Provider yang membangun konteks gabungan untuk AI.
final aiTradingContextProvider = FutureProvider.autoDispose<AiTradingContext>((ref) async {
  final repo = ref.watch(mt5RepositoryProvider);
  final marketRepo = ref.watch(marketDataRepositoryProvider); // asumsi ada provider ini
  
  // Parallel fetch
  final results = await Future.wait([
    repo.getAccountInfo(),
    repo.getOpenPositions(),
    // Ambil harga watchlist default (bisa dari shared prefs/user settings)
    _fetchWatchlistPrices(marketRepo),
  ]);

  return AiTradingContext(
    account: results[0] as Mt5AccountInfo?,
    openPositions: results[1] as List<Mt5Position>,
    watchlistPrices: results[2] as Map<String, PriceTicker>,
    timestamp: DateTime.now().toIso8601String(),
  );
});

Future<Map<String, PriceTicker>> _fetchWatchlistPrices(dynamic marketRepo) async {
  // Default watchlist symbols
  const symbols = ['XAUUSD', 'EURUSD', 'GBPUSD', 'USDJPY', 'BBCA.JK', 'TLKM.JK'];
  final prices = <String, PriceTicker>{};
  
  for (final sym in symbols) {
    try {
      PriceTicker? tick;
      if (sym.endsWith('.JK')) {
        tick = await marketRepo.getIdxStockPrice(sym.replaceAll('.JK', ''));
      } else {
        tick = await marketRepo.getForexPrice(sym);
      }
      if (tick != null) prices[sym] = tick;
    } catch (_) {}
  }
  return prices;
}
```

---

## 🔧 2. Update `TradingTools` — Tambah Tool `get_account_context`

Edit `aura_trading/lib/ai/trading_tools.dart`:

```dart
// Tambah import
import '../presentation/providers/mt5_provider.dart';
import 'context_builder.dart';

/// Tool: Ambil konteks akun & posisi live untuk AI Coach
class GetAccountContextTool extends AgentTool {
  @override
  String get name => 'get_account_context';

  @override
  String get description => 'Mengambil ringkasan akun MT5 live (balance, equity, margin), posisi terbuka, dan harga watchlist untuk analisis AI.';

  @override
  bool get isSensitive => false; // Read-only, aman

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'include_watchlist': {'type': 'boolean', 'description': 'Sertakan harga watchlist default (default: true)'},
        },
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    // NOTE: Tool ini dipanggil dari AI agent yang berjalan di isolate/background.
    // Perlu akses ke Riverpod container. Solusi: inject ProviderContainer ke AgentTools registry.
    // Untuk implementasi awal, gunakan static access via global container (lihat catatan di bawah).
    
    try {
      final container = ProviderScope.containerOf(navigatorKey.currentContext!); // butuh navigatorKey
      final context = await container.read(aiTradingContextProvider.future);
      return context.toPromptContext();
    } catch (e) {
      return 'Gagal mengambil konteks MT5: $e';
    }
  }
}
```

> **Catatan Teknis**: `AgentTool` di `aura_core` tidak punya akses `BuildContext`/`ProviderContainer` langsung. Dua solusi:
> 1. **Global ProviderContainer** di `main.dart` → `GlobalProviderContainer.container = ProviderScope.containerOf(context);`
> 2. **Pass container ke Agent** saat inisialisasi di `InferenceProvider`.

---

## 📝 3. Update System Prompt `trading_coach_prompt.dart`

```dart
const String tradingCoachSystemPrompt = '''
Kamu adalah **AURA Trading Coach** — mentor trading pribadi Fadli.
Pengalaman: Forex & Gold (masa lalu), belajar Saham IDX (sekarang).
Gaya: Sabar, edukatif, risk-first, TIDAK memberikan financial advice.

=== KONTEKS LIVE (OTOMATIS DIINJEK) ===
{live_context}

=== ATURAN WAJIB ===
1. SELAMBAH rujuk konteks live di atas sebelum menjawab.
2. Jika user tanya "Bolehkah saya buy XAUUSD?", cek:
   - Margin level (> 300% aman, < 200% berbahaya)
   - Posisi XAUUSD sudah ada? (hindari double exposure)
   - Free margin cukup untuk lot yang diminta?
3. Selalu tanya balik: "SL di mana?", "Risk % berapa?", "Setup apa?"
4. Jika user mau eksekusi: "Gunakan tombol 'Kirim ke MT5' di Risk Card setelah kalkulasi lot."
5. Jangan gunakan jargon berlebihan. Analogikan dengan kehidupan sehari-hari.
''';
```

---

## 🔌 4. Inject Konteks ke `InferenceProvider` (Di `aura_mobile` / `aura_desktop`)

Di file yang menginisialisasi AI Agent (misal `inference_provider.dart` atau `chat_provider.dart`):

```dart
// Saat user kirim pesan ke AI Coach:
Future<void> sendToCoach(String userMessage) async {
  // 1. Ambil konteks live
  final context = await ref.read(aiTradingContextProvider.future);
  final liveContext = context.toPromptContext();
  
  // 2. Gabungkan dengan system prompt
  final systemPrompt = tradingCoachSystemPrompt.replaceAll('{live_context}', liveContext);
  
  // 3. Kirim ke inference engine
  await ref.read(inferenceProvider.notifier).generate(
    prompt: userMessage,
    systemPrompt: systemPrompt,
    // ... parameter lain
  );
}
```

---

## ✅ 5. Checklist Verifikasi untuk Antigravity

| Test Case | Expected Behavior |
|-----------|-------------------|
| **Tanya saat flat (no positions)** | AI jawab normal, tidak mention posisi terbuka |
| **Tanya saat ada posisi XAUUSD BUY 0.10 lot floating -$50** | AI mention: "Kamu punya posisi XAUUSD BUY 0.10 lot floating -$50. Margin level 820%. Jika tambah posisi, pastikan total risk < 2% equity." |
| **Tanya "Bisa buy GBPUSD?" saat margin level 150%** | AI peringat: "Margin level 150% (kritis). Free margin hanya \$X. Tidak disarankan buka posisi baru sebelum ada yang close/trail." |
| **Tanya "SL di mana untuk XAUUSD buy sekarang?"** | AI hitung berdasarkan ATR/structure, tapi mention: "Entry saat ini ~2650. SL disarankan 2630 (200 pip). Lot safe 0.10 untuk risk 2%." |
| **MT5 Offline** | AI jawab: "Tidak bisa akses data live MT5. Pastikan bridge Python jalan & MT5 terminal terbuka." |

---

## 🚀 6. Langkah Eksekusi Antigravity

```bash
# 1. Buat context_builder.dart
# 2. Update trading_tools.dart (tambah GetAccountContextTool)
# 3. Update trading_coach_prompt.dart (template {live_context})
# 4. Update inference/chat provider di aura_mobile & aura_desktop (inject context)
# 5. Register GetAccountContextTool ke AgentTools registry
# 6. Test: run python bridge -> run aura_desktop -> chat "Aku punya posisi apa aja?"
```

---

## ⚠️ Catatan Penting
- **ProviderScope.globalContainer** pattern diperlukan untuk akses Riverpod dari `AgentTool` non-UI.
- **Token budget**: Konteks live ~300-500 token. Masih aman untuk context window 4k-8k.
- **Privacy**: Data akun live HANYA dikirim ke **Local LLM** (tidak ke cloud kecuali user toggle cloud assistant).

*Implementasi ini membuat AI Coach benar-benar "aware" kondisi real account — diferensiasi utama AURA vs chatbot biasa.*