# Rule: Hybrid Routing Mobile ↔ Desktop

Baca ini sebelum mengerjakan Fase 12. Fitur ini menghubungkan `aura_mobile` dan
`aura_desktop` (dua instance terpisah di monorepo) lewat jaringan lokal — BUKAN cloud,
BUKAN internet, murni LAN antara device yang sudah dikonfirmasi milik user sendiri.

## Prinsip inti
- Desktop (PC dengan RAM/CPU lebih lega, bisa jalankan model 7B-13B) jadi "otak cadangan"
  opsional untuk Mobile — dipakai HANYA untuk pertanyaan yang butuh reasoning lebih dalam
  dari yang bisa diberikan tier model di HP.
- User HARUS eksplisit setup pairing antara Mobile dan Desktop — tidak ada auto-discovery
  yang jalan diam-diam tanpa consent (risiko privasi kalau ada device lain di jaringan
  yang sama, mis. WiFi publik/kantor).
- Kalau Desktop tidak terjangkau (mati, beda jaringan, dll), Mobile HARUS tetap berfungsi
  penuh dengan model lokalnya sendiri — hybrid routing adalah enhancement, bukan
  dependency keras.

## Mekanisme pairing
1. Di Desktop: tampilkan kode pairing singkat (mis. 6 digit) + IP lokal + port yang
   dipakai `llama-server` (default `8080`, sudah dikonfirmasi jalan di
   `.agents/rules/08-desktop-roadmap.md`).
2. Di Mobile: masukkan kode pairing itu secara manual (bukan QR scan otomatis untuk v1,
   supaya sederhana) — simpan IP+port Desktop yang dipasangkan ke `SharedPreferences`.
3. Pairing tidak permanen — kalau IP Desktop berubah (jaringan beda), user perlu
   pairing ulang. Ini trade-off sadar untuk kesederhanaan v1, bukan bug.

## Keputusan routing — kapan pakai Desktop, kapan pakai Mobile lokal
- **Default: SELALU pakai model lokal Mobile.** Routing ke Desktop HANYA terjadi kalau:
  a. User eksplisit toggle "Gunakan Desktop untuk pertanyaan kompleks" di Settings, DAN
  b. Desktop terjangkau saat itu (ping/health-check ke endpoint Desktop berhasil dalam
     waktu wajar, mis. 2 detik), DAN
  c. (Opsional v2) Heuristik sederhana mendeteksi prompt "kompleks" (mis. panjang prompt,
     kata kunci tertentu) — untuk v1, cukup biarkan user pilih manual per-pesan lewat
     toggle/tombol di chat, jangan bikin heuristik otomatis dulu, itu menambah kompleksitas
     tanpa manfaat jelas di awal.
- Kalau Desktop dipilih tapi gagal connect saat itu juga (device mati/pindah jaringan),
  FALLBACK OTOMATIS ke model lokal Mobile — JANGAN biarkan chat macet menunggu Desktop
  yang tidak responsif.

## Implementasi teknis
1. Desktop expose endpoint HTTP yang sama dengan yang dipakai `aura_desktop` sendiri untuk
   `llama-server` (reuse, jangan bikin API terpisah) — tapi bind ke `0.0.0.0` bukan cuma
   `127.0.0.1` supaya bisa diakses dari device lain di LAN yang sama. **PENTING:** ini
   berarti server itu bisa diakses device LAIN di jaringan yang sama — beri warning
   eksplisit ke user soal ini di UI pairing ("Pastikan Anda di jaringan WiFi yang
   tepercaya, mis. rumah sendiri, bukan WiFi publik").
2. Mobile: kirim request ke `http://<IP_DESKTOP>:<PORT>/v1/chat/completions` (format
   OpenAI-compatible yang sudah dipakai `llama-server`) sebagai pengganti panggilan ke
   `llama_flutter_android` lokal, HANYA untuk giliran yang di-routing ke Desktop.
3. Riwayat chat, memori, persona tetap disimpan LOKAL di Mobile — Desktop cuma dipakai
   untuk satu putaran inferensi, tidak menyimpan riwayat percakapan Mobile.
4. Indikator UI jelas di chat bubble mana yang dijawab model lokal HP vs model Desktop
   (mis. badge kecil "☁️ via Desktop" — meski bukan cloud, istilah ini paling gampang
   dipahami user awam; boleh diganti label lain yang lebih akurat kalau ada yang lebih
   pas).

## Yang TIDAK termasuk di v1
- Sync dua arah (Desktop tidak butuh tahu apa-apa dari Mobile selain request per-giliran).
- Auto-discovery device di jaringan (mDNS/Bonjour) — pairing manual saja dulu.
- Multiple Desktop pairing sekaligus — satu Mobile ke satu Desktop untuk v1.
