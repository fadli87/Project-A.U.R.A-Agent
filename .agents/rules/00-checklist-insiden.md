# CHECKLIST: Insiden Sebelumnya & Pencegahan — BACA INI PALING AWAL SETIAP SESI

File ini rangkuman masalah yang SUDAH pernah terjadi di project ini, supaya tidak terulang.
Detail lengkap tiap masalah ada di file Rules terkait (link disertakan) — file ini cuma
ringkasan cepat + checklist, bukan pengganti file Rules lainnya.

## Insiden 1: Kejar-kejaran angka compileSdk (34→35→36...)
**Yang terjadi:** Tiap kali plugin baru mengeluh butuh compileSdk lebih tinggi, angka
dinaikkan satu-satu berulang kali, menghabiskan banyak waktu.
**Status: SUDAH DIKUNCI.** Jangan negosiasi ulang. Angka final ada di
`.agents/rules/01-overview-stack.md`: `compileSdk=36, minSdk=26, ndkVersion=26.1.10909125`.
✅ Kalau ada plugin baru komplain butuh lebih tinggi dari itu → cek dulu apakah plugin itu
memang perlu SEKARANG sebelum menaikkan angka lagi.

## Insiden 2: Dependency ditambah tanpa disadari (tflite_flutter)
**Yang terjadi:** Package baru masuk `pubspec.yaml` untuk fitur Fase 4 padahal masih
mengerjakan Fase 1, menambah kompleksitas build lebih cepat dari rencana.
**Status: DITERIMA sebagai keputusan sadar** (lihat `.agents/rules/01-overview-stack.md`,
bagian "Dependency & urutan fase") — boleh maju cepat lintas-fase.
✅ Yang tetap wajib: setiap dependency baru harus benar-benar TERPAKAI di kode (bukan
nganggur), dan progres lintas-fase dicatat di komentar/README supaya tidak membingungkan.

## Insiden 3: Reinstall APK menghapus model GGUF yang sudah di-push manual
**Yang terjadi:** Setelah build besar (NDK/compileSdk/plugin baru), Android melakukan
uninstall+install ulang (bukan update biasa), menghapus folder
`Android/data/<package>/files/` — 2 model yang sudah terdeteksi jadi hilang total.
**Status: DIPAHAMI sebagai konsekuensi normal**, dicatat di
`.agents/rules/01-overview-stack.md`. Solusi jangka panjang: Fase 8 (Backup/Restore) —
tapi itu untuk data chat/persona/skills, BUKAN file model GGUF (memang tidak di-backup,
lihat `.agents/rules/06-backup-safety-cap.md`).
✅ **SETELAH BUILD BESAR (native/NDK/plugin baru):** selalu cek dulu apakah model masih
terdeteksi di app SEBELUM menganggap ada bug baru. Kalau hilang, itu normal — reimport
lewat tombol Import (.gguf), bukan gejala bug.

## Insiden 4: `file_picker` error `already_active`
**Yang terjadi:** Proses pilih file macet di state "aktif" setelah hot-reload di tengah
proses pick, bikin tombol Import gagal terus dengan `PlatformException(already_active)`.
**Fix:** TUTUP PENUH app (bukan minimize, bukan hot-reload) lalu buka ulang dari HP —
bukan dari Antigravity.
✅ **Pencegahan permanen di kode:** disable tombol Import selama `pickFiles()` masih
berjalan, supaya tidak bisa dipanggil dobel. Cek apakah ini sudah diimplementasikan sebelum
menganggap bug ini "sudah selesai" secara permanen.

## Insiden 5: Persona tersimpan tapi model tidak mengikutinya
**Yang terjadi:** Edit persona berhasil disimpan, tapi jawaban model tidak berubah sesuai
persona itu.
**Status:** BELUM tentu selesai — lihat diagnosis 4 langkah di
`.agents/rules/05-persona-skills.md` (cek apakah persona masuk prompt final via logging,
cek query `is_active`, cek chat template model, tes tier model lebih tinggi untuk isolasi
apakah ini keterbatasan model kecil atau bug kode).
✅ Kalau root cause-nya keterbatasan model kecil (bukan bug), pertimbangkan teknik
reinforcement: ulangi inti instruksi persona di akhir prompt, bukan cuma di awal.

## Insiden 6 (Desktop): `llama-server` lokal gagal connect — dua penyebab sekaligus
**Yang terjadi:** App Desktop (`aura_desktop`) tidak bisa connect ke `llama-server` lokal
meski server-nya sendiri terbukti sehat saat dites manual dari terminal.
**Penyebab #1 — timing:** Loading model 2.2GB di CPU butuh ~2 menit; delay tetap 3 detik di
kode terlalu pendek, app menganggap gagal dan mematikan/meninggalkan proses.
**Penyebab #2 — model alias hilang:** `llama-server` default expose model ID sebagai path
absolut file, bukan nama custom. App kirim request pakai ID `'local-model'`, server tidak
kenali → `400 Bad Request`.
**Fix yang diterapkan (lihat `.agents/rules/08-desktop-roadmap.md` untuk detail arsitektur):**
- Spawn `llama-server` dengan flag `--alias local-model` supaya ID yang dipakai app dan
  yang dikenali server cocok.
- Ganti delay tetap dengan dynamic polling (coba tiap 2 detik, sampai 120 detik) langsung
  ke endpoint HTTP — JANGAN pakai delay tetap untuk deteksi kesiapan server manapun,
  loading time bervariasi tergantung ukuran model dan kecepatan hardware.
- Redirect stdout/stderr proses `llama-server` ke `debugPrint` untuk diagnostic logging.
✅ **Pencegahan untuk implementasi subprocess lain (kalau ada):** selalu (1) set alias/ID
eksplisit kalau API punya konsep model ID, (2) pakai dynamic polling bukan delay tetap
untuk deteksi kesiapan proses child, (3) log stdout/stderr proses child sejak awal, jangan
ditambah belakangan setelah debugging jadi sulit.

## Checklist umum — jalankan SETIAP KALI habis perubahan besar (native/dependency/plugin)
Supaya insiden BARU yang sejenis tidak muncul, bukan cuma insiden LAMA yang tidak terulang:

1. [ ] Build & jalankan app — perhatikan warning baru di log (bukan cuma error)
2. [ ] Cek apakah model GGUF yang sudah diimport sebelumnya masih terdeteksi
3. [ ] Cek apakah persona/skill yang sudah dibuat sebelumnya masih ada dan aktif
4. [ ] Untuk fix konfigurasi yang solusinya eksplisit di pesan error (versi SDK/NDK/dependency) —
      terapkan langsung tanpa banyak penjelasan dulu, sesuai konvensi editing di
      `.agents/rules/01-overview-stack.md`
5. [ ] Kalau menambah dependency baru, pastikan benar-benar dipakai di kode, bukan sisa
      eksperimen yang lupa dihapus
