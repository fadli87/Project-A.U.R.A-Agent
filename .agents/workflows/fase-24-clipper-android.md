# Workflow: Fase 24 — AURA Clipper di Android — **DIBLOKIR, JANGAN DIKERJAKAN**

> **Status: MENUNGGU KEPUTUSAN USER.** Antigravity tidak boleh menulis kode untuk fase ini
> sebelum user memilih jalur di bawah dan memperbarui dokumen ini. Fase 21–23 hanya wajib
> menjaga **kesiapan** (interface dan pemisahan `lib/src/desktop/`), bukan membangun Android.

## Kenapa tidak bisa sekadar "dipakai di Android"

Yang platform-netral dan siap dipakai ulang: `llm_router`, model, `MomentAnalyzer`,
`ClipDatabase` (sqlite3), logika pipeline, dan sebagian besar UI.
Yang **tidak** bisa: `yt-dlp`, `ffmpeg`, dan `whisper.cpp` yang dipanggil via `Process.run`
(cara kerja desktop), serta `DesktopSecureStorage` (DPAPI Windows). `aura_mobile` sudah punya
`MobileSecureStorage` untuk sisi key.

## Tiga jalur (user memilih satu)

1. **Android sebagai remote/companion (paling murah).** HP mengirim link ke PC; PC yang
   download, transkrip, dan potong; HP menerima kandidat, pratinjau, dan hasil. Memanfaatkan
   pola hybrid mobile↔desktop dari Fase 12 (`rules/11-hybrid-routing.md`). Perlu protokol
   job sederhana (kirim link + opsi, polling progres, ambil hasil) dan keputusan keamanan
   jaringan lokal (token, hanya LAN).
2. **Proses sendiri di perangkat.** `whisper.cpp` via FFI (pola sama dengan llama.cpp),
   FFmpeg lewat plugin Flutter, download lewat library yt-dlp untuk Android. Paling mandiri,
   paling berat: baterai, RAM, ukuran APK. Proyek `ffmpeg_kit` yang populer setahu saya sudah
   dihentikan — perlu cek fork yang masih terawat sebelum memilih.
3. **Hybrid ringan.** Video lokal atau caption YouTube yang sudah ada sebagai transkrip;
   analisis LLM dan potong video di HP; tanpa download dan tanpa Whisper. Terbatas pada
   video yang punya caption atau sudah ada di perangkat.

## Saat jalur sudah dipilih

User memperbarui bagian ini dengan jalur terpilih. Baru setelah itu fase ini diisi langkah,
DoD, dan aturan tambahan (termasuk `rules/15-android-sdk-version-lock.md`).
