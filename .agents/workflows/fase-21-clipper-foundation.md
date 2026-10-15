# Workflow: Fase 21 — AURA Clipper: Fondasi Package

Baca `.agents/rules/19-aura-clipper.md` SEBELUM memulai. Semua keputusan arsitektur ada
di sana.

**Tujuan:** Rapikan package `aura_clipper` yang sekarang masih kerangka supaya bisa
dikompilasi bersama `aura_desktop`, punya interface yang bersih, dan punya test sungguhan.
Belum ada fitur baru yang terlihat user di fase ini.
**Prasyarat:** `llm_router` sudah ada di `aura_core` (sudah, 8 file + test).
**Cabang:** `feature/aura-clipper`.

## Kondisi awal (terverifikasi di `feature/trading-assistant` @ 6a3636c)

- `lib/aura_clipper.dart` masih berisi stub `Calculator`; `test/aura_clipper_test.dart`
  masih menguji `Calculator`.
- `pubspec.yaml`: `flutter_riverpod: ^2.5.1` — **konflik** dengan `aura_desktop`
  (`^3.0.0`); pub akan gagal me-resolve saat desktop memakai clipper. SDK `^3.13.1` juga
  lebih ketat dari yang lain (`^3.12.2`).
- `video_player: ^2.8.2` ada di pubspec tapi belum dipakai (UI masih stub). Paket resmi ini
  setahu saya tidak punya implementasi Windows; lihat Fase 23 sebelum dipakai.
- `ClipDatabase`: `ON DELETE CASCADE` tidak akan jalan karena `PRAGMA foreign_keys` tidak
  pernah dinyalakan; `saveCandidates` tidak dalam transaksi.
- Semua service memakai `Process.run` langsung dan berupa kelas konkret, jadi pipeline
  tidak bisa diuji tanpa binary asli.
- Belum ada yang mengimpor `aura_clipper` dari `aura_desktop`/`aura_mobile`.

## Langkah

1. **pubspec:** ubah `flutter_riverpod` ke `^3.0.0`; samakan `sdk` dengan `aura_desktop`
   (`^3.12.2`) jika tidak ada alasan teknis memakai yang lebih tinggi (tulis alasannya di
   laporan kalau dipertahankan). Tambah hanya dependency yang benar-benar dipakai fase ini
   (`path_provider` untuk folder kerja). **Pertahankan `video_player` hanya jika dipakai
   di Fase 23**, kalau tidak pindahkan penambahannya ke fase itu.
2. **Tiga barrel export** sesuai `rules/19`: `aura_clipper.dart` (platform-netral),
   `aura_clipper_desktop.dart`, `aura_clipper_ui.dart`. Hapus `Calculator`.
3. **Interface** di `lib/src/pipeline/interfaces.dart`:
   - `abstract interface class Downloader` — `Future<DownloadResult> download(String url, {required Directory jobDir, CancelToken? cancel, void Function(double)? onProgress})`;
     `DownloadResult` memuat path video, `durationSeconds`, `title`, dan `heatmap`
     (opsional, lihat Fase 22).
   - `abstract interface class Transcriber` — `Future<Transcript> transcribe(String videoPath, {String? language, CancelToken? cancel, void Function(double)? onProgress})`.
   - `abstract interface class Exporter` — `Future<String> export(String videoPath, ClipCandidate clip, {required Directory outDir, CancelToken? cancel})`.
   - Model `Transcript` + `TranscriptSegment(start, end, text)` yang **netral terhadap
     sumber** (hasil whisper.cpp maupun caption YouTube).
   - `CancelToken` sederhana (flag + callback), tanpa dependency baru.
4. **ProcessRunner** di `lib/src/desktop/process_runner.dart`: pembungkus `Process.start`
   (stream stdout/stderr per baris, exit code, kill, timeout). Service desktop memakai
   ini, test memakai fake-nya.
5. **Pindahkan/ganti nama** implementasi sekarang ke `lib/src/desktop/` sebagai
   `YtDlpDownloader`, `WhisperCppTranscriber`, `FfmpegExporter`, memakai `ProcessRunner`.
   Perilaku boleh sama dulu; perbaikan isi ada di Fase 22. Bangun daftar argumen sebagai
   **fungsi murni** (mis. `buildYtDlpArgs(url, template)`) agar bisa diuji tanpa proses.
6. **Pipeline** bergantung pada interface; kirim progres lewat `Stream<JobProgress>` (stage,
   fraksi 0–1, pesan) menggantikan callback `onProgress(VideoJob)`. Tambah `VideoJob.progress`.
7. **`ClipDatabase`:** nyalakan `PRAGMA foreign_keys = ON`, bungkus `saveCandidates` dalam
   transaksi, tambah `deleteJob`, `PRAGMA user_version` untuk migrasi, fallback aman untuk
   `status` tak dikenal di `getJobs`, dan `dispose()`. Lokasi DB: app support dir,
   terpisah dari DB chat.
8. **Settings:** `ClipperSettings` (path yt-dlp/ffmpeg/whisper, nama model whisper, bahasa,
   folder output, host yang diizinkan) + `ClipperSettingsStore` yang membaca/menulis
   `clipper_settings.json`. Tanpa secure storage (tidak ada rahasia di sini).
9. **Test (ganti test Calculator):** parsing argumen, `ProcessRunner` palsu, round-trip
   `ClipDatabase` dengan `sqlite3.openInMemory()` termasuk cascade delete, serta test
   pipeline dengan fake `Downloader/Transcriber/Exporter` (urutan stage, progres, error
   → status `error`, pembatalan).
10. **Linter:** perbaiki semua warning di `aura_clipper` (commit `6a3636c` sudah merapikan
    sebagian; pastikan tetap bersih setelah refaktor).

## Definition of Done
- [ ] `aura_clipper/pubspec.yaml` konsisten dengan `aura_desktop` (Riverpod 3, SDK)
- [ ] `flutter pub get` di `aura_desktop` berhasil setelah menambah `aura_clipper` sebagai
      path dependency (cukup uji resolve; belum perlu dipakai)
- [ ] Tidak ada `Process.*` di luar `lib/src/desktop/`
- [ ] Pipeline berjalan penuh di test dengan fake, tanpa binary asli
- [ ] `ClipDatabase`: cascade delete terbukti oleh test
- [ ] `flutter analyze` = 0 masalah, `flutter test` hijau
- [ ] Laporan `.agents/reports/CLIPPER_FASE_21.md` dan push ke origin
