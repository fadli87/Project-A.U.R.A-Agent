# 📖 [PANDUAN PENGGUNA] AURA TRADING ASSISTANT USER GUIDE

> **AURA Trading Assistant** — Pendamping AI Trading Berbasis *Risk-First* untuk **Forex**, **Gold (XAU/USD)**, dan **Saham IDX**.  
> *Lokasi Berkas*: Root Project (`Project-A.U.R.A-Agent/TRADING_ASSISTANT_USER_GUIDE.md`)  
> *Terakhir diperbarui*: 1 September 2026

---

## 🎯 1. Pendahuluan & Visi Utama

AURA Trading Assistant didesain khusus sebagai pendamping trading pribadi yang:
1. **Mengutamakan Manajemen Risiko di Atas Profit**: Membantu menghitung ukuran Lot aman secara presisi sebelum transaksi.
2. **Edukatif & Non-Preskriptif**: Menjelaskan konsep teknikal & fundamental tanpa memberikan nasihat finansial buta.
3. **Presisi Finansial Mutlak (`Decimal`)**: Menggunakan aritmatika presisi arbitrary-precision (`Decimal`) untuk menghindarkan kerugian akibat *floating-point rounding errors*.
4. **Anti-Spekulasi AI**: AI Coach hanya menganalisis berdasarkan data pasar real-time dari alat bantu (*tool-calling*) resmi.

---

## 🏗️ 2. Struktur Arsitektur Monorepo

Sistem dibangun secara **Modular Clean Architecture**:

```
Project-A.U.R.A-Agent/
├── aura_core/         # Core AI Agent, LLM inference engine (GGUF/Ollama), memory (ObjectBox).
├── aura_trading/      # Package Shared Trading: Models, Indicators, Position Sizer, Backtester, Shared UI.
├── aura_desktop/      # Aplikasi Windows Desktop (Flutter): UI 3-Panel Trading Lab.
└── aura_mobile/       # Aplikasi Android Mobile (Flutter): Mobile Trading Dashboard.
```

---

## 💻 3. Panduan Penggunaan AURA Desktop Trading Lab (`aura_desktop`)

Jalankan aplikasi desktop dengan perintah:
```bash
cd aura_desktop
flutter run -d windows
```
Di navigasi atas aplikasi, pilih tab **"📈 Trading Lab"**.

