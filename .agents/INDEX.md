# 🤖 AURA Trading Assistant — Agent Rules & Guides Index

> **Lokasi**: `C:\devapp\AURA_MonoRepo\Project-A.U.R.A-Agent\.agents\`  
> **Untuk**: Antigravity (Agy) — AI Coding Executor  
> **Dibuat**: Otomatis oleh Shin (Brainstorming & Architecture)

---

## 📁 Struktur Direktori

```
.agents/
├── INDEX.md                    ← FILE INI (Entry point)
├── rules/                      ← Aturan wajib & prinsip keamanan
│   ├── ANTIGRAVITY_WORKING_RULES.md      ← **UTAMA**: Aturan kerja, Prinsip 1 & 5, 4 Skeleton Code (Mt5Client, Repository, Provider, Dialog)
│   ├── 00-checklist-insiden.md
│   ├── 01-overview-stack.md
│   ├── 02-architecture.md
│   ├── 03-tool-calling.md
│   ├── 04-reference-projects.md
│   ├── 05-persona-skills.md
│   ├── 06-backup-safety-cap.md
│   ├── 07-cron-search.md
│   ├── 08-desktop-roadmap.md
│   ├── 09-hermes-tools.md
│   ├── 10-document-rag.md
│   ├── 11-hybrid-routing.md
│   ├── 12-scoped-pc-access.md
│   ├── 13-cloud-fallback.md
│   └── 14-trading-assistant.md
└── guides/                     ← Panduan implementasi fitur spesifik
    ├── TRADING_ASSISTANT_REQUIREMENTS.md              ← **PRD MASTER**: Semua fitur, arsitektur, roadmap Phase 0-4, API, UI/UX
    ├── TRADING_ASSISTANT_MT5_INTEGRATION.md           ← Arsitektur integrasi MT5 (Python Bridge di port 8088)
    ├── RISK_CARD_TO_MT5_INTEGRATION_GUIDE.md          ← Verifikasi & perbaikan: RiskCard → Mt5OrderDialog → MT5
    ├── AI_COACH_MT5_CONTEXT_INTEGRATION_GUIDE.md      ← Inject konteks live (akun, posisi, harga) ke AI Coach
    └── ECONOMIC_CALENDAR_WIDGET_GUIDE.md              ← Widget Kalender Ekonomi (Forex Factory style) + AI Explain
