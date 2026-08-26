# Workflow: Fase 13 — Akses File PC Terbatas (Read-Only, Whitelist)

Baca `.agents/rules/12-scoped-pc-access.md` SEBELUM memulai — batasan keras di sana WAJIB
dipatuhi persis, tidak untuk dilonggarkan tanpa diskusi ulang eksplisit.

**Tujuan:** AURA bisa baca file spesifik yang diminta user secara ad-hoc, dalam batas
folder yang sudah di-whitelist — TANPA kemampuan tulis/hapus/eksekusi apapun.
**Prasyarat:** Fase 5 (Tool-Calling, kategori aman/sensitif) sudah selesai.

## Langkah

1. Bangun UI "Folder yang Bisa Dibaca AURA" di Settings — daftar kosong secara default,
   tombol tambah (folder picker) dan hapus.
2. Simpan whitelist folder ke penyimpanan settings lokal.
3. Implementasikan tool `read_local_file(path)` — kategori SENSITIF di skema tool-calling
   (Fase 5).
4. Implementasikan validasi path KETAT: resolve absolute path, cek prefix ada di whitelist,
   tolak dengan pesan jelas kalau tidak lolos (termasuk percobaan traversal `..`).
5. Batasi ukuran baca maksimal 1MB, potong dan beri catatan kalau file lebih besar.
6. Tampilkan indikator UI ("📄 Membaca: ...") tiap kali tool ini benar-benar dipanggil.
7. Update system prompt tool-calling: jelaskan ke model bahwa tool ini HANYA bisa baca
   folder whitelist, dan kalau user minta baca di luar itu, tool akan otomatis menolak
   (supaya model tidak terus mencoba path yang jelas akan gagal).
8. Uji tiga skenario:
   - Baca file DALAM folder whitelist → berhasil, ada indikator UI
   - Baca file DI LUAR folder whitelist → ditolak dengan pesan jelas, agent menjelaskan ke
     user perlu tambah folder ke whitelist dulu
   - Coba path traversal (`../../` dsb) dari folder whitelist → ditolak

## Definition of Done
- [ ] Whitelist folder kosong secara default, user harus aktif menambahkan
- [ ] `read_local_file` HANYA bisa baca dalam folder whitelist, tervalidasi ketat
- [ ] TIDAK ADA kemampuan tulis/hapus/eksekusi di tool ini sama sekali
- [ ] Percobaan path traversal berhasil ditolak
- [ ] Indikator UI muncul tiap kali tool benar-benar dipanggil
- [ ] File besar (>1MB) dipotong dengan catatan jelas, bukan gagal diam-diam
