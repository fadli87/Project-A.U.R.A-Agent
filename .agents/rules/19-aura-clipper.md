# Rule: AURA Clipper — Keputusan Final & Pagar Pengaman

Baca ini sebelum mengerjakan Fase 21–24. Baca juga `.agents/rules/00-checklist-insiden.md`
(terutama Insiden 2 dan 7) dan `.agents/PRD_AURA_Clipper.md` untuk konteks produk.

## Status keputusan

**FINAL (sudah diputuskan user, jangan diimprovisasi ulang):**
1. `aura_clipper` adalah **package di monorepo** (sejajar `aura_core`, `aura_trading`),
   BUKAN app/repo terpisah. Host-nya `aura_desktop`.
2. **Flutter Desktop (Windows) dulu.** Android bukan bagian Fase 21–23.
3. Deteksi momen viral memakai **`llm_router` yang sudah ada di `aura_core`**
   (`LlmRouterClient`). Jangan menulis klien LLM baru.
4. **Scope ramping.** Hanya fitur esensial dari referensi `galihjuansaputra/cheat-clip`:
   - heatmap ("most replayed") + pengayaan transkrip,
   - kandidat klip dari LLM,
   - range / custom focus (analisis hanya rentang waktu tertentu atau dengan arahan user),
   - export klip via FFmpeg.
5. **DIBUANG, jangan dibangun:** backend Python, tier proxy/Supadata, endpoint
   cookies/update, auto-discovery model, dan **fake fallback clips** (lihat bagian
   "Larangan keras").

**BELUM DIPUTUSKAN (jangan dikerjakan, jangan diasumsikan):**
- Whisper lokal penuh vs API.
- Jalur Android (remote ke PC / proses di perangkat / hybrid). Lihat Fase 24 (diblokir).
- Sinkron ke Supabase (schema `clipper`), auto-crop 9:16, burn-in subtitle (Fase 2–3 di PRD).
Kalau pekerjaan menyentuh salah satunya, **berhenti dan tanyakan**, jangan pilih sendiri.

## Arsitektur & batas modul

```
aura_clipper/                      (package, platform-netral kecuali folder desktop)
  lib/aura_clipper.dart            ← barrel: model, interface, pipeline, analyzer, db
  lib/aura_clipper_desktop.dart    ← barrel: implementasi Process.run (yt-dlp/ffmpeg/whisper)
  lib/aura_clipper_ui.dart         ← barrel: ClipperScreen & widget
  lib/src/models|pipeline|analysis|storage|desktop|ui
aura_desktop/lib/src/ui/desktop_clipper_screen.dart   ← glue ke host (pola sama dgn desktop_trading_screen.dart)
```

1. **`aura_clipper` TIDAK BOLEH import `aura_desktop` atau `aura_mobile`** (dependency
   melingkar). Hal yang dimiliki host (model/combo terpilih, API key, folder kerja)
   **dikirim lewat constructor / config object**, contoh: `MomentAnalyzer` sudah menerima
   `modelOrCombo` dan `apiKeys`. Pertahankan pola itu.
2. **JANGAN ubah `aura_core/`.** Kalau menemukan bug di `llm_router` (sudah direview 3
   putaran terhadap sumber Go-nya), **laporkan di laporan fase**, jangan diperbaiki diam-diam.
   `resolveDesktopModelOrCombo` tetap di `aura_desktop`; host yang memanggilnya.
3. Semua pemakaian `Process.run/start` hanya boleh di `lib/src/desktop/`. Pipeline dan
   analyzer bergantung pada **interface** (`Downloader`, `Transcriber`, `Exporter`), supaya
   jalur Android nanti cukup menyediakan implementasi lain tanpa membongkar pipeline.
4. State management: **Riverpod 3** (`Notifier`/`AsyncNotifier`). Tanpa `riverpod_generator`
   dan tanpa `build_runner` di package ini.
5. Navigasi desktop: `aura_desktop/lib/main.dart` memakai `_activeNavIndex` (0 = Chat,
   1 = Trading Lab, sekitar baris 1720). Clipper jadi **index 2**. Sentuh `main.dart`
   seminimal mungkin (import + satu entri navigasi); logika host taruh di file baru.

