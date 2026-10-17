# Workflow: Fase 23d — AURA Clipper: Perbaikan dari Uji Manual Pertama (tangkapan layar asli pengguna, 17 Okt)

Baca `rules/19-aura-clipper.md` (aturan bukti). Dasar: tangkapan layar nyata dari
`flutter run -d windows` oleh pengguna. Sampai tahap analisis berjalan; gagal di analisis LLM.

## Temuan
1. **`RIGHT OVERFLOWED BY 9 PIXELS`** pada baris tab sidebar (AI Chat / Trading Lab / Clipper).
   Regresi dari penambahan tab ketiga di `main.dart`; label "Trading Lab" terpotong.
2. **Analisis gagal:** "Chunk 0: Kesalahan router: LocalFallbackException(All models in …" —
   teks terpotong, penyebab sebenarnya tidak terlihat. Banner error di kolom kiri terpotong
   di tepi bawah jendela (720 px) dan tidak bisa digulir/disalin.
3. Panel kanan menampilkan "Terjadi kesalahan saat memproses video." (generik) sementara
   rincian ada di kolom kiri yang terpotong.
4. **AKAR MASALAH TERKONFIRMASI (teks error asli dari pengujian manual):** `Gemini HTTP 404 NOT_FOUND:
   "models/gemini-2.5-flash is no longer available to new users ... use models/gemini-3.8-flash"`.
   Nama model bawaan sudah usang. Pesan "layanan cloud sibuk/gagal, beralih ke model lokal"
   menyesatkan (ini 404, bukan sibuk). String usang tersebar di: `aura_desktop/lib/main.dart`
   (baris ±142, 909–950, chip combo), `desktop_settings_provider.dart` (±27, 62),
   `resolve_desktop_model.dart` (±20, 36, 63), `aura_mobile/.../inference_provider.dart`
   (±70, 85, 112) dan `aura_core/.../router_client.dart` (±406). Nilai combo yang sudah
   tersimpan di secure storage (`desktop_combo_model`) tidak ikut berubah bila default diganti.

## Tugas
1. **Overflow tab:** perbaiki baris tab di `main.dart` (mis. `Flexible` + `overflow: ellipsis`,
   atau ikon + label singkat). Perubahan sekecil mungkin; Chat dan Trading Lab tetap sama.
2. **Tampilkan error utuh:** banner error harus berada di area yang bisa digulir dan teksnya
   `SelectableText`; tampilkan penyebab asli (`decision.userFacingMessage` dan
   `originalError` per model: status HTTP, "model tidak ditemukan", "kuota", "key salah").
   Sertakan path `analysis_raw.log` yang bisa dibuka (tombol "Buka log"). Hapus duplikasi
   pesan generik di panel kanan, cukup satu ringkasan + tombol "Lihat rincian".
3. **Model Clipper bisa diatur sendiri:** tambah kolom "Model LLM (opsional)" di
   `ClipperSettingsDialog`; bila diisi, mengalahkan hasil `resolveDesktopModelOrCombo`
   (format `provider/model` atau `p1/m1,p2/m2`). Tampilkan model yang dipakai di kartu progres.
   Jangan mengubah `aura_core`.
4. **Perbaiki nama model usang di `aura_desktop`:** kumpulkan default model dalam satu
   konstanta (mis. `desktop_model_defaults.dart`) dan pakai di resolver, settings provider, dan
   chip combo di `main.dart`. **Verifikasi nama model aktif lewat satu panggilan nyata**
   (jangan menebak dari ingatan; Fase 23 menemukan `gemini-3.5-flash-lite` stabil, sedangkan
   `gemini-3.5-flash`/`3.8-flash` pernah 503 di free tier — pilih default dengan alasan tertulis,
   idealnya combo dengan fallback). Tambahkan migrasi ringan: bila nilai tersimpan
   `desktop_combo_model` memuat `gemini-2.5-flash`, ganti ke default baru satu kali.
   **Jangan ubah `aura_core` dan `aura_mobile`**; catat keduanya sebagai temuan (pengguna yang
   memutuskan). Perbaiki juga teks `LocalFallbackException` di UI Clipper agar membedakan
   404/401/429/503, bukan selalu "sibuk/gagal".
5. Test: widget test banner error menampilkan teks panjang tanpa overflow; test unit
   pemformat error router. **Tidak ada bukti buatan** — uji ulang di aplikasi hidup oleh pengguna.

## Definition of Done
- [ ] Tidak ada overflow di baris tab; Chat/Trading Lab tidak berubah perilaku
- [ ] Error LLM tampil lengkap, bisa digulir/disalin, dengan penyebab per model dan tombol log
- [ ] Model Clipper dapat diatur di dialog Pengaturan dan tampil saat berjalan
- [ ] Model usang diganti dari satu sumber; migrasi nilai tersimpan; satu panggilan nyata berhasil (keluaran asli)
- [ ] analyze = 0, test hijau, push; laporan `CLIPPER_FASE_23D.md` jujur ("belum dijalankan" bila belum)
