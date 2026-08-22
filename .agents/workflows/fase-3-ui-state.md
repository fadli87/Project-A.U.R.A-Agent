# Workflow: Fase 3 — Riverpod State & Chat Interface

**Tujuan:** UI reaktif dengan streaming token real-time, non-blocking terhadap 60fps.
**Deliverable akhir:** chat screen fungsional dengan streaming token-by-token dan Markdown
rendering.

## Langkah

1. Buat `ModelProvider` (Riverpod) — mengelola path GGUF aktif, status loading, dan info
   RAM yang dibutuhkan per model (referensi tier di `.agents/rules/02-architecture.md`).
2. Buat `ChatProvider` — mengelola daftar `ChatMessage` untuk sesi aktif.
3. Buat `ChatScreen` dengan `ListView.builder` untuk daftar pesan + text input field.
4. Hubungkan `StreamProvider` ke output token dari worker isolate (Fase 2) — pastikan UI
   update per-token tanpa jank.
5. Tambahkan renderer Markdown untuk balasan model (banyak model kecil menghasilkan output
   berformat Markdown secara default).
6. Tambahkan indikator baterai/suhu real-time di UI — ingat dari `.agents/rules/01-overview-stack.md`
   bahwa inferensi CPU-bound bisa memicu thermal throttling; user perlu tahu kondisi device.
7. Tambahkan UI status loading model yang jelas (bukan spinner generik) — tampilkan tier
   model yang sedang dimuat dan estimasi waktu jika memungkinkan.

## Definition of Done
- [ ] Chat screen menampilkan streaming token real-time tanpa drop frame
- [ ] Markdown ter-render dengan benar di chat bubble
- [ ] Indikator baterai/suhu terlihat dan update secara berkala
- [ ] Status loading model informatif (bukan generic spinner)
