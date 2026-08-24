# Rule: Tugas Terjadwal (Cron) & Pencarian Online (Search-Handoff)

Baca ini sebelum mengerjakan Fase 9. Dua fitur berbeda digabung di satu fase karena
sama-sama memperluas kemampuan agent di luar chat pasif — tapi keduanya PUNYA implikasi
privasi/baterai berbeda, jangan dicampur logikanya.

## Bagian A: Tugas Terjadwal (Cron)

### Mekanisme
- **WorkManager** untuk tugas berkala (mis. "setiap pagi jam 7") — catatan penting:
  Android membatasi interval minimum WorkManager periodik ke **15 menit**, ini batasan OS,
  bukan pilihan desain. Jangan janjikan ke user jadwal lebih presisi dari itu untuk tugas
  berkala.
- **AlarmManager** (`setExactAndAllowWhileIdle` atau setara) untuk tugas terjadwal presisi
  satu-kali (mis. "ingatkan jam 7 pagi besok") — ini yang dipakai untuk reminder personal,
  BUKAN WorkManager.
- Tetap 100% offline — cron TIDAK butuh koneksi internet apapun untuk fitur ini sendiri
  (beda dari Bagian B di bawah).

### Yang bisa dijadwalkan
- Reminder/notifikasi teks sederhana dari user (via tool "buat catatan/reminder" yang
  sudah ada di Fase 5).
- MemorySnapshot update terjadwal (opsional — sebagai alternatif dari trigger "tiap N
  pesan" yang sudah ada di Fase 7).
- JANGAN jadwalkan inferensi model penuh secara berkala tanpa alasan kuat — itu boros
  baterai kalau app di-background terus-menerus generate sesuatu. Kalau perlu ringkasan
  terjadwal, jaga se-ringan mungkin (mis. sekali per hari, bukan per jam).

### Notifikasi
- Pakai local notification Android biasa (tidak butuh Firebase/push server — semua
  terjadwal dan dieksekusi di device).
- Tap notification membuka app langsung ke konteks terkait (mis. sesi chat yang relevan).

## Bagian B: Pencarian Online (Search-Handoff)

### KEPUTUSAN FINAL: Opsi A — handoff ke browser, BUKAN fetch+parse+inject ke context
Alasan (jangan ubah tanpa diskusi ulang): menjaga janji privasi inti A.U.R.A (lihat
`.agents/rules/01-overview-stack.md`), nol maintenance beban parsing HTML yang rapuh, dan
menghindari masalah context window kecil model 1-3B kalau harus mencerna hasil pencarian
mentah.

### Cara kerja
1. Tool baru: `search_web(query: String)` — masuk kategori tool AMAN (bukan sensitif),
   karena TIDAK ADA data yang dikirim dari app selain membuka Intent standar Android;
   app tidak pernah menerima/menyimpan hasil pencarian.
2. Implementasi: `Intent(Intent.ACTION_WEB_SEARCH)` atau lebih andal —
   `Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=" + encodedQuery))`
   supaya browser default user yang menangani, apapun browsernya.
3. Setelah Intent terkirim, agent TIDAK menunggu hasil apapun — cukup respons ke user
   sesuatu seperti "Saya sudah bukakan pencarian untuk '...' di browser" lalu selesai
   giliran itu. Jangan pura-pura tahu hasilnya.
4. Ini satu kategori dengan tool berbasis Android Intent lainnya (buka Maps, dial nomor,
   dll) — desain `search_web` supaya gampang diperluas ke Intent lain nanti dengan pola
   yang sama.

### Kalau nanti mau upgrade ke fetch+parse (opt-in eksplisit)
JANGAN implementasikan di Fase 9 ini. Kalau nanti benar-benar dibutuhkan, itu keputusan
terpisah yang HARUS melalui toggle eksplisit "Izinkan A.U.R.A mengirim pertanyaan ke
internet" (default MATI) di Settings, dengan disclosure jelas setiap kali dipakai — bukan
default silent seperti tool aman lainnya. Lihat opsi B/C yang sudah dibahas (DuckDuckGo
HTML Lite / SearXNG) sebagai referensi kalau saatnya tiba.
