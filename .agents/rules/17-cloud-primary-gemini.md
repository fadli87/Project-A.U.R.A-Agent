# Rule: Cloud-Primary Gemini + Local Fallback Otomatis

Baca ini sebelum mengerjakan Fase 19. Ini MEREVISI asumsi default dari Fase 14
(`.agents/rules/13-cloud-fallback.md` — kalau file itu masih ada di repo, baca juga untuk
konteks mekanisme awal). Alasan revisi: device user tidak cukup kuat menjalankan inferensi
lokal secara konsisten, jadi Gemini (API key gratis, akun AI Studio yang sama dipakai untuk
Hermes Agent di ThinkPad) jadi **jalur utama**, model lokal jadi **fallback**, BUKAN
sebaliknya seperti desain awal.

## Yang TETAP dipertahankan dari Fase 14 (jangan diubah)
- Mekanisme secure storage API key (DPAPI di Desktop / Keystore di Mobile) — TIDAK
  BERUBAH, tetap wajib.
- **Kontrol manual tetap ada** — user eksplisit menolak auto-switch penuh berbasis deteksi
  device lambat. Toggle/pilihan mode TETAP ada, bukan dihilangkan.
- Budget context yang dikirim (persona + skills index + riwayat relevan, BUKAN dump
  seluruh database) — prinsip ini tidak berubah cuma karena provider berubah.

## Yang BERUBAH dari Fase 14
1. **Default mode:** Cloud (Gemini) jadi pilihan default aktif, bukan OFF. Toggle
   "Mode: Cloud / Lokal" **persisten antar sesi** (disimpan, tidak reset ke OFF tiap buka
   app seperti desain Fase 14 lama) — karena sekarang ini penggunaan reguler, bukan
   pengecualian sesekali.
2. **Fallback ke lokal jadi OTOMATIS saat cloud gagal**, bukan sekadar "ditawarkan sebagai
   opsi" seperti Fase 14 lama. Skenario fallback otomatis:
   - Tidak ada koneksi internet.
   - API call gagal (network error, timeout).
   - Rate limit tercapai (Gemini free tier punya limit RPM/RPD ketat).
   - API key belum diisi/tidak valid.
3. Saat fallback otomatis terjadi, TAMPILKAN pesan jelas ke user (mis. "☁️→📱 Kuota
   Gemini gratis habis untuk saat ini, beralih ke model lokal") — JANGAN diam-diam pindah
   tanpa penjelasan, supaya user tidak bingung kenapa kualitas/kecepatan jawaban berubah.
4. User TETAP bisa override manual kapan saja: paksa pakai lokal (mis. untuk privasi
   topik tertentu) atau paksa coba cloud lagi meski baru saja fallback.

## Model & Provider
- Model: `gemini-flash-latest` (konsisten dengan yang sudah dipakai di setup Hermes Agent
  ThinkPad — satu API key AI Studio bisa dipakai untuk keduanya, tidak perlu key terpisah).
- Reuse `GeminiInferenceEngine` yang sudah dispesifikasikan di Fase 14 — tidak perlu
  ditulis ulang, cuma diubah jadi default path bukan opsional.

## Tracking kuota gratis (baru, belum ada di Fase 14)
Karena Gemini sekarang dipakai reguler (bukan sesekali), tambahkan counter lokal sederhana
(bukan API resmi Google, cuma hitung manual di app) untuk membantu user mengira-ira posisi
terhadap limit free tier — tampilkan di Settings, bukan mengganggu di chat.

## Prinsip privasi yang TETAP berlaku meski cloud jadi default
- Riwayat percakapan TETAP disimpan lokal (Fase 4) — Gemini cuma dipakai untuk satu
  putaran inferensi per giliran, tidak untuk penyimpanan permanen di sisi Google.
- Indikator sumber jawaban tetap tampil di tiap chat bubble (☁️ Gemini / 📱 Lokal) — makin
  penting sekarang karena ini jadi mode paling sering dipakai, user harus tetap selalu
  sadar data sedang ke mana.
- Update Visi di file overview-stack (kalau masih ada di repo): ubah dari "utamanya
  offline, cloud pengecualian" jadi jujur mencerminkan kondisi baru — "cloud (Gemini free
  tier) sebagai jalur utama karena keterbatasan device, model lokal tetap tersedia penuh
  sebagai fallback offline dan opsi privasi manual". JANGAN biarkan dokumentasi bilang
  "100% offline" kalau kenyataannya sekarang cloud yang jadi default.
