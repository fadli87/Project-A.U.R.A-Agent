# Workflow: Fase 10 — Tools Tambahan (clarify, todo, skill_manage, session_search)

Baca `.agents/rules/09-hermes-tools.md` SEBELUM memulai — spesifikasi lengkap 4 tool baru
ada di sana, termasuk kategori aman/sensitif masing-masing.

**Tujuan:** Melengkapi kemampuan agent dengan pola yang terbukti dipakai Hermes Agent,
disaring khusus untuk konteks model kecil on-device.
**Prasyarat:** Fase 5 (Tool-Calling) dan Fase 7 (Persona & Skills) sudah selesai.

## Langkah

1. Implementasikan tool `clarify` — update system prompt tool-calling (Fase 5) supaya
   model tahu kapan harus memilih tool ini alih-alih menebak. Bangun UI pertanyaan dengan
   tombol pilihan cepat / kotak jawaban bebas.
2. Tambahkan tabel `TodoLists` dan `TodoItems`, implementasikan tiga tool terpisah
   (`todo_create`, `todo_update`, `todo_list`). Bangun UI checklist sederhana di Settings
   atau sebagai layar terpisah.
3. Tambahkan kolom `is_agent_created` ke tabel `Skills` (migrasi skema dari Fase 7).
   Implementasikan tool `skill_manage` dengan alur propose → dialog konfirmasi lengkap
   (tampilkan draft skill utuh, bukan ringkasan) → Approve/Reject → baru masuk tabel Skills
   kalau Approve.
4. Implementasikan tool `session_search` sebagai wrapper tipis di atas fungsi retrieval
   ObjectBox yang sudah ada di `embedding_service.dart` (Fase 4) — jangan duplikasi logic.
5. Update Skill Manager UI (Fase 7) untuk menandai visual skill yang `is_agent_created=1`
   berbeda dari skill buatan user (mis. badge kecil "dibuat agent").
6. Uji tiap tool satu-satu:
   - `clarify`: beri prompt ambigu, pastikan agent bertanya balik alih-alih menebak
   - `todo_*`: buat list, tandai selesai, lihat daftar — semua lewat chat natural
   - `skill_manage`: minta agent selesaikan task multi-step, lihat apakah agent
     mengusulkan skill baru, pastikan TIDAK tersimpan tanpa Approve eksplisit
   - `session_search`: tanya sesuatu yang merujuk percakapan lama, pastikan agent
     memanggil tool ini alih-alih mengarang jawaban

## Definition of Done
- [ ] `clarify` terpanggil untuk prompt ambigu, bukan ditebak
- [ ] Todo list berfungsi end-to-end (create/update/list) lewat chat
- [ ] `skill_manage` SELALU minta approval eksplisit sebelum skill baru tersimpan
- [ ] Skill hasil agent bisa dibedakan visual dari skill buatan user di UI
- [ ] `session_search` berhasil memanggil retrieval ObjectBox yang sudah ada, tanpa duplikasi logic
