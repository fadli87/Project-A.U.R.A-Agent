# Workflow: Fase 8 — Backup/Restore & Agentic Loop Safety Cap

Baca `.agents/rules/06-backup-safety-cap.md` SEBELUM memulai — semua spesifikasi format
backup dan aturan safety cap ada di sana.

**Tujuan:** Mencegah insiden kehilangan data (seperti yang sudah terjadi dengan model GGUF)
terulang untuk data yang jauh lebih penting — chat history, persona, skills. Sekaligus
mencegah agentic loop boros baterai tanpa kendali.
**Prasyarat:** Fase 4, 5, dan 7 sudah selesai (butuh skema database lengkap dan Agent
Orchestration Layer sudah berjalan).

## Langkah — Bagian A: Backup & Restore

1. Implementasikan fungsi `exportBackup()` yang mengumpulkan seluruh tabel (Sessions,
   Messages, Persona, Skills, MemorySnapshot, UserProfile) jadi satu file `.aurabackup`
   (ZIP berisi JSON per tabel).
2. Sertakan versi skema database di dalam file backup (mis. field `schema_version`) untuk
   validasi saat restore nanti.
3. Bangun UI "Export Backup" di Settings — pakai `file_picker` untuk user pilih lokasi
   simpan (Save As, bukan Open).
4. Implementasikan fungsi `importBackup(file)` — validasi `schema_version` dulu, tampilkan
   error jelas kalau tidak cocok, baru replace data setelah konfirmasi user.
5. Bangun UI "Restore dari Backup" di Settings, dengan dialog konfirmasi eksplisit sebelum
   menimpa data.
6. Implementasikan reminder pasif: cek tanggal backup terakhir setiap app dibuka, tampilkan
   banner halus di Settings kalau sudah >7 hari sejak backup terakhir dan ada data baru.
7. Uji end-to-end: buat beberapa persona/skill/chat, export, hapus app data (uninstall
   reinstall — persis skenario yang sudah terjadi), install ulang, restore, verifikasi
   semua data kembali persis seperti sebelumnya.

## Langkah — Bagian B: Agentic Loop Safety Cap

8. Tambahkan counter iterasi di Agent Orchestration Layer, default
   `MAX_AGENT_ITERATIONS = 8`, dengan opsi ubah di Settings (advanced).
9. Implementasikan penghentian paksa loop saat counter mencapai batas — kembalikan hasil
   parsial ke user dengan pesan jelas, bukan error kosong atau macet diam-diam.
10. Tambahkan indikator progres kasar di UI chat selama loop tool-call berjalan (mis.
    "Langkah 3 dari maks 8").
11. Uji dengan prompt yang sengaja memicu tool-call berulang (mis. instruksi ambigu yang
    bikin model terus mencoba tool berbeda-beda) — pastikan loop berhenti tepat di batas,
    bukan lebih.

## Definition of Done
- [ ] Export backup menghasilkan satu file yang mencakup semua tabel + schema_version
- [ ] Restore berhasil mengembalikan data persis setelah simulasi uninstall+reinstall
- [ ] Reminder pasif backup muncul setelah >7 hari tanpa backup + ada data baru
- [ ] Agentic loop berhenti otomatis di iterasi ke-8 (default) dengan hasil parsial yang jelas
- [ ] Indikator progres loop terlihat di UI selama tool-call berjalan
