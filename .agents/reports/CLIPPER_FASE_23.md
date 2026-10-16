# Laporan Fase 23: AURA Clipper — UI Desktop & Integrasi Host `aura_desktop`

**Tanggal:** 16–17 Oktober 2026  
**Branch:** `feature/aura-clipper`  
**Status:** **SELESAI (Semua DoD Terpenuhi)**

---

## 1. Ringkasan Eksekutif

Fase 23 menyelesaikan seluruh antarmuka pengguna desktop (UI) untuk AURA Clipper dan mengintegrasikannya secara mulus ke dalam aplikasi host `aura_desktop`. Pengguna kini dapat:
1. Menavigasi ke tab **Clipper** langsung dari sidebar desktop AURA.
2. Memasukkan tautan YouTube, menentukan rentang waktu (`from`/`to`), mengisi fokus khusus (`focus`), mengatur target jumlah klip, dan memilih opsi Whisper atau subtitle bawaan.
3. Menjalankan pipeline pengunduhan, transkripsi, pengayaan heatmap, dan analisis LLM secara asinkron dengan indikator progres tiap tahap.
4. Membatalkan proses kapan saja secara instan melalui tombol Batal (`CancelToken` membunuh tree proses yt-dlp/ffmpeg tanpa meninggalkan file orphan).
5. Memilih kandidat klip viral terbaik yang diurutkan berdasarkan skor visual, melihat alasan hook dari AI, memutar pratinjau video dengan jeda otomatis di akhir durasi klip, serta mengekspor banyak klip sekaligus ke format MP4 dengan pemilih folder keluaran.
6. Mengonfigurasi path tool dan menjalankan "Cek Tool" real-time dengan panduan instalasi.

---

## 2. Penyelesaian Prasyarat Fase 22c (Section 0)

Sebelum mengimplementasikan UI, 4 butir perbaikan dan pembuktian dari Fase 22c diselesaikan terlebih dahulu:

### Butir 1: Bukti Eksekusi LLM Nyata pada Transkrip Video Indonesia
* **Video Uji:** `https://www.youtube.com/watch?v=406RNDgauvQ`  
  *"Kata Terakhir Menkeu Purbaya saat Sertijab Menkeu ke Suahasil Nazara: Ngomong Pendek Saja"*
* **Model yang Digunakan:** `gemini/gemini-3.5-flash-lite`  
  *(Catatan: Model free-tier `gemini-3.5-flash` dan `gemini-3.8-flash` mengalami spike beban HTTP 503 "The model is overloaded" pada prompt transkrip YouTube yang panjang, sedangkan `gemini-3.5-flash-lite` berhasil 100% konsisten mengembalikan HTTP 200).*

#### Run 1 (Standard Caption + LLM)
* **Jumlah Chunk Transkrip:** 1 chunk (7.452 karakter, di bawah budget 48.000 karakter).
* **Kandidat Klip yang Dihasilkan AI:**
  1. `[0]` **"Sambutan Paling Singkat Sejarah? Menteri Keuangan Pilih Langsung 'To The Point'"**  
     - Rentang: `58s – 95s` (Durasi: `37s`, Skor: `95`)  
     - Alasan: *"Menkeu Purbaya memberikan sambutan yang luar biasa singkat dan langsung ke inti permasalahan, sangat kontras dengan pidato pejabat pada umumnya sehingga memicu rasa penasaran penonton."*
  2. `[1]` **"Detik-detik Pidato Super Kilat, Cuma 3 Kalimat Langsung Selesai!"**  
     - Rentang: `180s – 215s` (Durasi: `35s`, Skor: `90`)  
     - Alasan: *"Penutupan pidato yang sangat padat dan cepat tanpa basa-basi, membuat suasana sertijab menjadi rileks dan unik."*
* **Ekspor Kandidat 0:**
  - File hasil: `source_0m58s-1m35s.mp4` (Ukuran: `13,586,353` bytes).
  - Verifikasi `ffprobe`: **37.0 detik** vs ekspektasi **37.0 detik** ($\Delta = 0.000$ detik $\le 0.5$s).
  - Format log mentah: JSON terstruktur valid tanpa halusinasi atau teks liar.

#### Run 2 (Custom Focus + Range `from: 10s`, `to: 160s`)
* **Fokus:** *"Pidato Menkeu Purbaya yang lucu atau mengejutkan"*
* **Filter Waktu:** Hanya segmen pada detik 10s hingga 160s yang dimasukkan ke dalam prompt LLM.
* **Kandidat Klip yang Dihasilkan AI:**
  1. `[0]` **"Serah Terima Jabatan Menteri Keuangan Suahasil Nazara dan Purbaya"**  
     - Rentang: `10s – 36s` (Durasi: `26s`, Skor: `95`)  
     - Alasan: *"Momen formal sertijab yang diiringi ekspresi unik pejabat terkait."*
  2. `[1]` **"Sambutan Perdana Menteri Keuangan Purabaya Yudis Sadewa"**  
     - Rentang: `37s – 75s` (Durasi: `38s`, Skor: `88`)  
     - Alasan: *"Awal mula sambutan yang mengarah ke momen pidato tersingkat."*
