# AGY TASK — AURA Clipper (Brief Utama)

> **Untuk:** Antigravity (Agy). **Dari:** Shin & Fadli. **Tanggal brief:** 15 Okt 2026.
> Ini pintu masuk tunggal untuk pekerjaan AURA Clipper. Baca berurutan, kerjakan berurutan.

## 1. Urutan baca (wajib)

1. `.agents/rules/00-checklist-insiden.md` — terutama Insiden 2 dan 7.
2. `.agents/rules/19-aura-clipper.md` — keputusan final & larangan.
3. `.agents/PRD_AURA_Clipper.md` — konteks produk. **Catatan:** PRD ini lebih luas dari
   scope yang diputuskan (auto-crop 9:16, subtitle, Supabase, mobile). Yang berlaku untuk
   pekerjaan sekarang adalah `rules/19`, bukan PRD.
4. `.agents/workflows/fase-21-clipper-foundation.md` → `fase-22-clipper-pipeline.md` →
   `fase-23-clipper-ui-desktop.md`. **Jangan mulai fase berikutnya sebelum DoD fase
   sebelumnya lengkap.** `fase-24-clipper-android.md` DIBLOKIR, jangan disentuh.

## 2. Gambaran kondisi saat ini (terverifikasi 15 Okt 2026, `feature/trading-assistant` @ `6a3636c`)

| Hal | Kondisi |
|---|---|
| `aura_core/lib/src/llm_router/` | Ada (8 file), diekspor di `aura_core.dart`, 7 file test |
| `aura_desktop` memakai router | Ya, `desktop_chat_provider.dart` memakai `LlmRouterClient` → **"Fase 0" di PRD sudah terpenuhi** (verifikasi dengan satu panggilan nyata di Fase 22) |
| `aura_clipper` | Ada sebagai package: model, pipeline, 4 service, `ClipDatabase`, 4 widget **stub** |
| `aura_clipper.dart` | Masih stub `Calculator`; test juga masih `Calculator` |
| Dipakai oleh desktop/mobile | **Belum** ada yang mengimpor |
| Konflik versi | `aura_clipper` Riverpod `^2.5.1` vs desktop `^3.0.0` |
| `ClipDatabase` | `PRAGMA foreign_keys` tidak aktif, `saveCandidates` tanpa transaksi |
| Transcriber | Default `ggml-base.en.bin` (Inggris saja), tanpa pilihan bahasa |
| Analyzer | Satu prompt untuk seluruh transkrip, tanpa chunking & validasi hasil |
| UI | `ClipperScreen` = "MVP UI Pending", `ClipPreviewPlayer` = stub |
| Navigasi desktop | `_activeNavIndex`: 0 Chat, 1 Trading Lab (`main.dart` ±baris 1720) |
| Secure storage key | `gemini_api_key`, `openai_api_key`, `anthropic_api_key`, `groq_api_key` |

## 3. Daftar pekerjaan

| Fase | Isi | Dokumen | Status |
|---|---|---|---|
| 21 | Fondasi package: pubspec, interface, ProcessRunner, DB, settings, test | `workflows/fase-21-clipper-foundation.md` | siap |
| 22 | Pipeline nyata: yt-dlp (+heatmap, caption), Whisper, analyzer (chunking, range/focus, validasi), FFmpeg | `workflows/fase-22-clipper-pipeline.md` | setelah 21 |
| 23 | UI & integrasi `aura_desktop` | `workflows/fase-23-clipper-ui-desktop.md` | setelah 22 |
| 24 | Android | `workflows/fase-24-clipper-android.md` | **diblokir** |

## 4. Aturan kerja ringkas

- **Jangan ubah `aura_core/`.** Temuan bug di `llm_router` → tulis di laporan, jangan diperbaiki.
- `aura_clipper` tidak boleh mengimpor `aura_desktop`/`aura_mobile`. Host mengirim konfigurasi.
- `Process.*` hanya di `lib/src/desktop/`. Tanpa shell, argumen sebagai list.
- Tidak ada klip dummy/fallback saat LLM gagal. Error jelas + `analysis_raw.log`.
- Repo **publik**: jangan commit video, wav, transkrip, klip, model `ggml-*.bin`, `*.db`,
  `secure_credentials.json`. Cek `git status` sebelum `git add`.
- Branch `feature/aura-clipper` dari `feature/trading-assistant`. **Push di akhir tiap fase.**
- Commit: `feat(clipper): ...`, `fix(clipper): ...`, `test(clipper): ...`, `docs(clipper): ...`.
- Hal yang belum diputuskan (Whisper lokal vs API, Android, Supabase, crop 9:16, subtitle):
  **berhenti dan tanyakan**, jangan memilih sendiri.
- Tidak yakin tentang perilaku tool eksternal (bentuk JSON yt-dlp, flag whisper.cpp, dll.):
  **jalankan dan lihat hasil nyatanya**, jangan menebak dari ingatan.
- **Laporan harus jujur soal bukti.** Bukti = keluaran terminal asli atau tangkapan layar aplikasi yang benar-benar berjalan. Dilarang menggambar/membuat tiruan yang menyerupai bukti (mock evidence generator). AGY tidak boleh membuat bukti pengganti sendiri. Bila tidak bisa dijalankan di lingkungan agen, tulis "belum dijalankan" secara jujur.

## 5. Perintah standar

```bash
# Fondasi & pipeline
cd C:/devapp/AURA_MonoRepo/Project-A.U.R.A-Agent/aura_clipper
flutter pub get
flutter analyze
flutter test

# Uji integrasi di desktop
cd ../aura_desktop
flutter pub get
flutter run -d windows

# Sebelum commit
git status        # pastikan tidak ada video/model/db/secret
```

## 6. Format laporan per fase (`.agents/reports/CLIPPER_FASE_XX.md`)

1. **Ringkasan** — apa yang selesai, apa yang tidak.
2. **File berubah/baru** — daftar path.
3. **Keluaran** `flutter analyze` dan `flutter test` (ringkasan angka; tempel kegagalan jika ada).
4. **DoD** — salin daftar DoD fase dengan centang jujur; yang tidak tercentang diberi alasan.
5. **Penyimpangan dari dokumen** — dan kenapa.
6. **Dependency baru** — nama, versi, alasan (Insiden 2).
7. **Temuan** — bug di luar scope (mis. di `llm_router`), pertanyaan terbuka untuk user.
8. **Bukti uji manual** (Fase 22–23) — video yang dipakai, durasi proses, tangkapan layar.
9. **Commit/branch** — hash terakhir dan konfirmasi sudah di-push.

## 7. Entri yang perlu ditambahkan ke `.agents/INDEX.md`

Tambahkan bagian berikut (INDEX saat ini hanya memuat daftar trading):

```
### AURA Clipper
- Brief utama: .agents/AGY_TASK_CLIPPER_BRIEF.md
- Rules: .agents/rules/19-aura-clipper.md
- Workflows: fase-21 (fondasi), fase-22 (pipeline), fase-23 (UI desktop), fase-24 (Android, DIBLOKIR)
- PRD: .agents/PRD_AURA_Clipper.md
```
