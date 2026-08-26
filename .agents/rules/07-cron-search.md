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

## Bagian B: Pencarian Online (Deep Search — UPGRADE dari Search-Handoff)

### KEPUTUSAN DIPERBARUI: dua tool berdampingan, dipilih lewat toggle
Keputusan lama (Opsi A, handoff browser saja) sekarang **di-upgrade**, bukan diganti —
kedua tool tetap ada, dipilih berdasarkan toggle di Settings:
- **Toggle MATI (default):** agent HANYA punya `search_web_handoff` (Opsi A lama, tetap
  ada — lihat versi sebelumnya di riwayat git file ini). Ini tetap default aman.
- **Toggle NYALA (opt-in eksplisit user):** agent JUGA punya `search_web_deep` — fetch
  hasil pencarian sungguhan, parse, suntik ke context supaya agent bisa benar-benar
  menjawab berdasarkan itu.

Ini pengecualian sadar terhadap prinsip privasi inti (lihat pembaruan Visi di
`.agents/rules/01-overview-stack.md`) — query akan keluar device saat toggle nyala.

### Tool baru: `search_web_deep(query: String)`
Kategori: **SENSITIF** (beda dari `search_web_handoff` yang aman) — alasannya jelas: ini
benar-benar mengirim data ke internet dan menerima balasannya, bukan sekadar membuka Intent.

### Sumber pencarian: DuckDuckGo HTML Lite (utama) + SearXNG (fallback)
1. **Utama:** fetch `https://html.duckduckgo.com/html/?q=<query_encoded>` — HTML statis
   tanpa JS, tidak butuh API key.
2. **Fallback:** kalau request utama gagal/timeout (>5 detik) atau dapat response error,
   coba instance SearXNG publik (URL dikonfigurasi di Settings, advanced — beri default
   satu instance publik yang stabil, tapi izinkan user ganti karena instance publik bisa
   down sewaktu-waktu).
3. JANGAN fetch halaman penuh dari link hasil pencarian — cukup title + snippet dari
   halaman hasil pencarian itu sendiri. Fetch halaman penuh akan membanjiri context window
   model kecil dan menambah risiko lebih jauh dari yang perlu.

### Parsing & budget context (KRITIS untuk model 1-3B)
1. Parse HTML hasil, ekstrak maksimal **3-5 hasil teratas**: title, snippet singkat, URL.
2. Gabungkan jadi satu blok teks dengan **budget total maksimal ~500 karakter** — potong
   snippet yang kepanjangan, jangan suntik mentah-mentah. Model kecil gampang "kewalahan"
   kalau observasi tool terlalu panjang dibanding kapasitasnya.
3. Sertakan URL tiap hasil dalam blok itu supaya kalau user mau, bisa diminta buka salah
   satu link lewat `search_web_handoff` (Intent) untuk baca lengkap — kombinasi dua tool
   ini saling melengkapi, bukan saling gantikan.
4. Masukkan blok ini ke context sebagai observasi tool (role terpisah), sama pola dengan
   tool lain di `.agents/rules/03-tool-calling.md` — bukan menimpa system prompt.

### Permission & disclosure
1. Toggle "Izinkan pencarian internet mendalam" di Settings, **default MATI**, dengan teks
   peringatan jelas: "Saat aktif, pertanyaan pencarian Anda akan dikirim ke internet
   (DuckDuckGo/SearXNG). Riwayat chat dan data pribadi lain TETAP tidak pernah dikirim —
   hanya query pencarian spesifik yang dipicu tool ini."
2. Saat toggle nyala dan tool benar-benar dipakai, tampilkan indikator kecil di UI chat
   (mis. "🌐 Mencari online: '...'") — transparan tanpa perlu dialog konfirmasi blocking
   tiap kali (itu akan sangat mengganggu untuk agentic loop yang mungkin butuh search
   berkali-kali dalam satu giliran).
3. Update system prompt tool-calling: kalau `search_web_deep` tersedia (toggle nyala),
   prioritaskan itu untuk pertanyaan yang butuh info terkini — `search_web_handoff` jadi
   fallback untuk kasus user memang mau baca sendiri di browser.

### Error handling
- Kalau DDG dan SearXNG fallback KEDUANYA gagal, agent harus bilang jujur ke user "saya
  tidak berhasil mencari online saat ini" — JANGAN diam-diam fallback ke halusinasi
  jawaban dari pengetahuan model yang sudah usang.

