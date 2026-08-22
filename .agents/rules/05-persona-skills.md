# Rule: Persona, Skills & Memory Snapshot (pola ala Hermes Agent)

Baca ini sebelum mengerjakan Fase 7. Ini melengkapi (bukan menggantikan) Fase 4 (Memory)
dan Fase 5 (Tool-Calling) yang sudah ada.

## Skema Database (tambahan ke SQLite yang sudah ada di Fase 4)

```sql
CREATE TABLE Persona (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  content TEXT NOT NULL,       -- max ~1500 karakter, divalidasi di kode
  is_active INTEGER DEFAULT 0, -- hanya 1 row boleh aktif
  is_builtin INTEGER DEFAULT 0,
  created_at INTEGER
);

CREATE TABLE Skills (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL,   -- max ~150 karakter, ini yang masuk index setiap request
  body TEXT NOT NULL,          -- prosedur lengkap, hanya dimuat saat relevan
  enabled INTEGER DEFAULT 1,
  keywords TEXT,               -- comma-separated, untuk keyword-match v1
  created_at INTEGER
);

CREATE TABLE MemorySnapshot (
  id INTEGER PRIMARY KEY,
  session_id INTEGER NOT NULL,
  summary TEXT NOT NULL,       -- ringkasan berjalan, di-update berkala
  message_count_at_update INTEGER,
  updated_at INTEGER
);

CREATE TABLE UserProfile (
  id INTEGER PRIMARY KEY,
  fact TEXT NOT NULL,          -- satu baris = satu fakta stabil tentang user
  created_at INTEGER
);
```

## Urutan Perakitan System Prompt (WAJIB diikuti persis, jangan diacak)

```
[1. STABLE — selalu sama tiap request kecuali user ganti persona/skill]
   a. Persona aktif (dari tabel Persona WHERE is_active=1)
   b. Instruksi skema tool-calling (dari .agents/rules/03-tool-calling.md)
   c. Skills index — daftar "nama: deskripsi" untuk SEMUA skill enabled=1
      (bukan isi lengkap, cuma index — ini yang bikin murah walau skill banyak)

[2. CONTEXT — berubah tergantung prompt user saat ini]
   d. Body lengkap skill yang match (lihat "Keputusan pemilihan skill" di bawah)
      — HANYA yang match, jangan suntik semua body skill sekaligus

[3. VOLATILE — berubah tiap sesi/waktu]
   e. UserProfile — daftar fakta stabil tentang user (nama, preferensi)
   f. MemorySnapshot terbaru untuk sesi ini (ringkasan berjalan)
   g. N pesan terakhir dari sesi aktif (riwayat langsung, bukan hasil retrieval)
```

Gabungkan semua ke satu system prompt, urutan a→g. Jangan taruh riwayat pesan SEBELUM
persona/skills index — model kecil lebih rentan "lupa" instruksi awal kalau instruksi
penting diselipkan di tengah/akhir prompt yang panjang.

## Keputusan pemilihan skill — WAJIB deterministik, JANGAN percayakan ke model

Beda dari Hermes Agent asli (yang modelnya cukup kuat untuk memilih skill sendiri lewat
tool call), model 1-3B di project ini TIDAK BOLEH dipercaya membuat keputusan ini sendiri
secara reliable — konsisten dengan alasan permission-gate di
`.agents/rules/03-tool-calling.md`.

- **v1 (wajib diimplementasikan dulu):** keyword-match sederhana — cek apakah kolom
  `keywords` skill match dengan prompt user (case-insensitive substring match cukup).
- **v2 (opsional, setelah Fase 4 ObjectBox jalan):** semantic similarity antara embedding
  prompt user dan embedding deskripsi skill, pakai infrastruktur ObjectBox yang sama
  dengan ingatan Fase 4 — jangan bikin vector store terpisah untuk ini.
- Batasi maksimal 1-2 skill body yang disuntik per request — jangan suntik semua skill
  yang "agak match", nanti context membengkak dan model kecil makin bingung.

## UI yang perlu dibangun

- **Persona editor:** textarea + character counter (tunjukkan batas 1500 karakter),
  dropdown pilih preset bawaan, tombol "jadikan aktif".
- **Skill manager:** list skill terinstall dengan toggle enable/disable, tombol tambah
  skill baru (form: nama, deskripsi, keywords, body — atau import file `.md`), tombol
  hapus.
- Keduanya masuk ke Settings screen, terpisah dari Model Manager (Fase 3).

## Kapan MemorySnapshot di-update

Jangan update tiap pesan (boros inferensi). Update setiap kelipatan N pesan (default N=20,
boleh dikonfigurasi) — minta model membuat ringkasan singkat (2-4 kalimat) dari pesan-pesan
sejak snapshot terakhir, gabungkan dengan snapshot lama jadi satu snapshot baru yang tetap
ringkas (jangan biarkan snapshot bertumbuh tanpa batas — beri batas panjang maksimal, mis.
800 karakter, dan minta model meringkas ulang kalau sudah mendekati batas itu).
