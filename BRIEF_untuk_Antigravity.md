# Brief untuk Antigravity: Lanjutkan Restrukturisasi Monorepo A.U.R.A

## Konteks
Repo ini sedang direstrukturisasi dari project Flutter Android tunggal menjadi
monorepo dengan 3 package:

- `aura_core/`    -> Dart package murni (platform-agnostic): inference, memory,
                     storage, agent, utils. Dipakai bersama oleh aura_mobile & aura_desktop.
- `aura_mobile/`  -> Project Flutter Android yang sudah ada (UI + platform channel saja).
- `aura_desktop/` -> Project Flutter Desktop baru (Windows/Linux), belum dikerjakan.

File-file berikut SUDAH dipindahkan secara fisik ke `aura_core/lib/`:
- `agent/agent_tools.dart`, `agent/alarm_service.dart`, `agent/agent.dart` (placeholder)
- `inference/gguf_model.dart`, `inference/inference.dart` (placeholder)
- `utils/emoji_parser.dart`
- `storage/` (isi belum diverifikasi lengkap)
- `memory/` (isi belum diverifikasi lengkap)
- `memory/objectbox.g.dart`, `memory/objectbox-model.json`

`aura_mobile/lib/src/` seharusnya sekarang tinggal berisi: `ui/`, `providers/`, `main.dart`.

Project menggunakan **ObjectBox** (bukan SQLite murni) untuk persistensi data lokal.

## Yang PERLU kamu kerjakan sekarang

1. **Audit isi `aura_core/lib/`** — buka semua file di `agent/`, `inference/`, `storage/`,
   `memory/`, `utils/`. Konfirmasi tidak ada file yang masih bergantung ke
   `package:flutter/...` (kalau ada, pindahkan balik ke `aura_mobile` atau refactor
   agar platform-agnostic).

2. **Lengkapi `aura_core/lib/aura_core.dart`** — tambahkan `export` untuk SEMUA file
   publik di dalam `agent/`, `inference/`, `storage/`, `memory/`, `utils/` yang perlu
   diakses dari luar package.

3. **Setup `aura_core/pubspec.yaml`** — pastikan dependency berikut ada (sesuaikan versi
   yang cocok dengan yang dipakai `aura_mobile` sebelumnya, cek dari `aura_mobile/pubspec.yaml`
   yang lama sebelum restrukturisasi kalau perlu via git log):
   - `objectbox`, `objectbox_flutter_libs` (untuk memory/storage)
   - `ffi` (untuk inference/llama.cpp binding)
   - dependency lain yang dipakai file-file yang sudah dipindah

4. **Perbaiki `aura_mobile/pubspec.yaml`** — tambahkan:
   ```yaml
   dependencies:
     aura_core:
       path: ../aura_core
   ```

5. **Perbaiki semua import yang rusak di `aura_mobile/lib/src/ui/` dan `providers/`** —
   ganti import relatif lama (`../agent/...`, `../native/gguf_model.dart`,
   `../utils/emoji_parser.dart`, `../storage/...`, `../memory/...`) menjadi:
   ```dart
   import 'package:aura_core/aura_core.dart';
   ```

6. **Jalankan `flutter pub get`** di `aura_core/` lalu di `aura_mobile/`.

7. **Build & jalankan `aura_mobile`** (`flutter run` atau `flutter build apk --debug`)
   untuk memverifikasi tidak ada error import atau dependency yang hilang.
   Perbaiki error satu per satu sampai build sukses seperti sebelum restrukturisasi.

8. **Baru setelah `aura_mobile` build sukses**, lanjutkan ke `aura_desktop/`:
   - Tambahkan dependency `aura_core: {path: ../aura_core}` ke `aura_desktop/pubspec.yaml`
   - Mulai bangun UI desktop dasar yang memanggil `aura_core` untuk inference & chat

## Batasan penting
- JANGAN menyalin kode dari repo `unslothai/unsloth` (lisensi AGPL-3.0) — hanya boleh
  pakai pola arsitektur sebagai referensi konsep, ditulis ulang sendiri.
- Pertahankan Fase 8 dari versi Android: backup/restore chat/persona/skills, dan
  iteration safety cap di agent loop — jangan hilang saat migrasi ke aura_core.
- Jangan ubah behavior/fitur yang sudah ada di aura_mobile, restrukturisasi ini
  murni pemindahan lokasi kode, bukan rewrite logic.

## Kalau ragu
Kalau ada keputusan arsitektur yang ambigu (misalnya file yang campur platform-specific
dan platform-agnostic dalam satu file, atau konflik dependency version), berhenti dan
laporkan ke user dulu sebelum lanjut — jangan asumsikan sepihak.
