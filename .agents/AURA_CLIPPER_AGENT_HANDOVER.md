# 📋 AURA Clipper — Agent Handover & Technical Documentation

> **Dokumen untuk:** AI Agent / Developer yang melanjutkan pekerjaan di perangkat lain (laptop/desktop)  
> **Repository:** `Project-A.U.R.A-Agent`  
> **Active Branch:** `feature/aura-clipper` (terakhir di-push pada commit `2bed3c2`)  
> **Base Branch:** `feature/trading-assistant`  
> **Target Package:** `aura_clipper/`  
> **Host App:** `aura_desktop/`  
> **Tanggal Pembaruan:** 16 Oktober 2026

---

## 1. Ringkasan Status Proyek

AURA Clipper adalah modul pembuat klip video otomatis berbasis AI (YouTube link → Download → Transkripsi/Caption → Analisis LLM via `aura_core` → Export klip MP4).

| Fase | Deskripsi | Status | Laporan |
|---|---|---|---|
| **Fase 21** | Fondasi Package `aura_clipper`, models, interfaces, ProcessRunner, SQLite DB, Settings Store | ✅ **SELESAI** | [.agents/reports/CLIPPER_FASE_21.md](file:///l:/dev_app/aura_monorepo/Project-A.U.R.A-Agent/.agents/reports/CLIPPER_FASE_21.md) |
| **Fase 22** | Perbaikan 8 Review Fase 21 + Pipeline Sungguhan (yt-dlp, whisper.cpp/caption, MomentAnalyzer chunking & heatmap, FFmpeg export, ToolCheck) | ✅ **SELESAI** | [.agents/reports/CLIPPER_FASE_22.md](file:///l:/dev_app/aura_monorepo/Project-A.U.R.A-Agent/.agents/reports/CLIPPER_FASE_22.md) |
| **Fase 23** | UI Desktop (`ClipperScreen`, Riverpod Notifier, Preview Player, Export Panel, integrasi `aura_desktop`) | ⏳ **BERIKUTNYA** | [.agents/workflows/fase-23-clipper-ui-desktop.md](file:///l:/dev_app/aura_monorepo/Project-A.U.R.A-Agent/.agents/workflows/fase-23-clipper-ui-desktop.md) |
| **Fase 24** | Portabilitas Android / Mobile | 📅 Terjadwal | [.agents/workflows/fase-24-clipper-android.md](file:///l:/dev_app/aura_monorepo/Project-A.U.R.A-Agent/.agents/workflows/fase-24-clipper-android.md) |

---

## 2. Arsitektur & Peta File `aura_clipper`

Modul `aura_clipper` dirancang modular dengan isolasi ketat platform desktop vs platform-netral:

```
aura_clipper/
├── lib/
│   ├── aura_clipper.dart                 ← Barrel platform-netral (Models, Interfaces, Pipeline, Storage, Analyzer)
│   ├── aura_clipper_desktop.dart         ← Barrel desktop (ProcessRunner, YtDlp, Whisper, Ffmpeg, ToolCheck)
│   ├── aura_clipper_ui.dart              ← Barrel UI (dipergunakan di Fase 23)
│   └── src/
│       ├── models/
│       │   ├── video_job.dart            ← VideoJob, VideoJobStatus (queued, downloading, transcribing, analyzing, done, cancelled, error)
│       │   └── clip_candidate.dart       ← ClipCandidate (title, startTime, endTime, score, reason)
│       ├── pipeline/
│       │   ├── interfaces.dart           ← Downloader, Transcriber, Exporter, DownloadResult, Transcript, TranscriptSegment, HeatmapPoint, CancelToken, JobProgress
│       │   └── clipper_pipeline.dart     ← ClipperPipeline (orkestrasi stream progres via StreamController, subtitle bypass, language passing)
│       ├── desktop/
│       │   ├── process_runner.dart       ← ProcessRunner & DesktopProcessRunner (allowMalformed UTF-8 decoder, taskkill /PID /T /F tree kill Windows)
│       │   ├── yt_dlp_downloader.dart    ← YtDlpDownloader (validasi URL, --dump-json heatmap, auto-subs json3, --progress, pembersihan .part)
│       │   ├── whisper_cpp_transcriber.dart ← WhisperCppTranscriber (16kHz WAV ffmpeg, parser json3 YouTube & whisper JSON, dynamic binary/model)
│       │   ├── ffmpeg_exporter.dart      ← FfmpegExporter (frame-accurate -ss -to -i, re-encode faststart, safe filename)
│       │   └── tool_check.dart           ← ToolCheck (mengecek yt-dlp, ffmpeg, whisper.cpp + panduan instalasi manusiawi)
│       ├── analysis/
│       │   ├── transcript_enricher.dart  ← TranscriptEnricher (merge segmen <1.5s ke ~5-15s, overlay heatmap retensi dengan marker ▲)
│       │   └── moment_analyzer.dart      ← MomentAnalyzer (chunking token budget, range from/to & focus, sanitasi prompt delimiter, snapping, 0 dummy clips + raw log)
│       └── storage/
│           ├── clip_database.dart        ← ClipDatabase (SQLite sqflite_common_ffi, PRAGMA foreign_keys, atomic transaction, inMemory helper)
│           └── clipper_settings.dart     ← ClipperSettings & ClipperSettingsStore (baca/tulis clipper_settings.json)
└── test/
    ├── aura_clipper_test.dart            ← Verifikasi export barrel
    ├── desktop/
    │   ├── argument_builder_test.dart    ← Test fungsi murni argumen yt-dlp, whisper, ffmpeg, parser json3 & whisper
    │   ├── process_runner_test.dart      ← Test fake runner, cancel token, UTF-8 malformed, argumen taskkill
    │   └── tool_check_test.dart          ← Test checker tool ketersediaan & kegagalan
    ├── analysis/
    │   ├── transcript_enricher_test.dart ← Test penggabungan segmen & skor heatmap
    │   └── moment_analyzer_test.dart     ← Test sanitasi delimiter, chunking, snapping, range filtering, error raw log
    ├── pipeline/
    │   └── clipper_pipeline_test.dart    ← Test orkestrasi pipeline, event progres halus, cancellation, subtitle bypass
    └── storage/
        ├── clip_database_test.dart       ← Test CRUD VideoJob, status cancelled, ClipCandidate cascade delete
        └── clipper_settings_test.dart    ← Test round-trip settings JSON
```

---

## 3. Rincian 8 Temuan Review Fase 21 yang Sudah Diperbaiki

Jika agen baru membaca riwayat commit, berikut 8 poin kritis yang telah diatasi pada `2bed3c2`:

1. **Decoder UTF-8 Subprocess:** Menggunakan `const Utf8Decoder(allowMalformed: true)` agar stdout/stderr yt-dlp/ffmpeg di Windows yang mengandung byte non-UTF8 tidak melempar `FormatException`.
2. **Pohon Proses Subprocess Windows:** `taskkill /PID <pid> /T /F` dengan `runInShell: false` digunakan untuk membunuh seluruh pohon proses (termasuk yt-dlp child dan ffmpeg child) pada pembatalan.
3. **Progres Halus ke UI:** `ClipperPipeline.run` menggunakan `StreamController<JobProgress>` (menggantikan `async*` lama) sehingga callback fraksi progres dari downloader dan transcriber langsung mengeluarkan event ke UI.
4. **Status Pembatalan Eksplisit:** `VideoJobStatus.cancelled` ditambahkan ke model dan database. `OperationCancelledException` tidak lagi tercatat sebagai "error".
5. **Konteks Diteruskan:** Opsi bahasa (`language`) diteruskan ke `transcriber.transcribe()`, dan data `heatmap` YouTube diteruskan ke `TranscriptEnricher.enrich()` untuk mengisi `TranscriptSegment.heat`.
6. **yt-dlp Progress Suppression:** Flag `--progress` ditambahkan ke `buildDownloadArgs` agar keluaran persentase tetap muncul saat `--print after_move:filepath` digunakan.
7. **MomentAnalyzer Hardening:**
   - Menghapus kode mati `analyzeTranscript(String)`.
   - Delimiter prompt `===TRANSCRIPT_END===` dinetralisir via `sanitizeTranscriptForPrompt`.
   - `AnalysisOptions.from/to` dan `focus` memfilter segmen sebelum dikirim ke LLM.
   - Snapping ke batas kata segmen transkrip terdekat dan deduplikasi klip tumpang tindih.
   - **TIDAK ADA klip fallback/dummy**. Jika LLM gagal, lempar `LlmAnalysisException` dan simpan respons mentah ke `<jobDir>/analysis_raw.log`.
8. **Akurasi Durasi Klip:** Pemotongan `-ss <start> -to <end> -i <src>` menghasilkan durasi eksak `end - start` (terverifikasi `ffprobe` deviasi 0.0s).

---

## 4. Cara Menjalankan & Verifikasi di Laptop Baru

### 1. Checkout Branch & Dependencies
```bash
git checkout feature/aura-clipper
git pull origin feature/aura-clipper
cd aura_clipper
flutter pub get
```

### 2. Jalankan Pengujian
```bash
# Di direktori aura_clipper
flutter analyze
flutter test

# Di direktori aura_desktop
cd ../aura_desktop
flutter pub get
flutter analyze
flutter test
```
*Hasil yang diharapkan: 0 issues pada analyze, 39 tests lulus di `aura_clipper`, 12 tests lulus di `aura_desktop`.*

### 3. Alat Eksternal yang Dibutuhkan (Desktop Windows)
AURA Clipper membutuhkan 3 binary eksternal pada runtime desktop:
1. **FFmpeg & FFprobe:** Pastikan tersedia di PATH Windows (atau konfigurasikan di settings).
   ```bash
   winget install Gyan.FFmpeg
   # Cek versi:
   ffmpeg -version
   ```
2. **yt-dlp:**
   ```bash
   winget install yt-dlp
   # Atau via python:
   pip install yt-dlp
   # Cek versi:
   yt-dlp --version
   ```
3. **whisper.cpp:**
   - Binary: `whisper-cli.exe` atau `main.exe` dari [whisper.cpp release](https://github.com/ggerganov/whisper.cpp/releases).
   - Model: `ggml-base.bin` atau `ggml-small.bin` (disimpan di folder lokal, path dimasukkan ke `ClipperSettings`).

*Catatan: Jika video YouTube memiliki auto-subtitles, AURA Clipper secara otomatis mengunduh caption `json3` dan membypass Whisper, sehingga proses transkripsi berjalan instan tanpa model Whisper.*

---

## 5. Panduan Pelaksanaan Fase 23 (UI Desktop)

Untuk agent yang akan memulai **Fase 23**, ikuti petunjuk pada [fase-23-clipper-ui-desktop.md](file:///l:/dev_app/aura_monorepo/Project-A.U.R.A-Agent/.agents/workflows/fase-23-clipper-ui-desktop.md):

### A. Komponen Host (`aura_desktop`)
- Buat `aura_desktop/lib/src/ui/desktop_clipper_screen.dart` sebagai perekat.
- Resolusi model: `resolveDesktopModelOrCombo(ref.watch(desktopSettingsProvider))`.
- Baca API Key dari `SecureStorageService` (`gemini_api_key`, `openai_api_key`, `anthropic_api_key`, `groq_api_key`).
- Direktori kerja: `<getApplicationSupportDirectory()>/clipper`.
- Tambahkan tab navigasi ke-3 di `aura_desktop/lib/main.dart` (index 2: "Clipper").

### B. Komponen UI (`aura_clipper/lib/src/ui/` diekspor via `aura_clipper_ui.dart`)
- **`ClipperScreen`:** Tata letak dua kolom:
  - Kiri: Input URL, rentang waktu (from–to), fokus kustom, slider jumlah klip, daftar riwayat job SQLite.
  - Kanan: Bilah progres beranimasi sesuai event `JobProgress`, daftar kandidat `ClipCandidate` berurutan skor dengan badge retensi heatmap, panel export.
- **State Management:** Riverpod 3 (`Notifier` / `AsyncNotifier`), tanpa logika bisnis di dalam widget.
- **Preview Player Windows:** Evaluasi paket pemutar video untuk desktop Windows (mis. `fvp` atau `media_kit`) dengan verifikasi pub.dev terlebih dahulu sesuai **Insiden 2** dan **Insiden 7**.
- **Dialog Settings:** Konfigurasi path tool + tombol **Cek Tool** yang memanggil `ToolCheck.checkAll(...)` untuk menampilkan status hijau/merah dan panduan instalasi.

---

## 6. Aturan Kerja & Batasan Kritis (Wajib Dipatuhi)
1. **Dilarang keras mengubah `aura_core/`** (Gunakan `LlmRouterClient` dan models yang sudah ada apa adanya).
2. **Isolasi Subprocess:** Seluruh eksekusi `Process.start` / `Process.run` hanya boleh berada di `aura_clipper/lib/src/desktop/` dengan `runInShell: false`.
3. **Zero Dummy Clips:** Jangan pernah membuat klip tiruan jika analisis LLM gagal. Selalu rekam kegagalan dan simpan respons mentah ke `analysis_raw.log`.
4. **Git Safety:** Jangan commit media (`.mp4`, `.wav`, `.part`, `.json3`), model (`.bin`, `.gguf`), atau database SQLite ke git.
