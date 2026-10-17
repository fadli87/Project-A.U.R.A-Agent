# Workflow: Fase 23c — Koreksi Bukti Fase 23b (WAJIB; Fase 23 belum dianggap selesai)

Baca `AGY_TASK_CLIPPER_BRIEF.md` bagian aturan "Laporan harus jujur soal bukti".

## Temuan review `d7f1937` (dibaca langsung dari repo)
Lima PNG di `.agents/reports/img/fase23/` **bukan tangkapan layar aplikasi yang berjalan**.
Semuanya dihasilkan oleh `aura_desktop/test/fase23b_evidence_generator_test.dart`
(1.057 baris) yang **menggambar ulang tampilan secara manual** dengan data karangan:
- Skor kandidat 94/88/82 ditulis di kode; hasil LLM nyata (Fase 23 Bagian 0) adalah 95/90 dan 95/88.
- Teks "Gemma 2B • 38.4 t/s", komentar `// Fake Candlestick Chart Area`, dan blok
  `> tasklist | findstr /i "yt-dlp ffmpeg"` diketik sebagai `Text(...)` di dalam widget.
- Teks pesan pembatalan ("...dihentikan secara bersih via taskkill /F /T") adalah string statis.
- Font test runner membuat semua teks menjadi kotak; gambar tidak memperlihatkan UI asli.
Selain itu: ekspor yang "diukur ffprobe" (5,01 dtk dan 6,01 dtk) memakai perintah `ffmpeg -c copy`
manual pada `source.mp4.webm`, bukan `FfmpegExporter`, bukan klip dari kandidat UI, dan
bertentangan dengan `minLen` 20 dtk. Pratinjau memutar, batal via tombol, Chat, dan Trading Lab
**tidak punya bukti nyata**. Yang nyata hanya: `flutter build windows` sukses, test notifier/widget.

## Tugas
1. **Hapus** `fase23b_evidence_generator_test.dart` dan kelima PNG. Tidak boleh ada test yang
   menulis ke `.agents/reports/`.
2. **Koreksi `CLIPPER_FASE_23B.md` dan `CLIPPER_FASE_23.md`:** nyatakan bahwa tangkapan layar
   tersebut adalah mockup, centang DoD terkait diubah menjadi **belum**, dan hapus kalimat
   "bukti nyata/pengujian langsung".
3. **Jangan** membuat bukti pengganti sendiri. Uji manual UI dilakukan oleh **Fadli** di
   mesinnya (tangkapan layar asli Windows). AGY hanya menyiapkan perintah menjalankan dan
   memperbaiki bug yang ditemukan.
4. Tambah satu baris di `rules/19-aura-clipper.md`: *"Bukti = keluaran terminal asli atau
   tangkapan layar aplikasi yang benar-benar berjalan. Dilarang menggambar/membuat tiruan
   yang menyerupai bukti. Bila tidak bisa dijalankan, tulis 'belum dijalankan'."*
5. Dengan sikap yang sama, tandai di `CLIPPER_FASE_22C.md` bagian mana yang berasal dari
   keluaran asli dan mana yang diketik ulang dari ingatan (mis. PID pada tasklist).

## Definition of Done
- [ ] Generator test dan 5 PNG terhapus; `git grep -n "Fake Candlestick"` kosong
- [ ] Laporan 23 dan 23B dikoreksi; butir tanpa bukti nyata tidak tercentang
- [ ] Aturan bukti ditambahkan ke rules/19; push
