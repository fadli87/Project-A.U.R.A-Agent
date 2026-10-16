# Workflow: Fase 22b — AURA Clipper: Perbaikan Hasil Review Fase 22 (WAJIB sebelum Fase 23)

Baca `.agents/rules/19-aura-clipper.md` dan bagian 0 + A–E di
`.agents/workflows/fase-22-clipper-pipeline.md` terlebih dulu.

**Konteks:** Review kode `feature/aura-clipper` @ `2bed3c2`/`f59a752` (dibaca langsung,
test tidak dijalankan oleh reviewer). Struktur dan sebagian besar perbaikan Fase 21 sudah
benar (UTF-8 longgar, `cancelled`, `StreamController`, `--progress`, sanitasi delimiter,
`analysis_raw.log`, tanpa klip dummy, tidak ada media/rahasia ter-commit). Tetapi ada
**dua bug yang bisa merugikan user**, beberapa pelanggaran aturan arsitektur, dan **klaim
DoD yang belum didukung bukti**. Jangan mulai Fase 23 sebelum DoD di bawah lengkap.

## Prioritas 1 — Bug berbahaya / merusak hasil

### 1. `taskkill` bisa membunuh proses yang tidak terkait (PID reuse)
`DesktopProcessRunner.run` mendaftarkan `cancel.onCancel(() => killProcessTree(process.pid, ...))`
dan **tidak pernah melepasnya** setelah proses selesai. `CancelToken` yang sama dipakai
berurutan untuk semua langkah (dump-json, subtitle, download, ffmpeg, whisper). Saat user
membatalkan di langkah berikutnya (mis. saat analisis LLM), **semua listener lama menyala**
dan menjalankan `taskkill /PID <pid lama> /T /F`. Windows mendaur ulang PID dengan cepat, jadi
perintah itu bisa mematikan proses **aplikasi lain milik user**. Blok `catch` juga memanggil
`killProcessTree` setelah proses sudah selesai.
**Perbaikan:**
- Tandai `exited = true` begitu `process.exitCode` selesai; semua jalur kill (listener
  cancel, timer timeout, blok `catch`) harus **no-op bila `exited`**.
- Buat `CancelToken.onCancel` mengembalikan pelepas (disposer) dan lepaskan listener di
  `finally` setiap `run()`.
- Buat fungsi pembunuh bisa disuntikkan (parameter konstruktor `killer`) supaya bisa diuji
  tanpa `taskkill` sungguhan.
**Test wajib:** (a) token dibatalkan **setelah** `run()` selesai → pembunuh **tidak**
dipanggil; (b) token dibatalkan **saat** proses berjalan (fake yang menunda) → dipanggil
tepat sekali dengan PID yang benar; (c) timeout memanggil pembunuh sekali.

### 2. Caption: bahasa salah dan unduhan massal
`buildSubtitlesArgs` memakai `--sub-langs 'id,en,all'` dengan `--write-auto-subs`. Setahu
saya, `all` pada auto-caption YouTube berarti **semua bahasa terjemahan otomatis** (puluhan
sampai ratusan permintaan, rawan HTTP 429 yang lalu menggagalkan unduhan video), dan kode
lalu mengambil `json3Files.first` — file **sembarang**, jadi transkrip bisa berbahasa lain.
Bug yang sama ada di fallback `listSync()` di `ClipperPipeline`.
**Perbaikan:**
- Tentukan bahasa sumber dari metadata `--dump-json` (`language`, atau kunci
  `automatic_captions` berakhiran `-orig`), atau dari pengaturan bahasa user bila diisi.
- Minta **satu** bahasa eksplisit (pakai `<kode>-orig` untuk auto-caption asli bila ada).
  Utamakan subtitle manual (`--write-subs`) di atas auto-caption.
- Pilih file `<id>.<bahasa>.json3` yang cocok dengan bahasa itu; jika tidak ada → **jatuh ke
  Whisper**, bukan mengambil file lain.
- Hapus pemindaian `.first` di pipeline; pipeline hanya memakai `DownloadResult.captionPath`.
- **Verifikasi dengan video berbahasa Indonesia yang punya auto-caption** dan catat nama
  file + jumlah file `.json3` yang terunduh (harus 1).
**Test wajib:** pembangun argumen tidak pernah memuat `all`; pemilihan file memilih bahasa
yang benar di antara beberapa fixture; tanpa caption cocok → Whisper dipakai.

## Prioritas 2 — Aturan arsitektur & kualitas hasil

3. **Pipeline (netral) mengimpor file desktop.** `clipper_pipeline.dart` mengimpor
   `../desktop/whisper_cpp_transcriber.dart` hanya untuk `parseJson3`. Itu melanggar
   `rules/19` (inti netral tidak boleh bergantung pada implementasi desktop; jalur Android
   nanti terhambat). Pindahkan `parseJson3` dan `parseWhisperJson` ke
   `lib/src/analysis/transcript_parsers.dart` (netral), ekspor dari `aura_clipper.dart`.
   Pastikan `lib/src/pipeline/` dan `lib/src/analysis/` tidak mengimpor `lib/src/desktop/`
   (tambahkan satu test yang memindai impor, atau skrip pemeriksa di laporan).
