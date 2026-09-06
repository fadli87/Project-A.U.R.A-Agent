# Workflow: Fase 20 — Supabase Cross-Device Sync

Baca `.agents/rules/18-supabase-sync.md` SEBELUM memulai — Prinsip 2 (RLS wajib) adalah
yang paling kritis, jangan sampai terlewat sebelum fitur ini dianggap selesai.

**Tujuan:** Sinkronisasi chat/persona/trading data antar device (Mobile↔Desktop) lewat
Supabase, sebagai pelengkap (bukan pengganti) backup manual Fase 8.
**Prasyarat:** Fase 8 (Backup/Restore lokal) dan Fase 15 (Trading Hardening, termasuk
perluasan backup ke data trading) sudah selesai.

## Langkah

1. Buat project Supabase (user setup akun sendiri) — catat URL dan anon key.
2. Desain skema tabel di Supabase yang mencerminkan tabel lokal (Sessions, Messages,
   Persona, Skills, MemorySnapshot, UserProfile, dan tabel trading: virtual accounts,
   paper trades, trade journal) — tambahkan kolom `user_id`, `updated_at` ke semua tabel.
3. **WAJIB langkah ini sebelum lanjut apapun:** aktifkan RLS di semua tabel, buat policy
   `auth.uid() = user_id` untuk SELECT/INSERT/UPDATE/DELETE.
4. **Verifikasi manual RLS:** coba query salah satu tabel pakai anon key tanpa auth token
   (lewat REST API Supabase langsung atau dashboard) — pastikan hasilnya kosong/ditolak.
   JANGAN lanjut ke langkah berikutnya sebelum ini terverifikasi.
5. Implementasikan Supabase Auth (email+password atau magic link) di `aura_core` —
   simpan token via secure storage yang sudah ada.
6. Bangun UI toggle "Sync ke Cloud" di Settings, default OFF, dengan disclosure jelas.
7. Implementasikan sync logic: push perubahan lokal ke Supabase, pull perubahan dari
   Supabase ke lokal, resolusi konflik last-write-wins berdasarkan `updated_at`.
8. Pastikan API key provider (Gemini/OpenAI/TwelveData) dan kredensial MT5 TIDAK PERNAH
   masuk payload sync — audit kode sync untuk pastikan field-field itu di-exclude eksplisit.
9. Pertahankan fitur export/import `.aurabackup` manual (Fase 8) tetap ada dan berfungsi.
10. Uji: buat perubahan di Mobile, verifikasi muncul di Desktop setelah sync (dan
    sebaliknya). Uji konflik: edit data yang sama di kedua device secara offline, sync
    keduanya, verifikasi last-write-wins bekerja sesuai `updated_at`.

## Definition of Done
- [ ] RLS aktif dan TERVERIFIKASI MANUAL di semua tabel sebelum fitur dianggap selesai
- [ ] Auth berfungsi, token tersimpan via secure storage
- [ ] Toggle sync default OFF dengan disclosure jelas
- [ ] Data ter-sync dua arah antar device dengan benar
- [ ] Konflik last-write-wins berfungsi sesuai `updated_at`
- [ ] API key dan kredensial MT5 terkonfirmasi TIDAK PERNAH ikut ter-sync ke Supabase
- [ ] Backup manual `.aurabackup` tetap berfungsi sebagai lapisan kedua
