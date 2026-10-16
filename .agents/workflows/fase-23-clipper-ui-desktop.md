# Workflow: Fase 23 — AURA Clipper: UI & Integrasi ke `aura_desktop`

Baca `.agents/rules/19-aura-clipper.md` SEBELUM memulai.

**Tujuan:** Clipper bisa dipakai dari aplikasi desktop: tempel link, atur rentang/fokus,
lihat kandidat klip, pratinjau, export.
**Prasyarat:** Fase 22, 22b **dan 22c** selesai, dengan bukti uji end-to-end nyata (caption + Whisper) dan uji batal nyata di laporan `CLIPPER_FASE_22C.md`.

## 0. Sisa Fase 22c — KERJAKAN LEBIH DULU (kecil, sebelum menyentuh UI)

Review `b8926c1`: bukti caption/Whisper/batal-yt-dlp diterima. Yang masih kurang:

1. **LLM sungguhan belum pernah dijalankan** pada transkrip nyata (laporan 22c hanya menulis
   "siap dieksekusi"). Jalankan `flutter test --tags smoke` dengan `GEMINI_API_KEY` (atau
   provider lain) pada video `406RNDgauvQ`, run caption. Tempel keluaran asli: jumlah chunk,
   daftar kandidat (judul, rentang, skor), lalu **ekspor satu kandidat dari video nyata**
   lewat `FfmpegExporter`, ukur `ffprobe` (≈ `end − start`) dan putar. Ulangi sekali dengan
   `focus` + `from/to`. Bila LLM mengembalikan sampah, lampirkan `analysis_raw.log`.
2. **Klaim `git grep` di laporan 22c tidak benar untuk seluruh tree:** `reports/CLIPPER_FASE_22.md`
   dan `22B.md` masih memuat `<user>\...`. Ganti dengan `<user>`/`...`, lalu
   `git grep -n "<user>"` harus kosong. Koreksi kalimat "0 matches" di laporan 22c.
3. **Heatmap belum terbukti.** Kedua run menunjukkan `heat: 0%`. Cek `--dump-json` video ini
   punya `heatmap` atau tidak; jika tidak, coba video lebih populer dan tempel bentuk JSON
   nyata (field, rentang nilai). Jika bentuknya beda dari asumsi, perbaiki parser + test.
4. **Segmen caption tumpang tindih waktu** (`0.2–9.4s` lalu `5.4–17.2s`): ciri caption
   otomatis YouTube. Periksa `TranscriptEnricher`/`parseJson3`; pastikan tidak membuat teks
   ganda atau snapping klip yang tumpang tindih. Perbaiki dengan test bila perlu.

Butir 1 wajib selesai sebelum Bagian A; butir 2–4 boleh dalam satu commit `fix(clipper): ...`.

## A. Integrasi host (`aura_desktop`)

1. Tambah `aura_clipper: path: ../aura_clipper` di `aura_desktop/pubspec.yaml`.
2. Buat `aura_desktop/lib/src/ui/desktop_clipper_screen.dart` (pola sama dengan
   `desktop_trading_screen.dart`). File ini menjadi **satu-satunya perekat**:
   - `modelOrCombo` = `resolveDesktopModelOrCombo(ref.watch(desktopSettingsProvider))`
     (fungsi ini tetap di `aura_desktop`; jangan dipindah),
   - `apiKeys` = dibaca dari `SecureStorageService` untuk `gemini_api_key`,
     `openai_api_key`, `anthropic_api_key`, `groq_api_key`, hanya yang tidak kosong
     (pola sama dengan `desktop_chat_provider.dart`),
   - `workDir` = `<getApplicationSupportDirectory()>/clipper`,
   - membangun `ClipperScreen(config: ClipperHostConfig(...))` dari `aura_clipper_ui.dart`.
   Kalau tidak ada API key sama sekali, tampilkan pesan yang mengarahkan ke Settings
   (jangan memanggil router tanpa key).
