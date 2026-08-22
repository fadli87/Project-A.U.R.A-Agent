# Workflow: Fase 4 — Persistent Memory

**Tujuan:** Agent bisa "ingat" percakapan lama lewat semantic recall, bukan hanya
menempelkan N pesan terakhir ke context.
**Deliverable akhir:** riwayat chat tersimpan di SQLite, dan semantic recall berfungsi via
ObjectBox.

## Langkah

1. Rancang skema SQLite: tabel `Sessions` dan `Messages`.
2. Implementasikan auto-save setiap respons (user & model) ke SQLite.
3. Integrasikan **ObjectBox** (bukan sqlite-vec — lihat alasan di
   `.agents/rules/01-overview-stack.md`) untuk vector search HNSW.
4. Pilih model embedding ringan untuk on-device (referensi: all-MiniLM-L6-v2 via ONNX,
   lihat contoh di llmedge_gguf pada `.agents/rules/04-reference-projects.md`).
5. Bangun pipeline: pesan penting → embedding → simpan ke ObjectBox → saat prompt baru
   datang, retrieve top-K pesan relevan secara semantic → suntik ke context sebelum
   dikirim ke model.
6. JANGAN suntik seluruh riwayat mentah ke context — itu mahal untuk model kecil dan
   memperlambat inferensi. Gunakan retrieval semantic sebagai gantinya.
7. Uji: buat percakapan panjang (>50 pesan) dengan satu fakta penting disebutkan di awal,
   lalu tanyakan fakta itu di akhir — pastikan agent bisa mengambilnya lewat semantic
   recall meski sudah lewat context window normal.

## Definition of Done
- [ ] Skema SQLite (Sessions, Messages) berjalan dan auto-save berfungsi
- [ ] ObjectBox terintegrasi dengan vector search HNSW
- [ ] Uji recall fakta lama (>50 pesan) berhasil tanpa membengkakkan context window
