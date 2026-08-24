# Workflow: Fase 9 — Tugas Terjadwal (Cron) & Pencarian Online (Search-Handoff)

Baca `.agents/rules/07-cron-search.md` SEBELUM memulai — keputusan desain (WorkManager vs
AlarmManager, dan kenapa search pakai handoff bukan fetch+parse) sudah final di sana.

**Tujuan:** Agent bisa proaktif lewat reminder terjadwal, dan bisa membantu pencarian
online TANPA mengorbankan prinsip privasi-offline inti A.U.R.A.
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

## Langkah — Bagian B: Search-Handoff

6. Implementasikan tool baru `search_web(query)` di Agent Orchestration Layer — kategori
   AMAN (auto-execute, tidak perlu permission gate seperti tool sensitif di Fase 5).
7. Gunakan `Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=..."))`
   dengan query di-encode dengan benar (`Uri.encodeQueryComponent` atau setara).
8. Setelah Intent dikirim, agent merespons singkat ke user tanpa berpura-pura tahu hasil
   pencarian — lihat contoh respons di Rules.
9. Update system prompt tool-calling (skema di Fase 5) supaya model tahu kapan
   `search_web` relevan dipakai (mis. pertanyaan tentang info terkini yang tidak mungkin
   dijawab dari pengetahuan model kecil offline).
10. Uji: minta agent cari sesuatu yang jelas butuh info terkini (mis. "cuaca hari ini"),
    pastikan browser terbuka dengan query yang benar dan agent tidak berpura-pura menjawab
    dari halusinasi.

## Definition of Done
- [ ] Reminder terjadwal presisi (AlarmManager) berfungsi meski app ditutup total
- [ ] Notifikasi tepat waktu dan membuka konteks yang relevan saat di-tap
- [ ] Tool `search_web` membuka browser dengan query yang benar, tanpa fetch/parse HTML
- [ ] Agent tidak pernah berpura-pura tahu hasil pencarian setelah handoff ke browser
- [ ] Tidak ada toggle "izinkan kirim ke internet" yang aktif secara default
