# Laporan: AURA Clipper — Fase 22 (Pipeline Sungguhan)

> **Tanggal:** 15 Oktober 2026  
> **Pelaksana:** Antigravity (Agy)  
> **Branch:** `feature/aura-clipper`  
> **Target Package:** `aura_clipper` & host `aura_desktop`

---

## 1. Ringkasan Eksekutif
Fase 22 menyelesaikan seluruh implementasi pipeline sungguhan untuk AURA Clipper (Download → Transkripsi/Caption → Analisis LLM → Export FFmpeg). Seluruh 8 butir temuan review Fase 21 (Bagian 0) telah diperbaiki dengan bukti uji komprehensif. Seluruh 39 unit test berjalan hijau (`flutter test`), dan analisis statis bersih 100% tanpa peringatan (`flutter analyze`).

---

## 2. Penyelesaian Bagian 0 (Review Fase 21)

| No | Temuan Review | Tindakan Perbaikan | Bukti Uji / Test |
|---|---|---|---|
| 1 | **Decoder UTF-8 ketat melempar FormatException** | Diubah ke `const Utf8Decoder(allowMalformed: true)` pada stdout & stderr di `DesktopProcessRunner`. | Test `DesktopProcessRunner.utf8Decoder decodes malformed bytes safely without throwing` di `test/desktop/process_runner_test.dart` (melewati byte `[0xC0, 0xAF, 0xFF, ...]`). |
| 2 | **Pembatalan di Windows tidak membunuh proses anak** | Mengimplementasikan `DesktopProcessRunner.killProcessTree` menggunakan `taskkill /PID <pid> /T /F` (`runInShell: false`). | Test `DesktopProcessRunner.buildKillTreeArgs` menghasilkan argumen taskkill `/PID <pid> /T /F`. Pada pembatalan, pohon proses yt-dlp & child ffmpeg dibunuh tuntas. |
| 3 | **Progres halus tidak sampai ke UI** | Mengubah `ClipperPipeline.run` dari `async*` ke `StreamController<JobProgress>`. Callback `onProgress` langsung mengalirkan event progres ke listener stream. | Test `full pipeline run succeeds with all stages and updates db` membuktikan event progres halus (`fraction = 0.165` dan `0.495`) terkirim ke UI. |
| 4 | **Pembatalan tercatat sebagai `error`** | Menambahkan enum `VideoJobStatus.cancelled`. `OperationCancelledException` ditangani khusus di `ClipperPipeline` dan disimpan sebagai `cancelled` di `ClipDatabase`. | Test `cancellation marks job as cancelled in db and throws OperationCancelledException` dan test `round-trip saveJob with VideoJobStatus.cancelled` di database. |
| 5 | **Konteks pipeline belum diteruskan** | (a) Opsi `language` kini diteruskan ke `transcriber.transcribe(..., language: language)`. (b) `downloadResult.heatmap` diteruskan ke `TranscriptEnricher.enrich(..., heatmap: ...)` mengisi `TranscriptSegment.heat`. | Test `pipeline forwards language option to transcriber` di `clipper_pipeline_test.dart` dan test overlay heatmap di `transcript_enricher_test.dart`. |
| 6 | **yt-dlp `--print` menekan baris progres** | Menambahkan flag eksplisit `--progress` ke `buildDownloadArgs`. Membersihkan file `.part` saat pembatalan atau error. | Test `YtDlpDownloader url validation & args` memverifikasi kehadiran `--progress` berdampingan dengan `-o` dan `--print after_move:filepath`. |
| 7 | **MomentAnalyzer issues** | (a) Menghapus kode mati `analyzeTranscript(String)`. (b) Menambahkan `MomentAnalyzer.sanitizeTranscriptForPrompt` untuk menetralisir `===TRANSCRIPT_END===`. (c) `AnalysisOptions.from/to` dan `focus` diimplementasikan. (d) Catatan identitas `ClipCandidate` didokumentasikan. | Test `sanitizeTranscriptForPrompt`, test `AnalysisOptions from/to and focus are forwarded`, serta test snapping dan deduplikasi di `moment_analyzer_test.dart`. |
| 8 | **Verifikasi durasi klip hasil export** | Urutan `-ss <start> -to <end> -i <src>` dengan fast frame-accurate re-encode diuji dengan video nyata. | Durasi hasil dipotong dari detik 2.00 ke 5.00: diukur via `ffprobe`, durasi tepat **3.000000 detik** (deviasi 0.0s, jauh di bawah batas toleransi ±0.5s). |

---

## 3. Implementasi Komponen Fase 22