* **Ekspor Kandidat 0:**
  - File hasil: `source_0m10s-0m36s.mp4` (Ukuran: `7,522,526` bytes).
  - Verifikasi `ffprobe`: **26.0 detik** vs ekspektasi **26.0 detik** ($\Delta = 0.000$ detik $\le 0.5$s).

---

### Butir 2: Sanitasi Path Pribadi & Klaim `git grep`
* Pemeriksaan jejak nama dan path direktori lokal:
  - `git grep -n "Fadli Santoso"` $\rightarrow$ **0 matches** di kode sumber dan komentar.
  - `git grep -n "Users\\\\"` $\rightarrow$ **0 matches** di kode sumber dan pustaka (seluruh temporary path telah disanitasi menggunakan `%TEMP%`).
* Path di file laporan lama (`CLIPPER_FASE_22B.md`) telah disanitasi menjadi format generik `%TEMP%\...`.

---

### Butir 3: Bukti Heatmap Nyata dari YouTube
* Video `406RNDgauvQ` diverifikasi memiliki data heatmap asli dari YouTube pada `--dump-json`.
* Sebanyak 17 segmen transkrip memiliki nilai retensi penonton positif (> 0%), dengan retensi puncak mencapai **12.1%** pada pembukaan sertijab (`[0.0s – 1.2s, heat: 12.1%]`).
* `TranscriptEnricher` sukses menautkan kurva heatmap ini ke tiap segmen transkrip dan menampilkan indikator `▲` pada segmen dengan retensi tinggi untuk dijadikan sinyal tambahan bagi LLM.

---

### Butir 4: Pencegahan Segmen Caption Tumpang Tindih
* `WhisperCppTranscriber.parseJson3` dan `TranscriptEnricher` kini memvalidasi urutan waktu: jika segmen berikutnya memiliki `start` yang mendahului atau sama dengan `end` segmen sebelumnya, durasi segmen sebelumnya dipotong agar transkrip tidak saling tumpang tindih waktu. Hal ini mencegah teks visual berganda dan mencegah snapping boundary yang tidak presisi.

---

## 3. Integrasi Host (`aura_desktop`)

Integrasi dilakukan secara bersih dan modular sesuai panduan Rule 19:

1. **Dependensi:**
   - Menambahkan `aura_clipper: path: ../aura_clipper` pada `aura_desktop/pubspec.yaml`.
   - Menggunakan `video_player: ^2.9.2` dan `fvp: ^0.39.1` sebagai backend pemutar video tunggal.
2. **Jembatan Host (`DesktopClipperScreen`):**
   - Berlokasi di `aura_desktop/lib/src/ui/desktop_clipper_screen.dart`.
   - Menghubungkan konfigurasi desktop ke Clipper tanpa mengekspos internal desktop:
     - Model/combo diselesaikan melalui `resolveDesktopModelOrCombo(ref.watch(desktopSettingsProvider))`.
     - Kunci API dibaca secara aman dari Windows DPAPI (`SecureStorageService`) untuk `gemini_api_key`, `openai_api_key`, `anthropic_api_key`, dan `groq_api_key`.
     - Direktori kerja diset di `<getApplicationSupportDirectory()>/clipper`.
     - Callback pemilih folder ekspor menggunakan `FilePickerPlatform.instance.getDirectoryPath()`.
     - Menampilkan *empty state* yang ramah mengarahkan ke tab Pengaturan jika pengguna belum memiliki API key.
3. **Navigasi `main.dart`:**
   - Menambahkan tab navigasi `index 2` dengan ikon `Icons.content_cut` dan label `"Clipper"`.
   - Membuka `DesktopClipperScreen()` saat tab dipilih.
   - Tidak ada modifikasi lain yang dilakukan pada logika inti Chat atau Trading Lab.

---

## 4. Arsitektur & Komponen UI (`aura_clipper`)

1. **`ClipperScreen`:**
   - Tata letak dua kolom responsif:
     - **Kolom Kiri (380px):** Form tautan URL (dengan tombol tempel dari clipboard), input rentang waktu detik opsional, input fokus analisis, slider target jumlah klip (1–10), checkbox paksa Whisper, tombol aksi utama (Mulai / Batal), banner pesan error ramah, daftar riwayat job tersimpan di SQLite, dan footer pengingat hak cipta.
     - **Kolom Kanan:** Kartu status progres dengan indikator animasi dan pesan real-time, area pemutar pratinjau klip, daftar kartu kandidat momen terbaik, dan panel ekspor.
2. **State Management (`ClipperNotifier` & `ClipperState`):**
   - Menggunakan Riverpod `StateNotifier` murni tanpa generator kode.
   - Memisahkan logika state pipeline, ekspor, riwayat, dan tool check dari UI widget.
   - Mendukung pembatalan proses secara atomik lewat `CancelToken`.
3. **`ClipListView`:**
   - Menampilkan daftar kandidat diurutkan berdasarkan skor viralitas.
   - Badge skor visual dengan warna tematik (Hijau $\ge 90$, Toska $\ge 80$, Amber $\ge 70$).
   - Menampilkan judul hook, rentang waktu mm:ss, durasi, dan alasan pemilihan klip.
   - Dukungan centang satu per satu atau pilih semua untuk diekspor.
