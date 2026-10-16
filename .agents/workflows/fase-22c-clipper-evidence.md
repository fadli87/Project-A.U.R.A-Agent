# Workflow: Fase 22c — AURA Clipper: Bukti Uji Nyata (WAJIB sebelum Fase 23)

Baca `.agents/rules/19-aura-clipper.md` dan `fase-22b-clipper-hardening.md` (Prioritas 3) dulu.

**Konteks:** Review kode `ad9c7c1`. Perbaikan kode 22b (PID reuse, `--sub-langs` tanpa `all`,
parser netral, `enforceClipBounds`, `tokenBudget` 12.000, try-catch per chunk) terbaca benar.
Yang **belum** ada adalah bukti. Laporan 22b menulis "SELESAI 100%", padahal:

| Klaim / DoD 22b | Kenyataan di laporan |
|---|---|
| Uji end-to-end nyata (caption + Whisper) dengan angka | **Baris ini hilang dari tabel DoD laporan.** `smoke_test.dart` ada tapi tidak pernah dijalankan (tidak ada keluaran). Tanpa `TEST_VIDEO_URL` ia `return` diam-diam, jadi terlihat lulus. |
| "Bahasa benar" | Diuji dengan Rickroll (Inggris) lewat perintah PowerShell manual, bukan lewat `YtDlpDownloader`, bukan video Indonesia, `-orig` belum dicoba. |
| "Fallback Whisper" | `whisper-cli` belum pernah dijalankan; hanya fake. |
| Panggilan LLM sungguhan, jumlah chunk/kandidat | Tidak ada. |
| Waktu tiap langkah yt-dlp dan status 429 (22b butir 7) | Tidak dicatat. |
| Uji batal | Memakai `ping` (tanpa proses anak) — membuktikan guard PID dan Notepad, **bukan** pembunuhan pohon proses `yt-dlp`→`ffmpeg`. |

Juga: laporan menampilkan potongan `safeKill` yang tidak sama dengan kode sebenarnya, dan
menyebut "fallback bahasa Inggris" padahal default kode adalah `'id'`. Salin dari kode, jangan
dari ingatan.

## Tugas

### 1. Bersihkan `smoke_test.dart`
- Hapus path pribadi (`C:\Users\Fadli Santoso\...`) — repo publik. Path tool **hanya** dari
  environment (`YT_DLP_PATH`, `FFMPEG_PATH`, `WHISPER_PATH`, `FFPROBE_PATH`).
- Variabel wajib tidak ada → `markTestSkipped(...)` (muncul sebagai *skipped*), bukan `return`.
- Tambah `FORCE_WHISPER` benar-benar diteruskan ke pipeline/opsi (cek bahwa jalurnya ada).
- Setelah ekspor: ukur klip dengan `ffprobe`, assert durasi ≈ `end − start` (±0,5 dtk).
- Cetak: bahasa terdeteksi, nama file caption + jumlah `.json3`, jumlah segmen, jumlah chunk,
  jumlah kandidat, detik per stage, detik per panggilan yt-dlp.

### 2. Siapkan `whisper-cli.exe`
Setahu saya rilis resmi whisper.cpp untuk Windows menyertakan `whisper-cli.exe` — **cek di
rilisnya**, jangan menebak. Unduh sendiri (jangan di-commit), pakai model **multibahasa**
(`ggml-base.bin` atau `ggml-small.bin`, bukan `.en`). Jika benar-benar tidak tersedia, tulis
bukti perintah yang dijalankan dan **berhenti serta tanyakan**; jangan dicentang.

### 3. Jalankan smoke dua kali dengan video Indonesia
Video 3–5 menit, milik sendiri/berizin, berbahasa Indonesia, punya auto-caption.
- Run A: caption. Run B: `FORCE_WHISPER=true`.
- Tempel keluaran asli (bukan ringkasan) di `CLIPPER_FASE_22C.md`. Bandingkan jumlah segmen,
  bahasa, dan satu-dua kalimat awal transkrip kedua sumber.
- Pakai LLM sungguhan (kunci dari environment). Bila ada 429 dari yt-dlp, gabungkan subtitle
  ke panggilan unduh (22b butir 7) dan catat.

### 4. Uji batal nyata dengan tool asli
Mulai unduh video panjang lewat `YtDlpDownloader`, batalkan di tengah. Tempel
`tasklist | findstr /i "yt-dlp ffmpeg"` **sebelum dan sesudah**; hasil sesudah harus kosong
dan tidak ada file `.part` tersisa. Ulangi satu kali: batal saat tahap analisis LLM dengan
Notepad terbuka; Notepad harus tetap hidup.

### 5. Perbaiki laporan
Buat `.agents/reports/CLIPPER_FASE_22C.md` (format brief). Tambahkan **koreksi** satu paragraf
di `CLIPPER_FASE_22B.md` yang menyebut bahwa baris DoD "uji end-to-end" dan "bahasa benar"
belum terbukti saat laporan itu ditulis. Butir yang gagal/tidak terbukti ditulis "belum".

## Definition of Done
- [ ] Tidak ada path pribadi/rahasia di repo (`git grep -n "Users\\\\"` kosong)
- [ ] Smoke run A (caption, Indonesia) dengan keluaran asli terlampir; tepat 1 file `.json3`
- [ ] Smoke run B (Whisper multibahasa) dengan keluaran asli terlampir
- [ ] Klip hasil `FfmpegExporter` diukur `ffprobe`, selisih ≤ 0,5 dtk, dan diputar
- [ ] Uji batal `yt-dlp`/`ffmpeg` nyata: daftar proses sebelum/sesudah
- [ ] Uji Notepad tetap hidup saat batal di tahap analisis
- [ ] Waktu per langkah yt-dlp dan status 429 tercatat
- [ ] `flutter analyze` = 0, `flutter test` hijau; push ke origin
- [ ] Laporan `CLIPPER_FASE_22C.md` jujur; koreksi 22b ditambahkan

Fase 23 hanya boleh dimulai setelah semua butir di atas tercentang dengan bukti.
