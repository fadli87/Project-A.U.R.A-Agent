# Rule: Local Document RAG (dokumen pribadi sebagai basis pengetahuan)

Baca ini sebelum mengerjakan Fase 11. Fitur ini MEMPERLUAS infrastruktur Fase 4
(embedding_service.dart + ObjectBox) ke sumber baru: dokumen yang dipilih user, bukan
cuma riwayat chat.

## Cakupan platform — WAJIB di kedua platform, bukan Mobile-only
Fitur ini berlaku untuk `aura_mobile` DAN `aura_desktop` — logic inti (ekstraksi,
chunking, embedding, retrieval) harus ditaruh di `aura_core` (shared) supaya otomatis
tersedia di keduanya. UI Settings untuk import/kelola dokumen harus dibangun TERPISAH di
tiap platform (karena widget UI tidak selalu portable identik), tapi memanggil service
yang sama dari `aura_core` — jangan duplikasi logic-nya.

## Prinsip inti
- User **secara eksplisit** memilih dokumen mana yang di-index — TIDAK ADA scan otomatis
  ke seluruh storage/PC. Sama pola dengan Import GGUF (`file_picker`/SAF) yang sudah ada.
- 100% offline — ekstraksi, chunking, embedding, retrieval semua terjadi lokal. Tidak ada
  dokumen yang dikirim ke internet.
- Format didukung v1: `.txt`, `.md`, `.pdf` (ekstrak teks saja, bukan gambar/tabel
  kompleks). `.docx` opsional kalau ada library ringan yang cocok, jangan dipaksakan kalau
  menambah dependency berat.

## Pipeline (reuse infrastruktur Fase 4, JANGAN duplikasi)
1. User pilih file lewat `file_picker` → simpan referensi (path + metadata: nama,
   tanggal import, jumlah chunk) ke tabel baru `DocumentSources`.
2. Ekstrak teks dari file (PDF perlu library ekstraksi teks, TXT/MD langsung baca).
3. **Chunking:** potong teks jadi bagian ~300-500 kata per chunk, dengan overlap kecil
   (~50 kata) antar chunk supaya konteks tidak terputus di batas kalimat penting.
4. Setiap chunk di-embed pakai `embedding_service.dart` yang SUDAH ADA (model
   all-MiniLM-L6-v2 via `tflite_flutter`) — jangan bikin embedding service kedua.
5. Simpan embedding ke ObjectBox dengan tag pembeda dari memori chat (mis. field
   `source_type: "document"` vs `source_type: "chat"`) — supaya retrieval bisa
   difilter per jenis sumber kalau diperlukan nanti.

## Retrieval saat chat
1. Saat user bertanya, jalankan semantic search ke ObjectBox mencakup KEDUA source_type
   (chat memory + document) kecuali user secara eksplisit minta batasi ke salah satu.
2. Ambil top-K chunk paling relevan (mulai dari K=3, bisa dituning), suntik ke context
   sebagai observasi — beri label jelas asal chunk (mis. "Dari dokumen 'laporan-Q3.pdf':
   ...") supaya user bisa verifikasi sumber jawaban, bukan cuma percaya buta.
3. Sama seperti Fase 9 (search online), JAGA BUDGET context — jangan suntik seluruh
   dokumen, cuma potongan yang relevan.

## Manajemen dokumen (UI)
- Layar "Sumber Pengetahuan" di Settings: daftar dokumen yang sudah di-import, dengan
  opsi hapus (yang juga menghapus embedding-nya dari ObjectBox, bukan cuma referensi file).
- Progress indicator saat proses ekstraksi+embedding berjalan (bisa makan waktu untuk
  dokumen besar) — jangan blocking UI, jalankan di isolate terpisah sama seperti pola
  inferensi.