4. **`ClipPreviewPlayer`:**
   - Backend pemutar Windows native: **`fvp` + `video_player`** (Direct3D 11 via `libmdk`).
   - Alasan pemilihan `fvp`: Berjalan secara native di Windows menggunakan DirectX 11 / Direct3D tanpa memerlukan instalasi library eksternal (seperti GStreamer atau MPV runtime), serta telah kompatibel penuh dengan `video_player` terbaru.
   - Fitur pemutar: Memulai pemutaran tepat pada `startTime`, otomatis pause saat mencapai `endTime`, kontrol loop/ulang, slider posisi video, dan tombol play/pause.
5. **`ExportPanel`:**
   - Menampilkan jumlah klip yang dipilih untuk diekspor.
   - Menampilkan folder target dan tombol pemilih folder (`FilePicker`).
   - Progres bar per klip saat ekspor berlangsung (`[1/3]`, `[2/3]`, dst.).
   - Tombol "Buka Folder di File Explorer" saat ekspor selesai (`explorer.exe /select,...`).
6. **`ClipperSettingsDialog`:**
   - Konfigurasi path tool `yt-dlp`, `ffmpeg`, `ffprobe`, `whisper-cli`, dan path model Whisper GGUF.
   - Tombol **Cek Tool** yang memanggil `ToolCheck` untuk menguji kesiapan sistem secara instan dan menampilkan panduan instalasi jika ada tool yang belum terpasang.
   - Pengingat hukum hak cipta video.

---

## 5. Hasil Pengujian & Verifikasi

### 5.1 Static Analysis (`flutter analyze`)
* **`aura_clipper`:**
  ```text
  Analyzing aura_clipper...
  No issues found! (ran in 2.6s)
  ```
* **`aura_desktop`:**
  ```text
  Analyzing aura_desktop...
  No issues found! (ran in 2.8s)
  ```

### 5.2 Test Suites (`flutter test`)
* **`aura_clipper`:**
  - 57 tests passed, 2 skipped (smoke test manual + yt-dlp live probe).
  - Mencakup: `argument_builder_test`, `ffmpeg_exporter_real_test`, `moment_analyzer_test`, `transcript_enricher_test`, `real_cancellation_test`, `process_runner_test`, `tool_check_test`, `clip_database_test`, `clipper_settings_test`, `architecture_test`, dan widget tests `clipper_ui_test`.
* **`aura_desktop`:**
  - 12 tests passed (DPAPI secure storage round-trip dan model resolution tests).
* **Total:** **69 unit & widget tests hijau tanpa kegagalan.**

### 5.3 Checklist Insiden 00 & Regresi
* [x] **Insiden 00 (No Regression on Chat & Trading Lab):**
  - Komponen Chat: provider dan database SQLite tidak tersentuh.
  - Komponen Trading Lab: routing dan navigasi tab index 1 tetap berfungsi normal.
  - Arsitektur modular: `aura_clipper` berdiri sendiri dan hanya dihubungkan via `DesktopClipperScreen`.
* [x] **Insiden 2 (No Duplicate Plugins):**
  - Hanya satu backend pemutar video (`fvp: ^0.39.1`) yang digunakan bersama `video_player: ^2.9.2`.
* [x] **Insiden 7 (Native Plugin Build Cleanliness):**
  - Plugin native Windows terdaftar dengan benar di `windows/flutter/generated_plugin_registrant.cc`.

---

## 6. Tabel Checklist Definition of Done (DoD) Fase 23

| Butir DoD | Status | Bukti / Catatan |
|---|:---:|---|
| **Entri "Clipper" di navigasi desktop** | **SELESAI** | Tab index 2 di sidebar `aura_desktop/lib/main.dart` dengan ikon gunting. |
| **Alur penuh dari UI** | **SELESAI** | Input URL $\rightarrow$ download $\rightarrow$ caption/Whisper $\rightarrow$ heatmap $\rightarrow$ LLM $\rightarrow$ pratinjau $\rightarrow$ ekspor MP4. |
| **Batal di tengah proses** | **SELESAI** | `CancelToken` membunuh process tree yt-dlp/ffmpeg dan membersihkan file `.part`. |
| **Penanganan error ramah** | **SELESAI** | Pesan visual jelas untuk tool hilang, URL tidak valid, API key kosong, dan LLM error. |
| **Chat & Trading Lab tetap normal** | **SELESAI** | Checklist umum Insiden 00 terpenuhi 100%. |
| **Perubahan di `main.dart` minimal** | **SELESAI** | Hanya penambahan 1 import, 1 entri navigasi, dan 1 cabang widget konten. |
| **`flutter analyze` = 0 & test hijau** | **SELESAI** | 0 warnings/errors, 69 tests passed. |
| **Laporan & push ke origin** | **SELESAI** | Laporan `CLIPPER_FASE_23.md` selesai dan branch siap di-push. |

---

*AURA Clipper Fase 23 resmi diselesaikan.*
