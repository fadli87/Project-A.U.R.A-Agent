# Workflow: Fase 19 — Cloud-Primary Gemini + Local Fallback Otomatis

Baca `.agents/rules/17-cloud-primary-gemini.md` SEBELUM memulai.

**Tujuan:** Gemini (free tier) jadi jalur utama inferensi karena keterbatasan device,
dengan fallback otomatis ke model lokal saat cloud tidak tersedia — tetap dengan kontrol
manual user.
**Prasyarat:** Fase 14 (`GeminiInferenceEngine`, secure storage API key) sudah ada.

## Langkah

1. Ubah default state toggle mode jadi "Cloud" dan buat persisten (simpan ke
   settings/secure storage, tidak reset tiap buka app).
2. Implementasikan health-check ringan sebelum kirim prompt ke Gemini: cek konektivitas
   internet dulu — kalau tidak ada, langsung pakai lokal tanpa mencoba cloud dulu (hemat
   waktu tunggu timeout).
3. Implementasikan fallback otomatis: tangkap error dari `GeminiInferenceEngine` (network
   error, rate limit, key invalid) → otomatis panggil model lokal untuk giliran itu →
   tampilkan pesan transisi jelas ke user.
4. Tambahkan counter kuota lokal sederhana (increment tiap call ke Gemini, reset harian) —
   tampilkan di Settings sebagai estimasi, bukan angka pasti dari Google.
5. Pastikan toggle manual override tetap berfungsi: paksa Lokal (mis. tombol/switch di
   chat), paksa coba Cloud lagi meski baru fallback.
6. Update indikator chat bubble supaya selalu jelas sumber jawaban (☁️ Gemini / 📱 Lokal),
   termasuk saat terjadi fallback di tengah sesi.
7. Update dokumentasi Visi (kalau ada file overview-stack di repo) supaya jujur
   mencerminkan cloud sebagai default sekarang, bukan lagi "100% offline".
8. Uji: matikan koneksi internet di tengah sesi, kirim pesan → pastikan fallback otomatis
   ke lokal terjadi mulus dengan pesan jelas, bukan macet/error mentah ke user.
9. Uji override manual: paksa mode Lokal saat internet menyala → pastikan benar-benar
   pakai model lokal, tidak diam-diam tetap ke cloud.

## Definition of Done
- [ ] Default mode Cloud, persisten antar sesi
- [ ] Fallback ke lokal otomatis saat tidak ada internet/API gagal/rate limit, dengan pesan jelas
- [ ] Override manual (paksa lokal / paksa cloud) tetap berfungsi
- [ ] Indikator sumber jawaban selalu akurat di tiap chat bubble
- [ ] Counter kuota Gemini tampil di Settings
- [ ] Dokumentasi Visi diupdate supaya tidak lagi mengklaim "100% offline"
