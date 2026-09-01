# Workflow: Fase 15 — Trading Assistant Hardening (sebelum lanjut Backtesting)

Baca `.agents/rules/14-trading-assistant.md` SEBELUM memulai. Fase ini WAJIB selesai
sebelum lanjut ke Fase 16 (Backtesting Engine) — jangan bangun fitur baru di atas fondasi
yang belum diverifikasi aman untuk data uang.

**Tujuan:** Menutup tiga celah yang teridentifikasi dari review: presisi angka uang,
grounding AI Coach, dan cakupan backup.
**Prasyarat:** Phase 0-2 Trading Assistant (sesuai `TRADING_ASSISTANT_PROGRESS.md`) sudah
selesai.

## Langkah

1. **Audit tipe data uang:** cek `Candle`, `PriceTicker`, `PositionSizeResult`,
   `TradeJournal`, `PaperTradingEngine`, `TradingDatabase` — cari semua field yang
   merepresentasikan uang (harga, PnL, lot size, risk%, saldo). Kalau masih `double`,
   migrasikan ke package `decimal`.
2. Update ke-9 unit test yang sudah ada supaya sesuai tipe data baru (`decimal` punya API
   perbandingan/parsing berbeda dari `double`) — pastikan tetap 9/9 lolos setelah migrasi.
3. **Audit `trading_coach_prompt.dart`:** pastikan ada instruksi eksplisit melarang
   menjawab dari pengetahuan umum soal pasar — kalau belum ada, tambahkan sesuai draft di
   Rules.
4. Uji grounding: beri prompt yang memancing spekulasi (mis. "menurutmu EUR/USD bakal naik
   minggu depan?") TANPA memanggil tool dulu — pastikan AI menolak berspekulasi dan minta
   data via tool call, bukan langsung menjawab dari asumsi.
5. **Perluas `backup_service.dart`:** tambahkan tabel dari `aura_trading.db` (virtual
   accounts, paper trades, trade journal) ke proses export/import backup yang sudah ada
   dari Fase 8. Update `schema_version` check supaya tahu kalau backup lama (pra-Trading)
   di-restore ke versi yang sudah include data trading.
6. Uji end-to-end: buat beberapa trade jurnal + posisi terbuka, export backup, simulasikan
   reinstall (uninstall+install ulang seperti Insiden 3), restore, verifikasi seluruh data
   trading kembali persis seperti sebelumnya.
7. **Audit dependency:** konfirmasi `flutter_secure_storage` benar-benar tidak ada lagi di
   `aura_trading/pubspec.yaml` maupun `aura_desktop/pubspec.yaml` — cari referensi
   `secure_vault.dart`, pastikan memanggil `DesktopSecureStorage` yang sama dengan Fase 14.

## Definition of Done
- [ ] Semua field uang pakai `decimal`, 0 sisa `double` untuk nilai finansial
- [ ] 9/9 unit test tetap lolos setelah migrasi tipe data
- [ ] `trading_coach_prompt.dart` eksplisit melarang spekulasi tanpa tool-call, teruji
- [ ] Backup/restore mencakup seluruh data `aura_trading.db`, teruji lewat simulasi reinstall
- [ ] Tidak ada dependency `flutter_secure_storage` tersisa di manapun dalam monorepo
