# Rule: Supabase Cross-Device Sync

Baca ini sebelum mengerjakan Fase 20. Ini pengecualian privasi paling signifikan di
seluruh project — beda sifat dari Fase 9 (search, sekali kirim query) atau Fase 19 (cloud
inferensi, sekali per giliran, tidak disimpan). Di sini data **disimpan permanen** di
database pihak ketiga (Supabase, umumnya di-host di infrastruktur AWS) untuk keperluan
sync antar device.

## Tujuan
Mengganti backup manual (`.aurabackup` export/import, Fase 8) dengan sync otomatis
chat/persona/trading data antar device (Mobile ↔ Desktop) lewat Supabase.

## Prinsip 1: Opt-in eksplisit, default OFF
Fitur ini TIDAK aktif sampai user secara sadar setup akun Supabase sendiri (bukan akun
bersama/shared project) dan mengaktifkan toggle "Sync ke Cloud" — beri disclosure jelas:
"Chat, persona, dan data trading Anda akan disimpan di database Supabase yang Anda kelola
sendiri, untuk sinkronisasi antar device."

## Prinsip 2: Row-Level Security (RLS) WAJIB AKTIF — no exceptions
Kesalahan paling umum dan paling berbahaya di project berbasis Supabase adalah tabel
tanpa RLS (data bisa diakses siapa saja yang tahu API URL). ATURAN KERAS:
1. SETIAP tabel yang dibuat untuk sync WAJIB punya RLS aktif sebelum dipakai — TIDAK ADA
   pengecualian "aktifkan nanti setelah testing".
2. Policy WAJIB membatasi akses ke `auth.uid() = user_id` — user cuma bisa baca/tulis
   data miliknya sendiri.
3. Sebelum fitur ini dianggap selesai, WAJIB verifikasi manual: coba akses tabel dari
   client lain (mis. Supabase dashboard dengan anon key saja, tanpa login) — pastikan
   query mengembalikan kosong/ditolak, bukan menampilkan data user.

## Prinsip 3: Autentikasi
Gunakan Supabase Auth (email+password atau magic link — pilih yang paling sederhana untuk
setup single-user) untuk mengidentifikasi "device yang sama milik user yang sama". Token
auth disimpan via mekanisme secure storage yang sudah ada (DPAPI Desktop/Keystore Mobile),
BUKAN plain text.

## Prinsip 4: Apa yang di-sync, apa yang TIDAK PERNAH di-sync
**DI-SYNC (dengan enkripsi transport HTTPS bawaan Supabase, cukup untuk v1):**
- Riwayat chat, persona, skills (Fase 4, 7).
- Trade journal, riwayat paper trading, virtual account state (`aura_trading`).

**TIDAK PERNAH DI-SYNC ke Supabase, SELAMANYA:**
- API key provider (Gemini/OpenAI dari Fase 14, TwelveData dari Trading) — ini TETAP
  HANYA di secure storage lokal tiap device, tidak pernah dikirim ke Supabase dalam
  bentuk apapun.
- Kredensial MT5 (login/password/server) — SAMA, tetap lokal-only via DesktopSecureStorage.
- Model GGUF dan file besar lainnya — terlalu besar untuk database, dan toh sudah bisa
  didownload ulang dari sumber resminya.

## Prinsip 5: Backup lokal (Fase 8) TETAP ADA, bukan digantikan sepenuhnya
JANGAN hapus fitur export/import `.aurabackup` manual — pertahankan sebagai lapisan
pengaman kedua (defense in depth). Supabase adalah layanan pihak ketiga yang tidak
sepenuhnya dalam kendali user (bisa down, berubah kebijakan, dll) — jangan taruh semua
"telur" cuma di satu keranjang cloud yang tidak Anda operasikan sendiri.

## Prinsip 6: Resolusi konflik — sederhana dulu, jangan over-engineer
Kalau device A dan device B sama-sama edit data saat offline lalu sync bersamaan: pakai
**last-write-wins** berdasarkan `updated_at` timestamp — cukup untuk v1 (single user, dua
device). JANGAN bangun sistem resolusi konflik kompleks (CRDT dll) di awal, itu over
engineering untuk skala penggunaan personal saat ini.

## Prinsip 7: Data trading paling sensitif — pertimbangan ekstra
Trade journal berisi tag emosi (Discipline, FOMO, Revenge, Fear) dan catatan personal
soal psikologi trading user — ini data yang cukup pribadi. Pertimbangkan (opsional, boleh
ditunda ke v2 kalau menambah kompleksitas berlebih di v1): enkripsi client-side untuk
field catatan bebas sebelum upload ke Supabase, supaya bahkan kalau ada kebocoran di sisi
Supabase, isi catatan personal tidak langsung terbaca.
