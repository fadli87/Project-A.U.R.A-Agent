# Workflow: Fase 14 — Cloud Provider Fallback (Gemini/OpenAI)

Baca `.agents/rules/13-cloud-fallback.md` SEBELUM memulai — keputusan kunci (manual
per-pesan, secure storage wajib) sudah final di sana, jangan diimprovisasi ulang.

**Tujuan:** Opsi cadangan saat device terasa lambat, tanpa kejutan biaya atau kebocoran
privasi diam-diam.
**Prasyarat:** Fase 5 (Tool-Calling) dan Fase 12 (Hybrid Routing, untuk pola indikator
sumber jawaban) sudah selesai.

## Langkah

1. Tambahkan dependency `flutter_secure_storage` ke `aura_core` (atau langsung ke tiap
   platform kalau ada perbedaan API signifikan).
2. Bangun UI Settings "Cloud Provider (Opsional)": input API key Gemini, input API key
   OpenAI, mode password dengan show/hide, tombol validasi key, tombol hapus key.
3. Implementasikan validasi key: panggilan API ringan sebelum key disimpan sebagai aktif.
4. Desain interface `CloudInferenceEngine` di `aura_core`, dengan implementasi
   `GeminiInferenceEngine` dan `OpenAIInferenceEngine`.
5. Tambahkan toggle "☁️ Kirim ke Cloud" di chat screen, default OFF tiap buka app (tidak
   persisten sebagai default nyala antar sesi).
6. Kalau toggle aktif tanpa API key tersimpan, arahkan user ke Settings — jangan biarkan
   kirim request tanpa key valid.
7. Implementasikan pemanggilan provider yang dipilih saat toggle aktif untuk pesan itu,
   dengan payload dibatasi ke context relevan (persona + skills index + riwayat dalam
   window, BUKAN dump seluruh database).
8. Tambahkan indikator UI di chat bubble ("☁️ via Gemini"/"☁️ via OpenAI") untuk pesan yang
   dijawab lewat cloud.
9. Implementasikan error handling: pesan error jelas + tombol "Coba dengan model lokal"
   kalau API call gagal.
10. Uji: toggle aktif dengan key valid → jawaban dari cloud dengan indikator benar; toggle
    aktif tanpa key → diarahkan ke Settings; API call sengaja dibuat gagal (key salah) →
    error jelas + opsi fallback lokal muncul.

## Definition of Done
- [ ] API key tersimpan via secure storage, TIDAK di database/SharedPreferences plain
- [ ] Toggle per-pesan berfungsi, default OFF tiap sesi baru
- [ ] Indikator sumber jawaban (lokal/Desktop/cloud+provider) konsisten di semua chat bubble
- [ ] Payload ke cloud provider dibatasi ke context relevan, bukan seluruh database
- [ ] Error handling jelas dengan opsi fallback ke model lokal
- [ ] Riwayat chat tetap tersimpan lokal seperti biasa, tidak berubah walau pakai cloud
