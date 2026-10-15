# Workflow: Fase 22 — AURA Clipper: Pipeline Sungguhan (Download → Transkrip → Analisis → Export)

Baca `.agents/rules/19-aura-clipper.md` SEBELUM memulai.

**Tujuan:** Pipeline yang benar-benar bisa memproses satu video YouTube dari link sampai
klip MP4, sesuai scope ramping: heatmap + pengayaan transkrip, kandidat dari LLM,
range/custom focus, export FFmpeg.
**Prasyarat:** Fase 21 selesai (interface, ProcessRunner, DB, settings).

## A. Downloader (`YtDlpDownloader`)

1. Validasi URL (skema + host yang diizinkan) sebelum memanggil proses apa pun.
2. Satu panggilan `--dump-json --no-playlist -- <url>` untuk metadata: `id`, `title`,
   `duration`, dan **`heatmap`** bila tersedia (daftar `{start_time, end_time, value}`).
   **Verifikasi bentuk JSON sebenarnya di mesin ini dengan video nyata** dan catat hasilnya
   di laporan; heatmap tidak selalu ada (video baru/kecil), jadi harus opsional.
3. Download: `-f 'bestvideo[height<=1080]+bestaudio/best[height<=1080]/best'`,
   `-o <jobDir>/%(id)s.%(ext)s`, `--no-playlist`, `--newline`, `--` sebelum URL. Parse
   persentase dari stdout untuk progres. Path hasil diambil dari `--print after_move:filepath`
   atau dengan memindai `<jobDir>` untuk `<id>.*` (pilih salah satu, jelaskan di laporan).
4. Caption YouTube (jika ada): `--write-auto-subs --sub-langs <bahasa|all> --sub-format json3
   --skip-download` ke `<jobDir>`. Dipakai sebagai sumber transkrip **tanpa Whisper** bila
   tersedia, karena jauh lebih cepat. Whisper menjadi fallback.
5. Dukung `CancelToken` (kill proses, bersihkan file `.part`) dan timeout.

## B. Transcriber (`WhisperCppTranscriber`) + pengayaan transkrip

1. Ekstrak audio 16 kHz mono WAV via ffmpeg ke `<jobDir>`; hapus WAV setelah selesai
   (juga saat gagal/dibatalkan).
2. **Bahasa:** jangan hardkod model Inggris. Default sekarang `ggml-base.en.bin`
   (hanya Inggris) akan gagal untuk konten Indonesia. Jadikan nama model dan bahasa
   (`-l <kode>` atau `auto`) bagian `ClipperSettings`; dokumentasikan di README model mana
   yang dipakai untuk bahasa Indonesia (model multibahasa, bukan `.en`).
3. Nama binary whisper.cpp berubah antar versi (mis. `main` → `whisper-cli`); path
   sepenuhnya dari settings, bukan ditebak.
4. Parser transkrip menghasilkan `Transcript` netral dari dua sumber: JSON whisper.cpp
   (`transcription[].offsets.from/to` dalam ms) dan caption `json3`.
5. **Pengayaan:** gabungkan segmen pendek (<1–2 detik) menjadi kalimat/segmen ~5–15 detik,
   dan lampirkan skor heatmap rata-rata per segmen bila heatmap ada
   (`TranscriptSegment.heat` opsional, 0–1 ternormalisasi).

## C. Analyzer (`MomentAnalyzer`)

1. **Chunking.** Satu prompt untuk seluruh transkrip podcast 2 jam akan melewati batas
   konteks banyak provider. Pecah transkrip per anggaran token (estimasi kasar
   karakter/4, anggaran dapat diatur), dengan overlap ~30–60 detik, analisis tiap chunk,
   gabungkan, buang duplikat/tumpang-tindih, urutkan skor.
