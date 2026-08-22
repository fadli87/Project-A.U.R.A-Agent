# Workflow: Fase 5 — Agentic Tool-Calling & Permission System

**Tujuan:** Implementasi agentic loop nyata dengan tool-calling yang aman.
**Deliverable akhir:** minimal 2 tool nyata berfungsi end-to-end dengan permission gate.

Baca `.agents/rules/03-tool-calling.md` SEBELUM memulai fase ini — semua spesifikasi
detail (alur wajib, kategorisasi tool, retry policy) ada di sana, jangan improvisasi.

## Langkah

1. Tulis system prompt yang mendefinisikan skema tool secara ketat (nama fungsi,
   parameter, tipe data).
2. Implementasikan validator skema JSON untuk output model (bukan regex).
3. Implementasikan fallback: 1x re-prompt otomatis jika parsing gagal, lalu fallback ke
   jawaban teks biasa jika masih gagal.
4. Kategorisasikan tool jadi **aman** (auto-execute) vs **sensitif** (wajib konfirmasi
   user) — lihat daftar di `.agents/rules/03-tool-calling.md`.
5. Bangun UI dialog konfirmasi izin untuk tool sensitif — mirip pola approval card
   Allow/Deny (referensi: GGUF Loader Agentic Mode).
6. Implementasikan 3 tool nyata:
   - Cek status jaringan (aman)
   - Baca file lokal dalam sandbox app (aman)
   - Buat catatan/reminder (sensitif — karena menulis data baru, minta konfirmasi)
7. Implementasikan loop lengkap: prompt → reasoning → tool call → observasi (hasil tool
   dimasukkan sebagai role terpisah ke context) → lanjut reasoning → jawaban final.
8. Uji end-to-end dengan model tier standar (`qwen3-1.7b-instruct-Q4_K_M.gguf`) — ukur
   tingkat keberhasilan parsing JSON tool-call, target ≥95%.

## Definition of Done
- [ ] Minimal 2 tool nyata berfungsi end-to-end
- [ ] Permission gate berfungsi untuk tool sensitif — tidak ada auto-execute tanpa izin
- [ ] Fallback re-prompt otomatis berfungsi saat parsing JSON gagal
- [ ] Tingkat keberhasilan parsing JSON tool-call terukur dan didokumentasikan