```

---

## 🚀 Quick Start untuk Antigravity

### 1. Baca Aturan Utama (WAJIB)
```bash
cat .agents/rules/ANTIGRAVITY_WORKING_RULES.md
```
- Prinsip 1: **Decimal** untuk semua uang/lot
- Prinsip 5: **Manusia = pemicu akhir** (dialog konfirmasi wajib)
- 4 skeleton code siap implementasi: `Mt5Client`, `Mt5Repository`, `mt5_provider.dart`, `Mt5OrderDialog`

### 2. Pahami PRD Master
```bash
cat .agents/guides/TRADING_ASSISTANT_REQUIREMENTS.md
```
- Vision, arsitektur monorepo, fitur per asset class (Forex/Gold + IDX)
- Roadmap Phase 0-4, dependencies, kriteria selesai

### 3. Pilih Task Implementasi Berikutnya (Prioritas)

| Prioritas | Task | Guide | File Target | Status |
|-----------|------|-------|-------------|--------|
| 🔴 **Tinggi** | Verifikasi & perbaiki RiskCard → MT5 Execution | `RISK_CARD_TO_MT5_INTEGRATION_GUIDE.md` | `aura_trading/lib/presentation/widgets/risk_card.dart`, `mt5_order_dialog.dart` | ✅ Selesai |
| 🔴 **Tinggi** | Inject konteks MT5 live ke AI Coach | `AI_COACH_MT5_CONTEXT_INTEGRATION_GUIDE.md` | `aura_trading/lib/ai/context_builder.dart`, `trading_tools.dart`, `trading_coach_prompt.dart` | ✅ Selesai |
| 🟡 **Sedang** | Bangun Economic Calendar Widget | `ECONOMIC_CALENDAR_WIDGET_GUIDE.md` | `aura_trading/lib/presentation/widgets/economic_calendar_widget.dart` | ✅ Selesai |
| 🟡 **Sedang** | 1-Click Run & Kill MT5 Service | `TRADING_ASSISTANT_MT5_INTEGRATION.md` | `aura_trading/lib/services/mt5_service_launcher.dart` | ✅ Selesai |
| 🟢 **Lanjutan**| IDX Fundamental Screener | `TRADING_ASSISTANT_REQUIREMENTS.md` (Phase 1) | `aura_trading/lib/presentation/widgets/fundamental_screener.dart` | ⏳ Terjadwal |

---

## 🔑 File Kode Utama yang Sudah Ada (Jangan Duplikat)

| Komponen | Lokasi | Status |
|----------|--------|--------|
| **MT5 Bridge (Python)** | `tools/mt5_bridge/mt5_service.py` | ✅ Siap jalan di port 8088 + /shutdown |
| **Mt5ServiceLauncher** | `aura_trading/lib/services/mt5_service_launcher.dart` | ✅ 1-click Run & Kill service dari UI |
| **Mt5Client / Repository / Models** | `aura_trading/lib/data/sources/mt5/` | ✅ Lengkap + Decimal |
| **Riverpod Providers (MT5)** | `aura_trading/lib/presentation/providers/mt5_provider.dart` | ✅ Auto-polling + manual refresh |
| **Mt5OrderDialog** | `aura_trading/lib/presentation/widgets/mt5_order_dialog.dart` | ✅ Multi-layer confirmation |
| **Mt5PositionsWidget** | `aura_trading/lib/presentation/widgets/mt5_positions_widget.dart` | ✅ Live PnL + close button |
| **Mt5StatusBarWidget** | `aura_trading/lib/presentation/widgets/mt5_status_bar.dart` | ✅ Live stats + 1-click Run/Kill buttons |
| **EconomicCalendarWidget** | `aura_trading/lib/presentation/widgets/economic_calendar_widget.dart` | ✅ Currency filter + AI explain |
| **RiskCardWidget** | `aura_trading/lib/presentation/widgets/risk_card.dart` | ✅ Terhubung ke Mt5OrderDialog |
| **Paper Trading Engine** | `aura_trading/lib/domain/paper_trading_engine.dart` | ✅ Virtual accounts Forex/IDX |
| **Backtesting & Strategy** | `aura_trading/lib/domain/strategy_backtester.dart` | ✅ Equity curve, backtest panel |
| **Trade Journal + Risk Dashboard** | `aura_trading/lib/presentation/widgets/` | ✅ Lengkap |


---

## ⚙️ Perintah Standar Eksekusi

```bash
# Masuk ke package trading
cd C:/devapp/AURA_MonoRepo/Project-A.U.R.A-Agent/aura_trading

# Generate Riverpod code (setiap kali tambah provider)
flutter pub run build_runner build --delete-conflicting-outputs

# Analisis static
flutter analyze

# Test unit
flutter test test/position_sizer_test.dart

# Jalankan Desktop untuk manual testing
cd ../aura_desktop
flutter run -d windows

# Jalankan MT5 Bridge Python (terminal terpisah)
cd ../tools/mt5_bridge
python mt5_service.py
```

---

## 📌 Catatan Penting untuk Antigravity

1. **Jangan sentuh `aura_core/`** — hanya `aura_trading`, `aura_mobile`, `aura_desktop`.
2. **Semua dependency** sudah di `pubspec.yaml` masing-masing package.
3. **MT5 Terminal harus jalan** di Windows yang sama (bridge connect via IPC localhost).
4. **Commit message format**: `feat(trading): <deskripsi singkat>` / `fix(trading): <deskripsi>`.
5. **Semua panduan lengkap** ada di `.agents/guides/` — baca sebelum mulai coding.

---

*Index ini adalah peta navigasi tunggal untuk Antigravity. Semua dokumen terpusat di sini.*