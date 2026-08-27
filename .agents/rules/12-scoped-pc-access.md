# Rule: Akses File PC Terbatas (read-only, whitelist folder) — BUKAN computer_use

Baca ini sebelum mengerjakan Fase 13. Ini secara SADAR versi yang jauh lebih terbatas dari
`computer_use` Hermes Agent — keputusan ini sudah didiskusikan eksplisit dengan user dan
dipilih karena model 1-4B on-device kurang reliable untuk dipercaya akses PC tanpa batas
(lihat alasan penuh di riwayat diskusi; ringkasnya: risiko command/akses destruktif dari
tool-call yang salah tafsir terlalu tinggi untuk kelas model ini).

## Cakupan platform — WAJIB di kedua platform, JUSTRU LEBIH PENTING di Desktop
Fitur ini berlaku untuk `aura_mobile` DAN `aura_desktop`. Di Desktop ini bahkan lebih
relevan daripada di Mobile — Desktop berjalan LANGSUNG di PC tempat file-file berada,
sementara Mobile baru bisa "menyentuh" PC secara tidak langsung lewat Fase 12 (Hybrid
Routing). Logic validasi whitelist (`read_local_file`, resolve path, cek prefix) harus di
`aura_core` (shared), UI "Folder yang Bisa Dibaca AURA" dibangun terpisah di tiap platform
(folder picker berbeda API antara Android SAF dan Desktop file dialog) tapi memanggil
service yang sama.

## Batasan keras — JANGAN dilonggarkan tanpa diskusi ulang eksplisit dengan user
1. **HANYA baca (read-only).** TIDAK ADA kemampuan tulis, edit, rename, hapus file/folder
   apapun lewat tool ini. Titik.
2. **HANYA folder yang di-whitelist eksplisit oleh user.** TIDAK ADA akses ke path di luar
   whitelist, bahkan kalau user "memintanya" lewat chat — kalau prompt user minta baca
   file di luar whitelist, tool ini WAJIB menolak dan memberi tahu user untuk menambahkan
   folder itu ke whitelist dulu lewat Settings, bukan diam-diam mengizinkan by-pass.
3. **TIDAK ADA eksekusi command/terminal/shell dalam bentuk apapun.** Ini bukan tool
   `execute_code` atau `computer_use` — murni baca isi file teks.
4. **TIDAK ADA traversal ke parent directory** (`..`) dari folder yang di-whitelist — validasi
   path secara ketat (resolve absolute path, cek prefix-nya ada di whitelist) supaya tidak
   bisa "keluar" dari folder yang diizinkan lewat trik path.

## Mekanisme whitelist
1. UI di Settings: "Folder yang Bisa Dibaca AURA" — daftar folder dengan tombol
   tambah/hapus, pakai folder picker (Desktop: `file_picker` mode direktori).
2. Simpan daftar whitelist di `SharedPreferences`/tabel settings — bukan hardcode.
3. Default: **kosong**. User harus aktif menambahkan folder sebelum tool ini punya apapun
   untuk dibaca — jangan pre-populate dengan folder umum (Documents, Desktop, dll) tanpa
   consent eksplisit.

## Tool baru: `read_local_file(path: String)`
Kategori: **SENSITIF** — meski read-only, ini tetap akses ke data personal user di luar
sandbox app, jadi tetap butuh keberadaan di whitelist sebagai bentuk "izin yang sudah
diberikan di muka", TAPI penggunaan pertama kali tetap tampilkan indikator jelas di UI
chat (mis. "📄 Membaca: laporan.txt") — bukan permission dialog blocking tiap panggilan
(karena sudah di-whitelist di muka), tapi tetap transparan tiap kali benar-benar dipakai.

Validasi wajib sebelum baca:
1. Resolve path ke absolute path.
2. Cek prefix absolute path itu ada di salah satu folder whitelist.
3. Kalau tidak lolos validasi → tolak, beri pesan jelas ke user (lewat observasi tool ke
   agent, supaya agent bisa jelaskan ke user), JANGAN silent fail.
4. Batasi ukuran file yang dibaca (mis. maksimal 1MB teks) — file besar dipotong dan diberi
   catatan "file terpotong, hanya menampilkan bagian awal" ke context, supaya tidak
   membanjiri context window model kecil.

## Hubungan dengan Fase 11 (Document RAG)
Tool ini BEDA dari Document RAG di `.agents/rules/10-document-rag.md`:
- **Document RAG:** dokumen di-index PERMANEN (embedding tersimpan), untuk pertanyaan
  berulang soal dokumen yang sama — user "mengajarkan" AURA dokumen itu.
- **`read_local_file`:** baca SEKALI SAAT DIMINTA, tidak di-index/simpan permanen, untuk
  kasus ad-hoc ("tolong baca file X, ada apa isinya") tanpa perlu proses import formal.
Kedua fitur saling melengkapi, bukan duplikat. Kalau user sering baca file yang sama
berulang kali, arahkan mereka ke fitur Document RAG (Fase 11) untuk pengalaman yang lebih
baik (search semantic, bukan baca ulang dari nol tiap kali).

## Roadmap masa depan (JANGAN dikerjakan sekarang, catatan saja)
Kalau nanti benar-benar terbukti tool ini kurang cukup dan user secara eksplisit minta
kemampuan tulis/eksekusi, itu HARUS jadi diskusi keputusan terpisah — bukan ekstensi diam-
diam dari tool ini. Pertimbangkan dulu: apakah reliability tool-calling model saat itu
sudah cukup matang (data dari Fase 6 testing), sebelum melonggarkan batasan read-only ini.