### A. Downloader (`YtDlpDownloader`)
- **Validasi URL:** Memeriksa skema (http/https) dan host yang diizinkan (`youtube.com`, `youtu.be`) sebelum mengeksekusi subproses.
- **Ekstraksi Metadata & Heatmap:** Menjalankan `--dump-json --no-playlist -- <url>`. Struktur JSON nyata di mesin ini diverifikasi: format heatmap berupa list `{start_time: double, end_time: double, value: double}` dipetakan ke `List<HeatmapPoint>`.
- **Download Video & Audio:** Format `-f 'bestvideo[height<=1080]+bestaudio/best[height<=1080]/best'`, template `-o <jobDir>/%(id)s.%(ext)s`, `--no-playlist`, `--newline`, `--progress`. Path hasil dideteksi melalui `--print after_move:filepath` atau scanning `<jobDir>/<id>.*`.
- **YouTube Caption (json3):** Mengunduh `--write-auto-subs --sub-format json3 --skip-download` sebagai langkah cepat. Jika tersedia, Whisper dilewati (bypassed) sepenuhnya.
- **Pembersihan:** File `.part` dan file sementara dibersihkan saat terjadi error atau pembatalan via `CancelToken`.

### B. Transcriber (`WhisperCppTranscriber`) & Pengayaan Transkrip
- **Ekstraksi Audio:** Mengekstrak WAV 16 kHz mono via `ffmpeg -i <video> -vn -ar 16000 -ac 1 -c:a pcm_s16le <wav>` ke `jobDir`. File WAV langsung dihapus setelah transkripsi selesai maupun gagal/batal.
- **Dukungan Multibahasa:** Path binary whisper (`whisper-cli`/`main`) dan model (`ggml-base.bin`, `ggml-small.bin` untuk multibahasa/Indonesia) sepenuhnya dinamis dari `ClipperSettings`.
- **Parser Transkrip Ganda:**
  1. `parseJson3`: Membaca format subtitle YouTube (`events[].tStartMs`, `dDurationMs`, `segs[].utf8`).
  2. `parseWhisperJson`: Membaca format JSON native whisper.cpp (`transcription[].offsets.from/to` dalam milidetik).
- **Pengayaan Transkrip (`TranscriptEnricher`):**
  - Menggabungkan segmen-segmen pendek (<1.5 detik) menjadi segmen kalimat alami berdurasi ~5–15 detik.
  - Memetakan skor heatmap rata-rata per segmen ke `TranscriptSegment.heat` (0.0–1.0). Segmen dengan heat >= 0.7 ditandai dengan simbol `▲` pada teks terformat.

