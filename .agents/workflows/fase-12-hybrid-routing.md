# Workflow: Fase 12 — Hybrid Routing Mobile ↔ Desktop

Baca `.agents/rules/11-hybrid-routing.md` SEBELUM memulai.

**Tujuan:** Mobile bisa opsional meneruskan pertanyaan kompleks ke model lebih besar yang
jalan di Desktop, lewat LAN — tanpa cloud, tanpa dependency keras.
**Prasyarat:** Fase 8 Desktop (`llama-server` sudah jalan stabil di `aura_desktop`,
termasuk fix timing+alias dari insiden sebelumnya) sudah selesai.

## Langkah

1. Di `aura_desktop`: ubah bind address `llama-server` dari `127.0.0.1` ke `0.0.0.0` HANYA
   saat mode "expose ke LAN" diaktifkan user — default tetap `127.0.0.1` (localhost saja)
   untuk penggunaan Desktop mandiri.
2. Bangun UI pairing di Desktop: tampilkan kode 6 digit + IP lokal + port.
3. Bangun UI pairing di Mobile: input kode pairing, simpan IP+port Desktop yang dipasangkan.
4. Implementasikan health-check: sebelum routing ke Desktop, ping endpoint dengan timeout
   pendek (~2 detik) — kalau gagal, fallback otomatis ke model lokal Mobile.
5. Tambahkan toggle "Gunakan Desktop untuk pertanyaan kompleks" + tombol pilih manual
   per-pesan di chat (v1: user pilih, bukan heuristik otomatis).
6. Implementasikan pemanggilan endpoint Desktop (`/v1/chat/completions` format
   OpenAI-compatible) sebagai alternatif ke `llama_flutter_android` lokal, HANYA untuk
   giliran yang di-routing ke Desktop.
7. Tambahkan indikator UI di chat bubble yang menunjukkan asal jawaban (lokal HP vs
   Desktop).
8. Tampilkan warning eksplisit di UI pairing soal risiko jaringan tidak tepercaya.
9. Uji: matikan Desktop di tengah sesi, pastikan Mobile fallback otomatis ke model lokal
   tanpa macet/crash.

## Definition of Done
- [ ] Pairing Mobile↔Desktop berhasil lewat kode manual
- [ ] Toggle routing ke Desktop berfungsi, dengan fallback otomatis kalau Desktop tidak terjangkau
- [ ] Riwayat chat/memori/persona tetap tersimpan lokal di Mobile, tidak di Desktop
- [ ] Indikator UI jelas menunjukkan asal jawaban (lokal vs Desktop)
- [ ] Warning risiko jaringan tampil di UI pairing
- [ ] Default `llama-server` Desktop tetap bind ke localhost saja kecuali mode LAN diaktifkan eksplisit
