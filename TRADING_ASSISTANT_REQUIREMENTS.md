# 📋 [SPESIFIKASI UTAMA] TRADING ASSISTANT REQUIREMENTS

> **Kategori**: Acuan Utama Target Spesifikasi & Requirements Proyek  
> **Status Progress Terkini**: 📊 [TRADING_ASSISTANT_PROGRESS.md](file:///c:/DevApp/AURA_MonoRepo/Project-A.U.R.A-Agent/TRADING_ASSISTANT_PROGRESS.md)  
> **Target User:** Fadli Santoso (solo developer, kembali ke trading Forex/Gold + belajar Saham IDX)  
> **Mode:** Hybrid (local AI + cloud data APIs)  
> **Platforms:** Flutter Mobile (monitoring) + Desktop (analysis lab)  

---


## 🎯 Vision
Sebuah AI Trading Companion yang:
1. **Membantu kembali trading** Forex & Gold dengan confident setelah lama vakum.
2. **Membelajarkan Saham IDX dari nol** dengan pendamping edukatif dan risk-aware.
3. **Selalu menempatkan risk management di atas profit.**
4. **Menggabungkan kekuatan local LLM (offline reasoning) + real-time cloud data.**
5. **UI premium modern:** gradient, glassmorphism, contextual greeting.

---

## 📂 Struktur Monorepo (Perubahan)

```
AURA_MonoRepo/
├── aura_core/                    # ✅ TIDAK DIUBAH (core AI, memory, agent)
│   └── ... (inference, memory, storage, utils)
├── aura_mobile/                  # ✅ EXTEND: tambah fitur trading
│   └── lib/src/features/trading/ # ← BARU
├── aura_desktop/                 # ✅ EXTEND: tambah fitur trading
│   └── lib/src/features/trading/ # ← BARU
├── aura_trading/                 # ← PACKAGE BARU (shared trading logic)
│   ├── lib/
│   │   ├── data/
│   │   │   ├── sources/
│   │   │   │   ├── forex_gold/
│   │   │   │   │   ├── twelve_data_api.dart
│   │   │   │   │   ├── yahoo_finance_api.dart
│   │   │   │   │   ├── investing_com_scraper.dart
│   │   │   │   │   └── finnhub_api.dart
│   │   │   │   ├── idx_stocks/
│   │   │   │   │   ├── twelve_data_api.dart
│   │   │   │   │   ├── yahoo_finance_api.dart
│   │   │   │   │   ├── investing_com_idn.dart
│   │   │   │   │   └── idx_official_scraper.dart
│   │   │   │   ├── news/
│   │   │   │   │   ├── forex_factory_calendar.dart
│   │   │   │   │   ├── investing_com_news.dart
│   │   │   │   │   └── cnbc_indonesia.dart
│   │   │   │   └── unified/
│   │   │   │       └── market_data_repository.dart
│   │   │   ├── local/
│   │   │   │   ├── trading_database.dart
│   │   │   │   └── secure_vault.dart
│   │   │   ├── models/
│   │   │   │   ├── candle.dart
│   │   │   │   ├── order_book.dart
│   │   │   │   ├── position.dart
│   │   │   │   ├── portfolio.dart
│   │   │   │   ├── trade_journal.dart
│   │   │   │   └── strategy.dart
│   │   │   ├── ai/
│   │   │   │   ├── trading_tools.dart
│   │   │   │   ├── prompts/
│   │   │   │   │   └── trading_coach_prompt.dart
│   │   │   │   └── context_builder.dart
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   ├── repositories/
│   │   │   │   └── usecases/
│   │   │   └── presentation/
│   │   │       ├── providers/
│   │   │   │   │   ├── market_data_provider.dart
│   │   │   │   │   ├── portfolio_provider.dart
│   │   │   │   │   ├── signal_provider.dart
│   │   │   │   │   └── risk_provider.dart
│   │   │       ├── widgets/
│   │   │   │   │   ├── candlestick_chart.dart
│   │   │   │   │   ├── indicator_panel.dart
│   │   │   │   │   ├── risk_card.dart
│   │   │   │   │   ├── session_heatmap.dart
│   │   │   │   │   └── economic_calendar_tile.dart
│   │   │       └── screens/
│   │   │           ├── watchlist_screen.dart
│   │   │           ├── chart_screen.dart
│   │   │           ├── trade_journal_screen.dart
│   │   │           ├── paper_trading_screen.dart
│   │   │           └── settings_screen.dart
│   ├── pubspec.yaml
│   └── README.md
├── aura_core/pubspec.yaml        # ✅ TIDAK DIUBAH
├── aura_mobile/pubspec.yaml      # ✅ TAMBAHKAN dependency aura_trading
├── aura_desktop/pubspec.yaml     # ✅ TAMBAHKAN dependency aura_trading
└── TRADING_ASSISTANT_REQUIREMENTS.md  # ← FILE INI
```

---

## 🧩 Komponen Utama

### 1. `aura_trading` (Package Baru)
Berisi logika bisnis trading yang **platform-agnostic**, dapat digunakan oleh mobile & desktop.

#### Sub-packages:
- **`data.sources`**: Implementasi API konkret (TwelveData, Yahoo Finance, scraper).
- **`data.local`**: Penyimpanan lokal (trades, journal, API keys terenkripsi).
- **`data.models`**: Entity data (Candle, Position, Portfolio, Journal).
- **`ai`**: Agent tools untuk trading (`getPrice`, `calcPositionSize`, `getIndicators`).
- **`domain`**: Use case bisnis (analisis, risk management, signal generation).
- **`presentation`**: State management (Riverpod providers) & UI komponen reusable.

### 2. `aura_mobile` & `aura_desktop`
Hanya berisi:
- UI screens (menggunakan komponen dari `aura_trading.presentation.widgets`)
- Platform-specific code (jika ada, seperti background service untuk alert)
- Tidak boleh berisi logika bisnis trading — semuanya di-import dari `aura_trading`.

---

## 🔑 Fitur Utama

### A. Data Layer
- **Unified Market Data Repository** (abstraksi): mudah ganti sumber data tanpa ubah UI.
- **Forex & Gold**: TwelveData (primary), Yahoo Finance (backup), Finnhub (WS backup).
- **IDX Stocks**: TwelveData (covers IDX), Yahoo Finance (backup), scraper Investing.com IDX.
- **Economic Calendar**: Forex Factory (scraper) + Investing.com.
- **Market News**: Investing.com + CNBC Indonesia.
- **Real-time**: WebSocket dari TwelveData/Finnhub untuk price stream.
- **Historical**: Cache CSV/Parquet lokal untuk backtesting.

### B. AI Layer (Memanfaatkan `aura_core`)
- **Local LLM Inference** (GGUF via `aura_core`): reasoning, explanation, coaching.
- **Memory System** (ObjectBox + embeddings): simpan journal, pertukaran AI, pola trading yang dipelajari.
- **Agent Tool Calling**: AI dapat memanggil tools:
  - `get_current_price(symbol: String)`
  - `get_technical_indicators(symbol: String, timeframe: String)`
  - `calculate_position_size(entry: double, sl: double, riskPct: double, equity: double)`
  - `get_market_news(symbol: String)`
  - `get_economic_calendar()`
  - `place_paper_order(...)` (simulasi)
- **Trading Coach Persona**: System prompt yang mengedepankan edukasi, risk management, dan tidak memberikan financial advice langsung.

### C. Trading Features
#### Forex & Gold
- **Session Tracker**: Tokyo/London/New York open/close dengan highlight volatilitas.
- **Correlation Matrix**: DXY vs Gold, USD/JPY vs Nikkei, AUD/USD vs Gold.
- **Swap Calculator**: biaya overnight untuk posisi swing.
- **Spread Monitor**: perbandingan spread broker vs raw spread.

#### Saham IDX
- **Fundamental Screener**: PE, PB, ROE, DER, Div Yield, Market Cap.
- **Foreign Flow Monitor**: netto beli/jual asing harian (data dari scraping atau API unofficial).
- **Sector Heatmap**: visualisasi performa sektor per hari/minggu.
- **IPO & Corporate Action Tracker**: daftar rights issue, stock split, dividend.

#### Unified
- **Paper Trading Mode**: dua akun virtual terpisah (Forex/Gold: $10k, IDX: Rp100jt).
- **Trade Journal dengan AI Review**: setelah setiap trade, AI analisis: "Setup valid? SL/TP sesuai RR? Emosi terdeteksi?"
- **Position Sizing Calculator**: berbasis % risk per trade dan ATR (untuk Forex/Gold) atau volatilitas saham.
- **Risk Dashboard**:
  - Harian: loss limit, max drawdown harian.
  - Korelasi: peringatan jika posisi berkorelasi tinggi (misal: long Gold + long AUD/USD).
  - Exposure: sektor, mata uang, instrumen.

### D. UI/UX (Premium Modern)
- **Theme**: Gradasi warna premium (biru tua → ungu), efek glassmorphism pada kartu.
- **Greeting Contextual**: "Selamat pagi, trader. Siap menganalisis pasar hari ini?"
- **Mobile**:
  - Bottom navigation: Watchlist | Chart | Journal | AI Chat | Settings.
  - Watchlist card: harga, % change 24h, sparkline mini.
  - Chart: fullscreen candlestick dengan indikator toggle (EMA, RSI, MACD, BB).
  - AI Chat: floating action button → bottom sheet.
- **Desktop**:
  - Layout tiga panel: Chart (60%) | Orderbook/Depth (20%) | AI Chat (20%).
  - Dockable panels, multi-timeframe sync.
  - Sidebar: watchlist, economic calendar, risk metrics.
  - Hotkeys: `Ctrl+L` untuk load chart layout, `Ctrl+S` untuk screenshot strategi.

### E. Keamanan & Privasi
- **100% Lokal untuk AI**: reasoning tidak keluar ke cloud kecuali pilihan eksplisit (cloud assistant toggle).
- **Penyimpanan Credentials**: API key broker/Exchange disimpan di `flutter_secure_storage` + enkripsi.
- **Mode Offline**: aplikasi tetap berfungsi untuk analisis dasar dan jurnal tanpa internet (menggunakan data cache).

---

## 🗺️ Roadmap Implementasi (Untuk Antigravity)

### Phase 0: Foundation & Core Data (Estimasi: 2 minggu)
- [ ] Buat package `aura_trading` dengan struktur folder di atas.
- [ ] Implement `TwelveDataClient` (forex/gold/idx) + `YahooFinanceClient` (fallback).
- [ ] Buat `MarketDataRepository` abstraction (interface + implementasi gabungan).
- [ ] Setup Riverpod providers: `marketDataProvider`, `priceStreamProvider`.
- [ ] Buat model: `Candle`, `PriceTicker`.
- [ ] Implement basic watchlist UI di `aura_mobile` & `aura_desktop` (menggunakan komponen shared dari `aura_trading.presentation.widgets`).

### Phase 1: AI Coach & Analysis Tools (Estimasi: 2 minggu)
- [ ] Implement `TradingTools` di `aura_trading/lib/ai/trading_tools.dart`:
  - `getCurrentPrice`, `getTechnicalIndicators` (RSI, MACD, EMA, BB, ATR)
  - `calculatePositionSizeForex`, `calculatePositionSizeStock`
  - `getEconomicCalendar`, `getMarketNews`
- [ ] Buat `trading_coach_prompt.dart` dengan system prompt edukatif & risk-aware.
- [ ] Integrasi ke `InferenceProvider` (sudah ada di `aura_core`) → tambah mode "Trading Coach".
- [ ] Buat layar chart dasar dengan `fl_chart`: candlestick + volume + indikator toggle.
- [ ] Tambah fitur AI chat yang bisa memanggil `TradingTools` melalui agent tool calling.

### Phase 2: Paper Trading & Journal (Estimasi: 2 minggu)
- [ ] Buat `TradingDatabase` (ObjectBox/SQLite) untuk:
  - Virtual accounts (forex_gold_paper, idx_paper)
  - Paper trades (entry, exit, sl, tp, timestamp, pnl)
  - Trade journal (setup reasoning, emotion tag, AI review)
  - API keys terenkripsi (secure vault)
- [ ] Implement paper trading engine: simulated fill, P&L calculation.
- [ ] Buat layar Trade Journal dengan fitur:
  - Tambah/edit jurnal
  - AI review button: menganalisis jurnal terakhir dengan prompt khusus
  - Filter: berdasarkan aset, profit/loss, emosi
- [ ] Buat Risk Dashboard:
  - Harian: P&L harian, loss limit status
  - Korelasi: heatmap korelasi posisi terbuka
  - Peringatan: jika melebihi risk limit harian/mingguan

### Phase 3: Advanced Features (Desktop Focus) (Estimasi: 3 minggu)
- [ ] Buat modul backtesting:
  - Loader historical CSV/Parquet dari cache TwelveData/Yahoo
  - Strategy engine sederhana (rule-based: "RSI < 30 AND EMA20 > EMA50")
  - Backtest runner dengan metrik: Win Rate, Profit Factor, Sharpe, Max DD
  - Equity curve drawdown chart
- [ ] Buat strategy builder UI (desktop):
  - Drag & drop condition blocks (indikator, price action, time)
  - Generate kode strategy sederhana atau parameter untuk backtest
- [ ] Buat macro dashboard (desktop):
  - Widget: BI Rate, Inflasi AS/IDR, USD/IDR, harga komoditas (minyak, emas, nickel, CPO)
  - Korelasi otomatis ke sektor IDX dan pasangan Forex
- [ ] Buat economic calendar UI dengan warna kemimpinan (red/orange/yellow) + penjelasan AI dampak.

### Phase 4: Polishing & Prep for Live (Opsional)
- [ ] Implement alert system (push notification + in-app) untuk:
  - Price breakout/breakdown
  - Economic calendar event mulai dalam 15 menit
  - Signal AI muncul (jika diaktifkan)
  - Risk limit hampir tercapai
- [ ] Persiapan untuk live trading nanti:
  - Buat abstraction untuk broker API (IC Markets FIX/REST, Bibit/Stockbit unofficial API)
  - Tambah mode "Live Trading" dengan konfirmasi multi-layer dan simulasi dulu.
- [ ] Buat laporan minggan otomatis (PDF) yang bisa dikirim ke email: P&L, jurnal highlights, risiko observasi.

---

## 📦 Dependencies Baru (untuk `aura_trading/pubspec.yaml`)

```yaml
name: aura_trading
description: Shared trading logic for AURA (Forex/Gold & IDX)
version: 0.1.0
environment:
  sdk: '>=3.12.2 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  aura_core:
    path: ../aura_core
  flutter_riverpod: ^3.0.0
  riverpod_annotation: ^4.0.0
  http: ^1.2.0
  web_socket_channel: ^3.0.0
  fl_chart: ^0.69.0
  sqlite3: ^2.4.0
  sqlite3_flutter_libs: ^0.5.24
  path: ^1.9.1
  intl: ^0.19.0
  json_annotation: ^4.12.0
  crypto: ^3.0.3
  pointycastle: ^4.0.0
  collection: ^1.18.0
  equatable: ^2.0.5
  # Optional: for HTML parsing (scraper)
  html: ^0.15.4
  # Optional: for secure storage
  flutter_secure_storage: ^11.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.4.0
  riverpod_generator: ^4.0.0
  json_serializable: ^6.8.0
  test: ^1.24.0
```

---

## 🧭 Catatan Teknis untuk Antigravity

1. **Tidak boleh modify `aura_core`** kecuali bug fix bersama saya.
2. **Semua logika bisnis trading** harus di `aura_trading` — UI hanya konsumsi via providers dan widget reusable.
3. **Gunakan Riverpod + code generator** untuk state management (seperti yang sudah ada di `aura_mobile`).
4. **Implementasikan caching agar aplikasi cepat saat membuka** (simpan last data di local storage atau ObjectBox).
5. **Error handling yang baik**: jika API gagal, tampilkan data terakhir yang diketahui + label "Data mungkin tidak terkini".
6. **Respek rate limit API gratis**: implementasikan exponential backoff dan cache agresif.
7. **Untuk scraper**: gunakan `package:http` + `package:html` dengan delay acak antara request (1-2 detik) untuk menghindari blokir.
8. **Secure Storage**: API key dan credentional harus disimpan di `flutter_secure_storage` — **tidak boleh disimpan sebagai plain text**.
9. **Testing**: tulis unit test untuk:
   - Market data repository (mock API response)
   - Position sizing calculator
   - Technical indicator functions (bandingkan dengan TradingView)
10. **Dokumentasi tiap fungsi** dengan contoh penggunaan dan expected output.

---

## ✅ Kriteria Selesai
Aplikasi dapat:
1. Menampilkan harga real-time Forex/Gold/IDX dengan candle chart.
2. Menjalankan AI chat yang bisa menjawab:
   - "Apa itu RSI dan bagaimana cara membacanya?"
   - "Bagaimana cara menghitung posisi size untuk XAU/USD dengan risk 2%?"
   - "Jelaskan apa efek NFP ke USD/IDR dan korelasinya ke saham perbankan."
3. Mencatat trade (paper) dan mendapatkan review AI setelah penutupan posisi.
4. Menampilkan risk dashboard dengan peringatan jika over-exposure.
5. Bekerja secara offline untuk melihat data cache dan jurnal.
6. UI terasa premium: gradasi, glassmorphism, animasi halus, sapaan kontekstual sesuai waktu.

--- 
*Document ini adalah single source of truth untuk pengembangan AURA Trading Assistant. Perubahan harus disepakati bersama melalui diskusi dengan Shin dan Claude Desktop sebelum diimplementasikan oleh Antigravity.*