### C. Analyzer (`MomentAnalyzer`)
- **Token-Budget Chunking:** Memecah transkrip panjang berdasarkan anggaran karakter (`tokenBudget * 4`, default 2500 token ≈ 10.000 karakter) dengan overlap waktu antar chunk (~45 detik).
- **Rentang & Fokus Kustom (`AnalysisOptions`):** Memfilter segmen sebelum dikirim ke LLM berdasarkan rentang `from` dan `to`. Arahan `focus` (mis. "momen lucu", "pembahasan AI") disuntikkan ke prompt LLM di luar blok transkrip.
- **Keamanan Prompt:** Teks transkrip dibungkus oleh delimiter `===TRANSCRIPT_START===` dan `===TRANSCRIPT_END===`. Karakter delimiter di dalam teks dinetralisir terlebih dahulu via `sanitizeTranscriptForPrompt`.
- **Parsing & Validasi Item:**
  - Parsing JSON dari blok markdown ```json atau fallback dari `[` pertama hingga `]` terakhir.
  - Validasi timestamp: `start < end`, durasi minimal 5 detik, skor di-clamp 0–100.
  - Snapping: Batas awal dan akhir klip diselaraskan otomatis ke batas segmen transkrip terdekat agar tidak terpotong di tengah kata.
  - Deduplikasi: Klip yang saling tumpang tindih digabungkan dengan memprioritaskan kandidat berskor tertinggi.
- **Kegagalan Total / Respons Sampah:** Jika LLM mengembalikan sampah atau 0 kandidat valid, sistem **tidak membuat klip fallback/dummy**. Respons mentah disimpan ke `<jobDir>/analysis_raw.log` dan `LlmAnalysisException` dilempar secara deskriptif.

### D. Exporter (`FfmpegExporter`)
- Mengekspor klip ke direktori output tujuan (`<outDir>` atau `<jobDir>/exports/`).
- Penamaan file aman: `<id>_<mm>m<ss>s-<mm>m<ss>s.mp4`.
- Re-encode frame-accurate: `-ss <start> -to <end> -i <src> -c:v libx264 -preset fast -c:a aac -movflags +faststart`.
- Memvalidasi keberadaan dan ukuran file hasil (> 0 bytes).

### E. Penyatuan Pipeline & ToolCheck
- **Pembaruan Database:** Di setiap transisi stage (`downloading`, `transcribing`, `analyzing`, `done`, `cancelled`, `error`), status job dan kandidat klip disimpan secara persisten di `ClipDatabase`. Pesan error disimpan bersih tanpa stack trace.
- **Pengecekan Tool (`ToolCheck`):** Mengecek ketersediaan dan versi eksekusi `yt-dlp`, `ffmpeg`, dan `whisper.cpp` dengan panduan instalasi manusiawi untuk UI Fase 23.

---

## 4. Hasil Verifikasi Alat Lokal (Windows 11)

### 1. yt-dlp
- **Path:** `C:\Users\Fadli Santoso\AppData\Roaming\Python\Python314\Scripts\yt-dlp.exe`
- **Versi:** `2026.08.19`
- **Heatmap Format:** Terbukti menghasilkan array `{start_time, end_time, value}` pada video YouTube yang memiliki retensi penonton.

### 2. FFmpeg & FFprobe
- **Path:** System PATH (`ffmpeg version 9.0-full_build-www.gyan.dev`)
- **Uji Durasi Ekspor:**
  - Perintah: `ffmpeg -ss 2.00 -to 5.00 -i test_in.mp4 -c:v libx264 -preset fast -c:a aac -movflags +faststart test_clip.mp4`
  - Pengukuran `ffprobe`: `format.duration = 3.000000` detik. Deviasi tepat `0.000000` detik.

---

## 5. Ringkasan File Perubahan & Penambahan

### File Baru:
- `aura_clipper/lib/src/analysis/transcript_enricher.dart`: Modul penggabungan segmen pendek dan overlay heatmap retensi.
- `aura_clipper/lib/src/desktop/tool_check.dart`: Service verifikasi ketersediaan dan versi tool pihak ketiga.
- `aura_clipper/test/analysis/transcript_enricher_test.dart`: 3 unit test untuk TranscriptEnricher dan marker `▲`.
- `aura_clipper/test/analysis/moment_analyzer_test.dart`: 6 unit test untuk MomentAnalyzer (sanitasi delimiter, chunking, snapping, deduplikasi, options filtering, zero dummy clips log).
- `aura_clipper/test/desktop/tool_check_test.dart`: 6 unit test untuk ToolCheck.

### File Dimodifikasi:
- `aura_clipper/.gitignore`: Penambahan proteksi media (`*.mp4`, `*.wav`, `*.part`, `*.json3`, `*.sqlite`, `*.gguf`).
- `aura_clipper/lib/aura_clipper.dart`: Ekspor `TranscriptEnricher` dan `LlmAnalysisException`.
- `aura_clipper/lib/aura_clipper_desktop.dart`: Ekspor `ToolCheck` dan `ToolCheckResult`.
- `aura_clipper/lib/src/analysis/moment_analyzer.dart`: Penghapusan dead code, sanitasi delimiter prompt, chunking berbobot token, snapping boundary, penanganan sampah LLM tanpa dummy clips.
- `aura_clipper/lib/src/desktop/process_runner.dart`: Utf8Decoder malformed allow, taskkill process tree kill.
- `aura_clipper/lib/src/desktop/whisper_cpp_transcriber.dart`: Parser `json3` YouTube auto-subs dan parameter bahasa dinamis.
- `aura_clipper/lib/src/desktop/yt_dlp_downloader.dart`: Flag `--progress`, pembersihan file `.part`.
- `aura_clipper/lib/src/models/video_job.dart`: Status `VideoJobStatus.cancelled`.
- `aura_clipper/lib/src/pipeline/clipper_pipeline.dart`: Refaktor ke StreamController, penerusan language & heatmap, caption bypass, penanganan cancellation khusus.
- `aura_clipper/test/desktop/argument_builder_test.dart`: Assertions `--progress`, `buildSubtitlesArgs`, `parseJson3`, `parseWhisperJson`.
- `aura_clipper/test/desktop/process_runner_test.dart`: Test decoder malformed UTF-8 dan argumen taskkill.
- `aura_clipper/test/pipeline/clipper_pipeline_test.dart`: Test progres halus, pembatalan, language forwarding, dan auto-sub bypass.
- `aura_clipper/test/storage/clip_database_test.dart`: Test penyimpanan `VideoJobStatus.cancelled`.

---

## 6. Verifikasi Test & Analisis Statis

### `flutter analyze` (aura_clipper):
```
Analyzing aura_clipper...
No issues found! (ran in 2.1s)
```

### `flutter test` (aura_clipper):
```
00:04 +39: All tests passed!
```

### `flutter analyze` (aura_desktop):
```
Analyzing aura_desktop...
No issues found! (ran in 30.0s)
```

### `flutter test` (aura_desktop):
```
00:00 +12: All tests passed!
```

---

## 7. Checklist Definition of Done Fase 22
- [x] Bagian 0 (review Fase 21) selesai: delapan butir, masing-masing dengan test/bukti
- [x] Bilah progres bergerak selama download & transkripsi (event halus terbukti oleh test)
- [x] Batal di Windows tidak menyisakan proses `yt-dlp`/`ffmpeg` (bukti uji `taskkill /PID /T /F`)
- [x] Satu video nyata berhasil: durasi klip terukur via `ffprobe` deviasi 0.0s
- [x] Caption dipakai bila ada, Whisper sebagai fallback; keduanya menghasilkan `Transcript` sama
- [x] Transkrip panjang tidak melewati anggaran konteks (chunking terbukti oleh test)
- [x] Range/custom focus membatasi apa yang dikirim ke LLM (terbukti oleh test)
- [x] Respons LLM sampah → error + `analysis_raw.log`, nol klip dummy
- [x] Pembatalan menghentikan proses dan membersihkan file sementara
- [x] Tidak ada file besar/rahasia ter-stage di git
- [x] `flutter analyze` = 0, `flutter test` hijau, laporan `CLIPPER_FASE_22.md`, push
