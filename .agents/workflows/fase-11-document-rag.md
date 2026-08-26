# Workflow: Fase 11 — Local Document RAG

Baca `.agents/rules/10-document-rag.md` SEBELUM memulai.

**Tujuan:** AURA bisa menjawab berdasarkan dokumen pribadi yang user pilih, bukan cuma
pengetahuan parametrik model yang terbatas.
**Prasyarat:** Fase 4 (Memory/ObjectBox/embedding_service.dart) sudah selesai.

## Langkah

1. Tambahkan tabel `DocumentSources` (id, name, path, imported_at, chunk_count).
2. Bangun UI "Sumber Pengetahuan" di Settings dengan tombol import (file_picker).
3. Implementasikan ekstraksi teks per format (`.txt`/`.md` langsung, `.pdf` via library
   ekstraksi teks ringan).
4. Implementasikan chunking (~300-500 kata, overlap ~50 kata).
5. Reuse `embedding_service.dart` untuk embed tiap chunk, simpan ke ObjectBox dengan field
   `source_type: "document"` untuk membedakan dari memori chat.
6. Update fungsi retrieval yang sudah ada (Fase 4) supaya mencakup kedua source_type,
   dengan label asal chunk di observasi yang disuntik ke context.
7. Implementasikan hapus dokumen (referensi + embedding-nya) dari UI Sumber Pengetahuan.
8. Jalankan proses ekstraksi+embedding di isolate terpisah, dengan progress indicator di UI.
9. Uji: import satu dokumen, tanya sesuatu yang jawabannya HANYA ada di dokumen itu (bukan
   pengetahuan umum), pastikan AURA menjawab benar dan menyebut sumbernya.

## Definition of Done
- [ ] Import dokumen (.txt/.md/.pdf) berhasil, muncul di daftar Sumber Pengetahuan
- [ ] Pertanyaan yang jawabannya cuma ada di dokumen berhasil dijawab dengan benar
- [ ] Jawaban menyebut sumber dokumen asalnya
- [ ] Hapus dokumen juga menghapus embedding-nya dari ObjectBox
- [ ] Proses import tidak blocking UI (jalan di isolate terpisah)
