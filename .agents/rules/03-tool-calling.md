# Rule: Desain Tool-Calling & Agentic Loop

Ikuti spesifikasi ini persis saat mengimplementasikan Agent Orchestration Layer (Fase 5).

## Alur wajib
1. System prompt mendefinisikan skema tool secara ketat: nama fungsi, parameter, tipe data.
   Jangan biarkan model bebas berimprovisasi format.
2. Output model di-parse dengan **validator skema** (bukan regex sederhana yang rapuh).
3. Jika parsing gagal: lakukan **satu kali re-prompt otomatis** (mis. "format JSON kamu
   salah, coba lagi") sebelum fallback ke jawaban teks biasa. Jangan retry lebih dari sekali
   — itu buang waktu inferensi yang mahal di CPU mobile.
4. Hasil tool (observasi) dimasukkan kembali ke context sebagai role terpisah (bukan
   dianggap jawaban akhir) — model harus melanjutkan reasoning setelah menerima observasi.

## Kategorisasi tool — WAJIB dipisah dua kelas
- **Aman** (boleh auto-execute tanpa konfirmasi): baca status jaringan, baca file dalam
  sandbox app.
- **Sensitif** (WAJIB minta konfirmasi user eksplisit sebelum eksekusi, TIDAK PERNAH
  auto-execute): akses kontak, lokasi, file di luar sandbox app, dan aksi lain yang
  mengubah/menghapus data user.

Jangan pernah menambahkan tool baru ke kategori "aman" tanpa review eksplisit — default
untuk tool baru yang belum jelas kategorinya adalah **sensitif**.

## Tool v1 yang harus diimplementasikan nyata (bukan mock)
1. Cek status jaringan
2. Baca file lokal dalam sandbox app
3. Buat catatan/reminder

## Referensi desain (boleh dicontek polanya, bukan di-copy langsung)
- Skema tool-calling model-agnostic (JSON+XML+function-call): lihat `ToolManager` di
  Tool-Neuron (https://github.com/Siddhesh2377/llama.cpp-android) — native Kotlin, tapi
  polanya berlaku untuk Dart.
- Pola permission-gate dengan approval card Allow/Deny: lihat Agentic Mode di GGUF Loader
  (https://github.com/GGUFloader/gguf-loader) — desktop Python, contoh UX-nya yang dicontek.
- Model kecil yang dilatih khusus function-calling, untuk referensi cara prompting SLM
  supaya lebih patuh JSON: Octopus V2
  (https://huggingface.co/NexaAI/Octopus-v2-gguf-awq/blob/main/README.md)
