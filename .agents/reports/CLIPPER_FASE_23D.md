# Laporan Fase 23d — AURA Clipper: Perbaikan dari Uji Manual Pertama

**Tanggal:** 17 Oktober 2026  
**Branch:** `feature/aura-clipper`  
**Dasar Evaluasi:** Uji coba manual nyata `flutter run -d windows` pada aplikasi hidup oleh pengguna.  
**Status Bukti:** 100% Asli (tanpa generator mock/sintetis). Uji coba live pipeline selanjutnya menunggu eksekusi ulang aplikasi oleh pengguna di Windows.

---

## 1. Ringkasan Temuan dari Uji Coba Pertama

1. **Tab Row Overflow:** Tampilan bilah tab navigasi di sidebar kiri mengalami `RIGHT OVERFLOWED BY 9 PIXELS` akibat penambahan tab ketiga ("Clipper"), memotong teks label "Trading Lab".
2. **LLM Error 404 (Akar Masalah Utama):**
   ```text
   HttpException: Gemini HTTP 404 NOT_FOUND: {
     "error": {
       "code": 404,
       "message": "This model models/gemini-2.5-flash is no longer available to new users. Please update your code to use models/gemini-3.8-flash..."
     }
   }
   ```
   Pipeline berhasil mengunduh video, mengekstrak subtitle, dan memperkaya heatmap, namun terhenti di tahap analisis LLM karena Google telah mendeprekasi model default lama `gemini-2.5-flash`.
3. **Penyajian Error Terpotong & Non-interaktif:**
   - Banner error di kolom kiri terpotong di bagian bawah jendela resolusi 720 px, tidak dapat digulir, dan tidak dapat disalin (`SelectableText`).
   - Di panel kanan, pesan error menampilkan string generik duplikat (`Terjadi kesalahan saat memproses video.`), menyamarkan akar masalah.
   - Pesan `LocalFallbackException` membungkus error dengan teks "Seluruh layanan cloud sibuk/gagal", yang membingungkan ketika penyebab sebenarnya adalah HTTP 404 (model tidak ditemukan).

---

## 2. Perbaikan yang Diimplementasikan

### A. Perbaikan Tab Row Overflow (`aura_desktop/lib/main.dart`)
- Membungkus widget label teks tab navigasi (`AI Chat`, `Trading Lab`, `Clipper`) dengan `Flexible` dan properti `maxLines: 1`, `overflow: TextOverflow.ellipsis`.
- Mengurangi horizontal padding menjadi 4 dan ukuran ikon menjadi 14 agar pas dan estetis di jendela resolusi 720 px atau lebih kecil, tanpa mengubah perilaku tab AI Chat maupun Trading Lab.

### B. Pemusatan Default Model & Migrasi Otomatis (`aura_desktop`)
- Dibuat kelas konstanta terpusat: `DesktopModelDefaults` (`aura_desktop/lib/src/providers/desktop_model_defaults.dart`):
  - `geminiModel = 'gemini-3.8-flash'` (sesuai arahan resmi respons API Google).
  - `comboModel = 'gemini/gemini-3.8-flash,openai/gpt-4o'`.
  - Fungsi migrasi otomatis `migrateCombo(String combo)`.
- Mengintegrasikan `DesktopModelDefaults` ke:
  - `resolve_desktop_model.dart`
  - `desktop_settings_provider.dart`
  - Dialog pengaturan dan ChoiceChip di `main.dart`
- **Migrasi Storage:** Di `DesktopSettingsNotifier._load()` dan `main.dart`, jika nilai tersimpan `desktop_combo_model` di secure storage memuat model lama `gemini-2.5-flash`, nilai tersebut dimigrasikan secara otomatis satu kali ke `gemini-3.8-flash` dan disimpan kembali ke storage.

### C. Pengaturan Model Khusus Clipper (`aura_clipper`)
- Menambahkan properti `customModel` pada `ClipperSettings` dan `ClipperSettingsStore` (tersimpan di `clipper_settings.json`).
- Menambahkan input field `"Model LLM (Opsional)"` pada `ClipperSettingsDialog`.
- Jika diisi (mis. `gemini/gemini-3.8-flash` atau `openai/gpt-4o`), pengaturan ini langsung mengesampingkan model default host saat pipeline berjalan.
- Menampilkan tag model yang sedang aktif digunakan (`Model LLM: ... (kustom)`) pada kartu progres di panel kanan.

### D. Penguraian & Tampilan Error Utuh (`aura_clipper`)
- Membuat helper `ClipperErrorFormatter` (`aura_clipper/lib/src/ui/clipper_error_formatter.dart`):
  - Mengklasifikasikan kode status HTTP:
    - **404:** Model Tidak Ditemukan / Pensiun (memberikan instruksi ganti model ke `gemini-3.8-flash`).
    - **401/403:** Autentikasi Gagal / API Key tidak valid.
    - **429:** Batas Kuota Terlampaui.
    - **503/500:** Layanan Cloud Sibuk / Pemeliharaan.
    - **ProcessException:** Tool eksternal sistem gagal dieksekusi.
- **Penyajian di Kolom Kiri:**
  - Banner error dibungkus dalam kontainer berbingkai dengan header kategori yang jelas.
  - Teks saran tindakan perbaikan.
  - Detail teknis diletakkan di dalam kontainer `SelectableText` dengan font monospace yang dapat digulir mandiri (bebas overflow vertikal maupun horizontal).
  - Tombol **"Salin Seluruh Error"** (ke clipboard).
  - Tombol **"Buka File Log"** yang mengeksekusi `explorer.exe /select, <path>` pada Windows untuk langsung membuka berkas `analysis_raw.log`.
  - Tombol **"Salin Path"** untuk memudahkan inspeksi manual.
- **Penyajian di Kolom Kanan:**
  - Mengganti teks generik dengan ringkasan terklasifikasi (mis. `Model tidak ditemukan / pensiun (HTTP 404)`).
  - Tombol **"Lihat Rincian"** yang secara halus menggulir panel kiri kembali ke kartu error.

---

## 3. Catatan Temuan untuk Paket Lain (Sesuai Aturan Rule 19)

Sesuai aturan bahwa agent dilarang memodifikasi `aura_core` dan `aura_mobile` tanpa instruksi eksplisit:
- Di `aura_core/lib/src/llm_router/router_client.dart` (baris ±406): default fallback Gemini masih tertulis `gemini-2.5-flash`.
- Di `aura_mobile/.../inference_provider.dart` (baris ±70, 85, 112): default model Gemini masih tertulis `gemini-2.5-flash`.
- *Temuan ini dicatat agar pengguna dapat memutuskan kapan ingin memperbarui kedua modul tersebut.*

---

## 4. Hasil Verifikasi & Pengujian

### Static Analysis
- `aura_clipper`: `flutter analyze` → **No issues found!**
- `aura_desktop`: `flutter analyze` → **No issues found!**

### Test Suite
- `aura_desktop`: **14 passed** (termasuk 13 unit tests resolver model, deteksi passthrough, normalisasi combo, dan validasi migrasi `DesktopModelDefaults`).
- `aura_clipper`: **76 passed** (seluruh unit test pipeline, pembatalan proses Windows, serialisasi settings, klasifikasi error `ClipperErrorFormatter`, dan widget tests `ClipperScreen`).

---

## 5. Status Uji Live

- **Uji coba live pipeline berikutnya:** *Belum dijalankan* (menunggu pengguna menjalankan kembali `flutter run -d windows` pada aplikasi asli di Windows).