![Layout 3-Panel Trading Lab](https://placeholder.local/trading_lab_overview)

### 🔹 Panel 1: Interactive Chart & Indikator Teknikal *(Kiri — 55% Screen)*
* **Candlestick Chart (`fl_chart`)**: Memantau grafik harga aset aktif.
* **Timeframe Selector**: Pilih skala waktu `15M` (15 Menit), `1H` (1 Jam), atau `1D` (1 Hari) di bagian header atas.
* **Global Session Heatmap**: Status jam buka pasar dunia (Tokyo: 00-09 UTC, London: 08-17 UTC, New York: 13-22 UTC).
* **Summary Bar Indikator**:
  * **EMA 20/50**: Menunjukkan arah tren (EMA 20 di atas EMA 50 = Tren Naik / *Bullish*).
  * **RSI (14)**: Mengukur kejenuhan pasar (<30 = *Oversold*, >70 = *Overbought*).
  * **MACD (12, 26, 9)**: Mengukur momentum pergerakan tren.
  * **Ichimoku Kinko Hyo**: Memantau posisi harga terhadap Awan Kumo (*Tenkan*, *Kijun*, *Senkou A/B*, *Chikou*).

---

### 🔹 Panel 2: Watchlist, Jurnal & Risk Dashboard *(Tengah — 25% Screen)*

Panel tengah memiliki **Tab Switcher** dengan 3 layar interaktif:

#### 1. Tab Watchlist
* Memantau daftar harga real-time instrumen favorit:
  * **Forex**: `EUR/USD`, `GBP/USD`, `USD/JPY`
  * **Gold**: `XAU/USD`
  * **Saham IDX**: `BBCA`, `BBRI`, `TLKM`, `ASII`
* Memiliki *automatic failover* dari Yahoo Finance ke TwelveData dan fallback in-memory cache.
* Klik salah satu aset untuk mengganti tampilan Chart di Panel Kiri.

#### 2. Tab Jurnal Trading
* Mencatat histori simulasi transaksi (*Paper Trade*).
* **Cara Catat Jurnal**:
  1. Klik tombol **"Catat Jurnal"**.
  2. Isi instrumen, jenis transaksi (`BUY`/`SELL`), harga entry, harga exit, dan **Tag Emosi** yang Anda rasakan (`Discipline`, `FOMO`, `Revenge`, `Fear`).
  3. Klik **"Simpan Jurnal"**.
* **Fitur AI Review**: Klik tombol **"AI Review"** pada kartu jurnal. AI Coach akan menganalisis psikologi trading Anda secara otomatis (misal: memberikan peringatan jika Anda terkena emosi *FOMO* atau *Revenge*).

#### 3. Tab Dashboard & Strategy Backtester
* **Daily Risk Dashboard**: Menampilkan saldo *Balance*, *Equity*, *Floating P/L*, dan spanduk peringatan jika kerugian harian melebihi batas 3% (*Max Daily Drawdown Alert*).
* **Strategy Backtester & Equity Curve**:
  1. Pilih jenis strategi:
     * **EMA Cross**: Sinyal beli saat EMA cepat menyilang di atas EMA lambat.
     * **RSI Mean**: Sinyal beli saat RSI berada di area *Oversold* (<30).
  2. Masukkan parameter (saldo awal, risk %, periode EMA/RSI).
  3. Klik **"Jalankan Backtest"**.
  4. Periksa hasil statistik: **Win Rate %**, **Profit Factor**, **Max Drawdown %**, serta grafik **Equity Curve** interaktif.

---

### 🔹 Panel 3: AI Trading Coach Panel *(Kanan — 20% Screen)*

Pendamping AI interaktif berbasis *Risk-First*. Anda dapat menggunakan perintah kata kunci atau berdiskusi bebas:

| Kata Kunci | Respon AI Coach |
| :--- | :--- |
| **`harga`** / **`price`** | Menampilkan quote harga real-time aset aktif. |
| **`indikator`** / **`rsi`** | Menampilkan analisis lengkap RSI, MACD, Ichimoku, dan EMA. |
| **`lot`** / **`risk`** | Menjalankan kalkulator Lot presisi sesuai toleransi risiko modal. |
| **`backtest`** / **`strategi`** | Memberikan panduan pengujian strategi trading di Middle Panel. |
| **Sapaan / Percakapan** | Merespons salam (*"halo"*, *"pagi"*) atau konfirmasi (*"ok"*, *"terima kasih"*) secara ramah & alami. |

> **💡 Diskusi Bebas dengan Local LLM**: Aktifkan Server LLM Lokal (Ollama / LM Studio / llama-server) di tab **AI Chat**, maka AI Trading Coach akan otomatis terhubung untuk berdiskusi topik trading apa pun tanpa batas secara offline.

---

## 📱 4. Panduan Pengguna AURA Mobile App (`aura_mobile`)

Jalankan aplikasi Android mobile dengan perintah:
```bash
cd aura_mobile
flutter run
```
* **Dashboard Mobile**: Akses rute `/trading` pada menu navigasi mobile untuk membuka Mobile Trading Dashboard (Session Heatmap, Quick Watchlist, Chart Preview, & Risk Calculator).

---

## 🛡️ 5. Ringkasan Aturan Keamanan & Presisi Data

1. **Presisi Uang (`Decimal`)**: Seluruh nilai PnL, harga entry/exit, saldo akun, dan lot size dihitung menggunakan `package:decimal` dan disimpan sebagai `TEXT` di SQLite (`aura_trading.db`).
2. **Data Grounding**: AI Coach dilarang mengarang harga pasar atau berspekulasi tanpa data dari *tool-call* real-time.
3. **Backup Data Trading**: Data transaksi virtual account, paper trades, dan jurnal trading didukung oleh `backup_service.dart` agar aman dari reinstall.

---

## 🧪 6. Menjalankan Verification Test

Untuk memastikan seluruh engine kalkulasi berjalan 100% akurat:
```bash
cd aura_trading
flutter analyze lib/
flutter test test/position_sizer_test.dart test/paper_trading_test.dart test/strategy_backtester_test.dart
```

---

*Dokumen panduan ini merupakan acuan resmi penggunaan fitur AURA Trading Assistant.*