## Keamanan & keandalan (wajib)

1. **Tanpa shell, tanpa string command.** `Process.start(exe, [args...])` dengan list
   argumen. Jangan pernah `cmd /c` atau interpolasi URL ke string perintah.
2. **URL = input tidak tepercaya.** Validasi skema `http`/`https` dan host yang diizinkan
   (default: `youtube.com`, `youtu.be`, plus daftar yang bisa ditambah di settings).
   Di argumen yt-dlp, taruh `--` sebelum URL supaya URL berawalan `-` tidak terbaca sebagai
   opsi.
3. **Transkrip = input tidak tepercaya (prompt injection).** Di prompt analyzer, bungkus
   transkrip dengan delimiter jelas dan instruksikan model untuk mengabaikan perintah di
   dalamnya. Output model selalu divalidasi, tidak dipercaya mentah.
4. **Nama file.** Jangan pakai `%(title)s` mentah. Pakai folder kerja per-job
   `<appSupport>/clipper/jobs/<jobId>/` dan template `%(id)s.%(ext)s`. Semua artefak
   (video, wav, transkrip, klip) hidup di folder job itu, bukan di folder video sumber.
5. **API key** hanya lewat `SecureStorageService` (DPAPI via `DesktopSecureStorage`).
   Key yang dipakai: `gemini_api_key`, `openai_api_key`, `anthropic_api_key`,
   `groq_api_key`. Jangan simpan key di SQLite, file settings, atau log. Jangan log
   isi prompt/transkrip penuh di level default.
6. **Setting non-rahasia** (path tool, bahasa, folder output) disimpan di file JSON
   `clipper_settings.json` di app support dir. Bukan `SharedPreferences` (tidak ada di
   dependency desktop) dan bukan secure storage.
7. **Proses panjang harus bisa dibatalkan** (`process.kill()`), punya timeout, dan melapor
   progres. `Process.run` yang memblokir sampai selesai tidak boleh dipakai untuk
   download/transkripsi/export.
8. **Repo ini PUBLIC.** Jangan commit video, `.wav`, transkrip, klip `.mp4`, model
   `ggml-*.bin`, `*.db`, atau `secure_credentials.json`. Periksa `.gitignore` sebelum
   `git add`.
9. **Legal.** yt-dlp hanya untuk video milik sendiri atau yang punya izin repurpose.
   Tampilkan satu kalimat pengingat di UI (cukup di dialog pertama kali), jangan lebih.

## Larangan keras

- **Jangan pernah mengembalikan klip palsu/dummy saat LLM gagal atau responsnya tidak
  bisa di-parse.** Tampilkan error yang jelas dan simpan respons mentah ke file log job
  (tanpa API key). Klip fiktif membuat user mengekspor potongan yang tidak ada artinya.
- Jangan auto-download binary (yt-dlp/ffmpeg/whisper) di Fase 21–23. Cukup deteksi path,
  uji `--version`, dan beri pesan instalasi yang jelas.
- Jangan menambah dependency yang tidak dipakai (Insiden 2). Tiap dependency baru harus
  disebut di laporan fase beserta alasannya.
- Jangan menambah plugin native Windows tanpa cek komponen Visual Studio (Insiden 7):
  jalankan `flutter clean` lalu build ulang, dan catat hasilnya.

## Konvensi

- Commit: `feat(clipper): ...` / `fix(clipper): ...` / `test(clipper): ...` / `docs(clipper): ...`.
- Branch kerja: `feature/aura-clipper` (cabang dari `feature/trading-assistant`).
  **Push ke origin di akhir setiap fase.** Pekerjaan yang belum di-push dianggap belum ada.
- Setiap fase ditutup dengan `flutter analyze` (0 error, 0 warning) dan `flutter test`
  hijau di `aura_clipper`, lalu satu laporan di `.agents/reports/CLIPPER_FASE_XX.md`
  (format di `.agents/AGY_TASK_CLIPPER_BRIEF.md`).
