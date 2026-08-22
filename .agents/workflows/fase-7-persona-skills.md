# Workflow: Fase 7 — Persona, Skills & Memory Snapshot

Baca `.agents/rules/05-persona-skills.md` SEBELUM memulai — semua skema database, urutan
prompt assembly, dan aturan pemilihan skill ada di sana.

**Tujuan:** Agent punya identitas persisten (persona), bisa ditambah kemampuan baru lewat
skill tanpa ubah kode (skills), dan ingat konteks jangka panjang secara efisien (memory
snapshot) — pola yang sama dengan yang membuat Hermes Agent terasa "hidup" dan bisa
disesuaikan.
**Prasyarat:** Fase 4 (Memory/SQLite/ObjectBox) dan Fase 5 (Tool-Calling) sudah selesai.

## Langkah

1. Tambahkan 4 tabel baru ke skema SQLite (Persona, Skills, MemorySnapshot, UserProfile) —
   lihat DDL lengkap di `.agents/rules/05-persona-skills.md`.
2. Seed 2-3 persona bawaan (`is_builtin=1`) saat first-run app — jangan biarkan user mulai
   dari kosong.
3. Implementasikan fungsi `buildSystemPrompt()` yang merakit prompt sesuai urutan
   stable → context → volatile persis seperti spesifikasi di Rules — pisahkan jadi fungsi
   sendiri yang gampang di-test, jangan digabung langsung ke tempat pemanggilan model.
4. Implementasikan keyword-match sederhana untuk pemilihan skill (v1) — fungsi terpisah
   yang menerima prompt user + daftar skill enabled, mengembalikan maksimal 1-2 skill yang
   match.
5. Bangun UI Persona Editor di Settings — textarea, character counter, pilih preset,
   tombol aktifkan.
6. Bangun UI Skill Manager di Settings — list, toggle enable/disable, tambah/hapus/import.
7. Implementasikan job update MemorySnapshot: setiap kelipatan N pesan (default 20), minta
   model meringkas pesan-pesan baru, gabungkan dengan snapshot lama, simpan snapshot baru
   (dengan batas panjang maksimal).
8. Uji end-to-end: buat persona custom ("Anda adalah asisten yang bicara santai"), buat
   satu skill custom (mis. "cara membuat catatan belanja"), lalu prompt sesuatu yang
   memicu skill itu — pastikan body skill hanya muncul di context saat prompt memang match
   keyword-nya, tidak setiap saat.
9. (Opsional, setelah langkah 1-8 stabil) Upgrade pemilihan skill dari keyword-match ke
   semantic similarity pakai ObjectBox — lihat catatan v2 di Rules.

## Definition of Done
- [ ] 4 tabel baru berjalan, persona bawaan ter-seed saat first-run
- [ ] `buildSystemPrompt()` merakit prompt sesuai urutan yang ditentukan, teruji terpisah
- [ ] Persona custom bisa dibuat, diedit, dan diaktifkan dari UI
- [ ] Skill custom bisa ditambah dari UI dan body-nya hanya muncul di context saat relevan
- [ ] MemorySnapshot ter-update otomatis tiap N pesan, tidak bertumbuh tanpa batas