2. **Range / custom focus.** Terima `AnalysisOptions { Duration? from, Duration? to,
   String? focus, int maxClips, Duration minLen, Duration maxLen }`. Hanya segmen dalam
   rentang yang dikirim ke LLM. `focus` (mis. "momen lucu", "bagian yang membahas X") masuk
   ke prompt sebagai arahan user, di luar blok transkrip.
3. **Prompt.** Keluaran JSON array ketat. Judul klip memakai **bahasa transkrip**.
   Sertakan petunjuk heatmap ("segmen bertanda ▲ paling banyak diputar ulang"). Bungkus
   transkrip dengan delimiter dan perintahkan model mengabaikan instruksi di dalamnya
   (`rules/19`, keamanan butir 3).
4. **Parameter panggilan:** `temperature` rendah (≈0.2–0.3), `maxTokens` cukup untuk
   N klip (default 1024 bisa terpotong), `comboStrategy` tetap default.
5. **Parsing & validasi per item**, bukan all-or-nothing:
   - ekstrak JSON: blok ```json, lalu fallback dari `[` pertama ke `]` terakhir,
   - `start < end`, keduanya dalam `[0, durasi video]`, panjang di antara `minLen`–`maxLen`
     (default 20–60 dtk) atau dipotong ke batas, `score` di-clamp 0–100,
   - sejajarkan ke batas segmen transkrip terdekat supaya klip tidak mulai di tengah kata,
   - item invalid dibuang dan dicatat; jika **nol** item valid → lempar error jelas yang
     memuat ringkasan alasan dan **menyimpan respons mentah** ke `<jobDir>/analysis_raw.log`.
     **Tidak ada klip fallback/dummy.**
6. `sessionId: 0` untuk `ChatMessage` (tipe `int`).

## D. Exporter (`FfmpegExporter`)

1. Output ke `<outDir>` (folder yang dipilih user atau `<jobDir>/exports/`), bukan di sebelah
   video sumber. Nama aman: `<id>_<mm>m<ss>s-<mm>m<ss>s.mp4`.
2. Re-encode `libx264 -preset fast -c:a aac` (akurat per frame) dengan `-movflags +faststart`.
   Argumen sebagai fungsi murni yang diuji.
3. Progres dari `-progress pipe:1` bila mudah; minimal state "mengekspor…" + pembatalan.
4. Verifikasi file hasil ada dan berukuran > 0; kalau tidak, error.

## E. Penyatuan

1. `ClipperPipeline.run(...)` menyimpan job dan kandidat ke `ClipDatabase` di setiap
   transisi stage. Job yang `error` menyimpan pesan, bukan stack trace penuh.
2. Cek tool: `ToolCheck` menjalankan `--version` tiap tool dan mengembalikan daftar status
   + pesan instalasi manusiawi (dipakai UI Fase 23).
3. Test: parser caption/whisper dengan fixture kecil, validasi & chunking analyzer dengan
   `LlmRouterClient` palsu (stream `RouterTextDelta`), argumen yt-dlp/ffmpeg, dan satu skenario
   "LLM mengembalikan sampah → error, bukan klip".
4. **Uji manual satu video nyata** (pendek, milik sendiri/berizin) dan tempel hasilnya di laporan.

## Definition of Done
- [ ] Satu video nyata berhasil: link → klip MP4 yang bisa diputar
- [ ] Caption dipakai bila ada, Whisper sebagai fallback; keduanya menghasilkan `Transcript` sama
- [ ] Transkrip panjang tidak melewati anggaran konteks (chunking terbukti oleh test)
- [ ] Range/custom focus membatasi apa yang dikirim ke LLM (terbukti oleh test)
- [ ] Respons LLM sampah → error + `analysis_raw.log`, nol klip dummy
- [ ] Pembatalan menghentikan proses dan membersihkan file sementara
- [ ] Tidak ada file besar/rahasia ter-stage di git
- [ ] `flutter analyze` = 0, `flutter test` hijau, laporan `CLIPPER_FASE_22.md`, push
