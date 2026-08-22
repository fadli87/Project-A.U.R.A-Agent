# Workflow: Fase 2 — FFI Bridge & Isolate + Foreground Service

**Tujuan:** Komunikasi aman dan non-blocking antara Dart dan C++, dengan proses inferensi
yang tidak dibunuh OS saat app di-background.
**Deliverable akhir:** model GGUF berhasil dimuat, status "ready" dikirim ke UI tanpa freeze,
proses tetap hidup saat app di-background.

## Langkah

1. Tulis C-wrapper `llama_bridge.cpp` dengan fungsi: `load_model`, `generate_tokens`,
   `free_model`, `unload_model`.
2. Tulis binding Dart FFI yang sesuai dengan signature fungsi C di atas.
3. Implementasikan `Isolate.spawn` untuk membungkus panggilan inferensi — inferensi TIDAK
   BOLEH berjalan di main isolate (akan freeze UI).
4. Implementasikan komunikasi dua arah lewat SendPort/ReceivePort: kirim prompt dari main
   isolate ke worker isolate, terima stream token kembali.
5. Tambahkan Android Foreground Service dengan notification persisten ("Agent aktif") yang
   menjaga isolate/proses tetap hidup saat app di-background. Ini WAJIB — lihat
   `.agents/rules/01-overview-stack.md` soal kenapa Isolate saja tidak cukup.
6. Uji: load salah satu model tier ringan (`gemma-3-1b-it-Q4_K_M.gguf`), pastikan status
   "ready" terkirim ke UI tanpa membekukan frame rate.
7. Uji skenario background: mulai generate, minimize app, pastikan proses tidak terputus
   dan notification foreground service muncul.

## Referensi jika stuck
`.agents/rules/04-reference-projects.md` — Llama-Flutter punya arsitektur Foreground
Service yang bisa dicontek langsung.

## Definition of Done
- [ ] Model GGUF tier ringan berhasil dimuat via isolate tanpa freeze UI
- [ ] Foreground Service aktif dengan notification saat inferensi berjalan
- [ ] Proses tidak terputus saat app di-minimize selama generate berlangsung
