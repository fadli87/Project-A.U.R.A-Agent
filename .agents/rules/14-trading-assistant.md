# Rule: AURA Trading Assistant — Visi, Arsitektur & Prinsip Keamanan

Baca ini sebelum mengerjakan apapun di package `aura_trading`. File ini konsolidasi dari
`TRADING_ASSISTANT_REQUIREMENTS.md` dan `TRADING_ASSISTANT_PROGRESS.md` yang sudah ada di
root project, DITAMBAH pagar keamanan yang belum tercakup di kedua dokumen itu. Kalau ada
konflik antara file ini dan dua dokumen tadi soal hal yang menyangkut KEAMANAN/PRESISI
DATA UANG, file ini yang menang.

## Cakupan platform
`aura_trading` adalah package shared, dikonsumsi `aura_mobile` DAN `aura_desktop` — UI
boleh beda per platform, logic bisnis (indikator, position sizer, paper trading engine)
harus satu sumber di `aura_trading`, tidak diduplikasi ke masing-masing app.

## Prinsip 1: SEMUA angka uang WAJIB pakai `decimal`, BUKAN `double`
`double` (floating-point biner) tidak presisi untuk aritmatika uang — rounding error
menumpuk seiring banyak transaksi. Ini berlaku untuk: PnL (realized/unrealized), lot size,
risk percentage, max loss, harga entry/stop-loss/take-profit, saldo virtual account.
Gunakan package `decimal` (arbitrary-precision) di `Candle`, `PriceTicker`,
`PositionSizeResult`, `TradeJournal`, `PaperTradingEngine`, dan `TradingDatabase`. `double`
cuma boleh dipakai untuk hal non-uang (mis. koordinat chart, persentase progres UI).

## Prinsip 2: AI Trading Coach HANYA boleh reasoning dari tool-call, TIDAK BOLEH dari pengetahuan umum
Model 1-4B on-device (sama seperti yang sudah didokumentasikan reliability-nya di seluruh
project ini) TIDAK BOLEH menjawab soal kondisi pasar dari "ingatan" parametriknya —
pengetahuan itu statis dari waktu training, pasti usang untuk data pasar real-time.
- `trading_coach_prompt.dart` WAJIB eksplisit menyatakan: "Jawab HANYA berdasarkan hasil
  pemanggilan getCurrentPrice/getTechnicalIndicators/calculatePositionSize. JANGAN
  berspekulasi soal harga, berita, atau kondisi pasar yang tidak berasal dari tool-call."
- Kalau user tanya sesuatu yang butuh data yang tidak tersedia lewat tool yang ada, AI
  HARUS bilang tidak punya data itu — bukan mengarang jawaban yang terdengar meyakinkan.
- Ini prinsip yang SAMA dengan larangan halusinasi hasil pencarian di
  `.agents/rules/07-cron-search.md` — model tidak boleh berpura-pura tahu sesuatu yang
  sebenarnya tidak dia ketahui.

## Prinsip 3: Reuse `DesktopSecureStorage` (DPAPI), JANGAN tambah `flutter_secure_storage`
Sudah pernah terjadi dependency ini masuk ke `aura_trading/pubspec.yaml` dan nyaris memicu
ulang Insiden 7 (`atlstr.h`/ATL) — lihat `.agents/rules/00-checklist-insiden.md`. API key
broker/exchange (TwelveData, IC Markets, dll) WAJIB pakai mekanisme secure storage yang
SAMA dengan yang sudah divalidasi di Fase 14 (`.agents/rules/13-cloud-fallback.md`) — satu
implementasi DPAPI-via-FFI untuk semua kebutuhan secure storage di Desktop, titik.

## Prinsip 4: Sumber data online — prioritas dan fallback yang jelas
1. **Prioritas 1:** API resmi berbayar/gratis dengan ToS jelas (TwelveData, Finnhub).
2. **Prioritas 2:** Yahoo Finance endpoint tidak resmi (v8/chart) — dipahami RAPUH dan bisa
   berhenti bekerja sewaktu-waktu tanpa pemberitahuan, JANGAN dijadikan satu-satunya
   sumber data untuk fitur penting.
3. **Prioritas terakhir (fallback saja):** scraper (investing.com, IDX official, Forex
   Factory, CNBC Indonesia) — rapuh terhadap perubahan struktur HTML, berpotensi
   melanggar ToS situs sumber. Jangan investasikan effort besar untuk "menyembunyikan diri
   dari blokir" (mis. delay acak) — kalau situs sumber memang memblokir, terima sebagai
   sinyal untuk beralih ke sumber lain, bukan alasan untuk makin canggih menghindar.
4. SELALU tampilkan indikator "Data mungkin tidak terkini" kalau data berasal dari cache,
   bukan fetch langsung — sudah tercantum di requirements, pastikan benar-benar
   diimplementasikan konsisten di semua widget yang menampilkan harga.

## Prinsip 5: Live trading (Phase 4 masa depan) — manusia SELALU pemicu akhir
Requirements sudah menyebut "konfirmasi multi-layer" untuk live trading nanti — ini
DIPERKUAT jadi aturan keras: **AI TIDAK PERNAH BOLEH menempatkan order live secara
otonom penuh**, berapapun "yakin" hasil reasoning-nya. Order live HARUS selalu diakhiri
oleh aksi eksplisit manusia (tombol konfirmasi terpisah, bukan sekadar "ya" di chat) —
konsisten dengan prinsip permission-gate untuk tool sensitif di
`.agents/rules/03-tool-calling.md`, tapi levelnya lebih tinggi karena ini uang sungguhan
lewat API broker tidak resmi (Bibit/Stockbit) yang risiko akun ter-suspend kalau salah
pakai.

## Prinsip 6: Backup mencakup data Trading (perluasan Fase 8)
`backup_service.dart` (Fase 8) awalnya didesain sebelum `aura_trading.db` ada. WAJIB
diperluas mencakup: virtual accounts, paper trades, trade journal (termasuk tag emosi).
Ini data yang paling berharga untuk dipertahankan (riwayat belajar dari kesalahan sendiri)
dan paling berisiko hilang kalau ada reinstall seperti Insiden 3.

## Prinsip 7: Disclaimer
Kalau app ini nantinya dipakai orang lain (bukan cuma pribadi) atau live trading benar-benar
diaktifkan, tampilkan disclaimer eksplisit "bukan nasihat keuangan" — terutama karena ada
AI Coach yang bisa terdengar otoritatif meski sebenarnya cuma pattern-matching dari model
kecil lokal.