3. `aura_desktop/lib/main.dart`: tambah satu entri navigasi (index 2, ikon + label
   "Clipper") dan satu cabang di area konten utama. Hindari perubahan lain di file ini.

## B. UI di `aura_clipper`

1. **`ClipperScreen`** (menggantikan stub "MVP UI Pending"), tata letak dua kolom:
   - Kiri: input link, opsi analisis (rentang dari–sampai, kotak "fokus" opsional, jumlah
     klip maksimum), tombol Mulai/Batal, daftar riwayat job (dari `ClipDatabase`).
   - Kanan: progres stage + pesan, daftar kandidat (judul, skor, alasan, rentang waktu),
     pratinjau, `ExportPanel`.
2. **Riverpod 3** `Notifier`/`AsyncNotifier` untuk job aktif dan riwayat. Tidak ada logika
   bisnis di widget.
3. **`ClipListView`:** urut skor, badge skor, centang pilih, klik = pratinjau.
4. **Pratinjau (`ClipPreviewPlayer`):** putar dari `startTime`, otomatis jeda di `endTime`,
   tombol ulang. **Pemutar video di Windows:** paket resmi `video_player` setahu saya tidak
   punya backend Windows; ada backend pihak ketiga seperti `fvp` atau `video_player_media_kit`
   ([daftar hasil pencarian](https://pub.dev/documentation/fvp/latest/)). **Verifikasi di
   pub.dev dulu**, pilih satu, dan catat alasannya di laporan. Ini plugin native Windows
   baru → ikuti **Insiden 7** (cek komponen VS, `flutter clean`, build ulang) dan Insiden 2
   (hanya satu pemutar, tanpa sisa eksperimen).
5. **`ExportPanel`:** pilih folder output (`file_picker` sudah ada di dependency desktop;
   jika dipakai dari package clipper, tambahkan hanya jika benar-benar perlu, atau terima
   callback pemilih folder dari host), export banyak klip terpilih, progres per klip, tombol
   "Buka folder".
6. **Dialog Pengaturan Clipper:** path yt-dlp/ffmpeg/whisper, nama model whisper, bahasa,
   dengan tombol **Cek Tool** (memakai `ToolCheck` Fase 22, menampilkan ✔/✘ + cara
   memasang). Simpan ke `clipper_settings.json`.
7. Pengingat legal satu kalimat di dialog pertama kali (`rules/19`, keamanan butir 9).
8. Pesan error ramah untuk: tool tidak ditemukan, URL tidak valid/diblokir, tidak ada API
   key, LLM gagal/respons tak valid (tampilkan ringkasan + lokasi `analysis_raw.log`),
   disk penuh, dibatalkan user.

## C. Pengujian

1. Widget test: `ClipperScreen` dengan pipeline palsu (status, daftar kandidat, error).
2. Uji manual di Windows: `flutter run -d windows` dari `aura_desktop`, satu video nyata
   dari link sampai klip diputar. Lampirkan tangkapan layar di laporan.
3. Jalankan **checklist umum** di `00-checklist-insiden.md`: pastikan fitur Chat dan Trading
   Lab yang sudah ada **tidak rusak** (build, buka kedua layar, kirim satu pesan chat).

## Definition of Done
- [ ] Entri "Clipper" muncul di navigasi desktop dan membuka `ClipperScreen`
- [ ] Alur penuh dari UI: link → progres → kandidat → pratinjau → export → file ada
- [ ] Batal di tengah proses menghentikan proses dan membersihkan file sementara
- [ ] Tanpa API key / tool hilang / URL buruk → pesan jelas, tidak crash
- [ ] Chat dan Trading Lab tetap normal (checklist umum dijalankan)
- [ ] Perubahan di `main.dart` minimal dan tercantum di laporan
- [ ] `flutter analyze` = 0 di `aura_clipper` dan `aura_desktop`, test hijau
- [ ] Laporan `CLIPPER_FASE_23.md` dengan tangkapan layar, push ke origin
