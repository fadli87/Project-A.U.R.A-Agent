# Workflow: Fase 16 — Trading Assistant Phase 3 (Backtesting Engine)

Baca `.agents/rules/14-trading-assistant.md` SEBELUM memulai. Ini lanjutan roadmap Phase 3
dari `TRADING_ASSISTANT_PROGRESS.md` — JANGAN mulai fase ini sebelum Fase 15 (Hardening)
selesai, karena backtesting yang akurat butuh fondasi presisi angka (`decimal`) yang benar.

**Tujuan:** Strategy Backtesting Engine + Equity Curve Visualizer, sesuai roadmap asli.
**Prasyarat:** Fase 15 (Trading Hardening) selesai — semua Definition of Done-nya terpenuhi.

## Langkah

1. Implementasikan Historical Data Loader dari cache Yahoo Finance/TwelveData yang sudah
   ada (CSV/Parquet) — reuse `MarketDataRepository`, jangan bikin pipeline data baru.
2. Implementasikan rule-based strategy runner sederhana (mis. kondisi berbasis indikator
   yang sudah ada: EMA, RSI, MACD, Ichimoku) — parser kondisi harus robust terhadap input
   yang salah format, jangan asumsikan selalu valid.
3. Implementasikan kalkulasi metrik kinerja: Win Rate %, Profit Factor, Sharpe Ratio, Max
   Drawdown — SEMUA pakai `decimal` sesuai Prinsip 1 di Rules, konsisten dengan Fase 15.
4. **Peringatan wajib di UI:** tampilkan catatan jelas soal risiko overfitting — strategi
   yang terlihat bagus di backtest historis tidak menjamin performa di pasar nyata. Ini
   bukan sekadar disclaimer kosong, tapi edukasi yang harus terlihat tiap kali hasil
   backtest ditampilkan.
5. Implementasikan Equity Curve Visualizer pakai `fl_chart` (konsisten dengan chart yang
   sudah ada di `candlestick_chart.dart`).
6. Uji dengan strategi sederhana yang hasilnya bisa diverifikasi manual (mis. "beli kalau
   RSI<30, jual kalau RSI>70" di data historis yang diketahui) — pastikan metrik yang
   dihasilkan benar secara matematis, bukan cuma "jalan tanpa error".

## Definition of Done
- [ ] Historical data loader berfungsi dari cache yang sudah ada
- [ ] Strategy runner bisa mengeksekusi minimal 1 strategi berbasis kondisi indikator
- [ ] Win Rate, Profit Factor, Sharpe Ratio, Max Drawdown terhitung benar (diverifikasi manual)
- [ ] Peringatan overfitting tampil jelas di UI hasil backtest
- [ ] Equity Curve Visualizer menampilkan kurva yang sesuai dengan data backtest
- [ ] Semua kalkulasi metrik pakai `decimal`, bukan `double`