4. **Durasi klip hanya dicek di prompt.** `minLen`/`maxLen` tidak ditegakkan; satu-satunya
   validasi `end − start ≥ 5 dtk`. LLM bisa mengembalikan klip 5 menit. Tegakkan di kode:
   klip harus di dalam `[from, to]` dan `[0, durasi video]` (teruskan `durationSeconds` dari
   `DownloadResult`), panjang dipaksa ke `[minLen, maxLen]` (potong akhir ke `maxLen` lalu
   snap ke batas segmen; buang jika di bawah `minLen` dan tidak bisa diperpanjang). Beri test
   untuk tiap kasus.
5. **Chunking terlalu halus.** Default `tokenBudget = 2500` (±10.000 karakter) memecah
   podcast 2 jam menjadi belasan panggilan LLM berurutan — lambat, mahal, dan menabrak batas
   RPM/RPD tier gratis. Model target punya konteks jauh lebih besar. Naikkan default ke
   kisaran 12.000 token dan jadikan nilai di `ClipperSettings`.
6. **Kegagalan per-chunk.** Kesalahan parse JSON ditelan diam-diam; kesalahan router
   di tengah daftar chunk membatalkan **seluruh** analisis dan membuang hasil chunk
   sebelumnya. Tangani per chunk: lanjut ke chunk berikut, kumpulkan hasil yang ada, dan
   tulis `analysis_raw.log` **kapan pun ada chunk yang gagal/kosong** (bukan hanya bila total
   nol). Hanya lempar `LlmAnalysisException` jika hasil akhir kosong, dengan ringkasan
   alasan per chunk di pesan error.
7. **Tiga panggilan yt-dlp per job** (dump-json, subtitle, video). Boleh dipertahankan, tapi
   catat di laporan berapa detik tiap langkah pada video uji dan apakah ada 429. Jika ada,
   gabungkan subtitle ke panggilan unduh video.

## Prioritas 3 — Bukti yang kurang (laporan Fase 22 menyatakan lebih dari yang dibuktikan)

Laporan Fase 22 mencentang tiga butir DoD tanpa bukti yang sepadan:

| Klaim di laporan | Bukti yang ada | Kekurangan |
|---|---|---|
| "Satu video nyata berhasil: link → klip MP4" | `ffmpeg -ss 2 -to 5` lewat CLI pada `test_in.mp4` lokal | Bukan lewat `FfmpegExporter`, bukan dari link YouTube, tanpa panggilan LLM, tanpa caption/Whisper |
| "Batal di Windows tidak menyisakan proses" | test yang hanya memeriksa daftar argumen `taskkill` | Tidak ada pembatalan nyata dan tidak ada pemeriksaan Task Manager |
| "Caption dipakai, Whisper fallback, keduanya menghasilkan Transcript sama" | test dengan fake | `whisper.cpp` dengan model asli belum pernah dijalankan |

**Kerjakan satu uji end-to-end nyata** dan lampirkan buktinya di `CLIPPER_FASE_22B.md`:
1. Video pendek (3–5 menit), **milik sendiri atau berizin**, berbahasa Indonesia dan punya
   auto-caption. Jalankan lewat `YtDlpDownloader` + `ClipperPipeline` + `FfmpegExporter`
   + `LlmRouterClient` sungguhan (tulis sebagai test bertag `smoke`, dilewati secara default,
   dijalankan manual: `flutter test --tags smoke`; tool path & API key dari environment,
   **tidak ditulis ke repo**).
2. Jalankan **dua kali**: sekali dengan caption, sekali memaksa Whisper (model multibahasa).
   Catat bahasa, jumlah segmen, waktu tiap stage, jumlah chunk, jumlah kandidat.
3. Ekspor satu klip lewat `FfmpegExporter`, ukur dengan `ffprobe` (durasi ≈ `end − start`),
   dan putar hasilnya.
4. **Uji batal nyata:** mulai download video yang lebih panjang, batalkan di tengah, lalu
   tempel bukti (daftar proses sebelum/sesudah) bahwa tidak ada `yt-dlp`/`ffmpeg` tersisa,
   dan bahwa batal di tahap analisis **tidak** mematikan proses lain.
5. Tambahkan juga satu uji manual: buka aplikasi lain (mis. Notepad) lalu batalkan job di
   tahap analisis; Notepad harus tetap hidup.

## Definition of Done
- [ ] PID reuse diperbaiki; tiga test di butir 1 hijau; listener dilepas setiap `run()`
- [ ] `--sub-langs` tidak pernah `all`; satu file `.json3` terunduh; bahasa benar; fallback Whisper
- [ ] `lib/src/pipeline/` dan `lib/src/analysis/` bebas impor dari `lib/src/desktop/`
- [ ] Durasi/rentang klip ditegakkan di kode, dengan test
- [ ] `tokenBudget` default dinaikkan dan dapat diatur; kegagalan per-chunk tidak membuang hasil lain
- [ ] Uji end-to-end nyata (caption + Whisper) terlampir dengan angka nyata
- [ ] Uji batal nyata terlampir, termasuk uji Notepad tetap hidup
- [ ] `flutter analyze` = 0, `flutter test` hijau di `aura_clipper` dan `aura_desktop`
- [ ] Laporan `.agents/reports/CLIPPER_FASE_22B.md` (format di brief); butir yang **tidak**
      terbukti ditulis jujur sebagai belum selesai, bukan dicentang; push ke origin
