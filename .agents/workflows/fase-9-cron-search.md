# Workflow: Fase 9 — Tugas Terjadwal (Cron) & Pencarian Online (Deep Search + Handoff)

Baca `.agents/rules/07-cron-search.md` SEBELUM memulai — keputusan desain sudah diperbarui:
sekarang ada DUA tool pencarian berdampingan (handoff aman + deep search sensitif via
toggle), bukan cuma handoff seperti versi awal.

**Tujuan:** Agent bisa proaktif lewat reminder terjadwal, dan bisa membantu pencarian
online — baik sekadar membuka browser, maupun (kalau user aktifkan) benar-benar membaca
dan menalar dari hasil pencarian.
**Prasyarat:** Fase 5 (Tool-Calling) sudah selesai — reminder terjadwal butuh tool "buat
catatan/reminder" yang sudah ada.

## Langkah — Bagian A: Cron

1. Tambahkan dependency `workmanager` untuk tugas berkala dan gunakan `AlarmManager` native
   (lewat platform channel) untuk tugas presisi satu-kali.
2. Implementasikan penjadwalan reminder: saat tool "buat catatan/reminder" dipanggil dengan
   waktu spesifik, daftarkan ke `AlarmManager`, bukan `WorkManager`.
3. Implementasikan local notification — tampil saat alarm/reminder jatuh tempo, tap
   notification membuka app ke sesi chat terkait.
4. Kalau ada kebutuhan ringkasan/maintenance terjadwal (mis. MemorySnapshot harian),
   daftarkan lewat `WorkManager` periodik — ingat batas minimum 15 menit dari Android.
5. Uji: buat reminder "5 menit dari sekarang", tutup app sepenuhnya, pastikan notifikasi
   tetap muncul tepat waktu.

## Langkah — Bagian B: Search (Handoff + Deep Search)

6. Implementasikan `search_web_handoff(query)` — kategori AMAN, buka
   `Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=..."))` dengan
   query di-encode benar. Agent respons singkat tanpa berpura-pura tahu hasilnya.
7. Tambahkan toggle "Izinkan pencarian internet mendalam" di Settings, default MATI,
   dengan teks peringatan sesuai draft di Rules.
8. Implementasikan `search_web_deep(query)` — kategori SENSITIF, hanya terdaftar ke agent
   kalau toggle di langkah 7 nyala:
   - Fetch `https://html.duckduckgo.com/html/?q=<query>`, parse title+snippet dari 3-5
     hasil teratas.
   - Fallback ke instance SearXNG publik (URL configurable) kalau fetch utama gagal/timeout.
   - Gabungkan hasil jadi satu blok maksimal ~500 karakter sebelum disuntik ke context.
9. Tampilkan indikator UI kecil ("🌐 Mencari online: '...'") tiap kali `search_web_deep`
   benar-benar dipanggil — bukan dialog konfirmasi blocking per panggilan.
10. Update system prompt tool-calling: prioritaskan `search_web_deep` (kalau tersedia)
    untuk pertanyaan info terkini; `search_web_handoff` untuk kasus user mau baca sendiri
    di browser.
11. Implementasikan error handling: kalau DDG dan SearXNG fallback keduanya gagal, agent
    HARUS bilang jujur ke user, bukan diam-diam menjawab dari halusinasi.
12. Uji dua skenario terpisah:
    - Toggle MATI: minta info terkini → hanya `search_web_handoff` tersedia, browser
      terbuka, agent tidak berpura-pura tahu hasil.
    - Toggle NYALA: minta info terkini → `search_web_deep` terpanggil, indikator UI
      muncul, agent menjawab berdasarkan snippet hasil pencarian asli.

## Definition of Done
- [ ] Reminder terjadwal presisi (AlarmManager) berfungsi meski app ditutup total
- [ ] Notifikasi tepat waktu dan membuka konteks yang relevan saat di-tap
- [ ] `search_web_handoff` tetap berfungsi seperti semula (aman, tanpa fetch/parse)
- [ ] Toggle "pencarian internet mendalam" default MATI, dengan teks peringatan jelas
- [ ] `search_web_deep` HANYA aktif saat toggle nyala, dengan fallback DDG→SearXNG
- [ ] Hasil pencarian dipotong ke budget ~500 karakter sebelum masuk context
- [ ] Indikator UI muncul tiap kali `search_web_deep` benar-benar dipanggil
- [ ] Agent jujur mengaku gagal kalau kedua sumber pencarian tidak bisa diakses

