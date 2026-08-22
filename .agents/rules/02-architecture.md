# Rule: System Architecture & Strategi Model

## 5 Layer Arsitektur (jangan campur tanggung jawab antar layer)

1. **Presentation Layer (Flutter):** Chat UI, Settings, Model Manager, indikator baterai/suhu.
2. **State Management Layer (Riverpod):** StreamProvider untuk token stream, Notifier untuk
   riwayat chat & status loading model.
3. **Agent Orchestration Layer:** mengelola loop reasoning → tool-call → observasi → jawaban;
   validasi skema JSON tool-call; permission gate untuk aksi sensitif; retry/fallback saat
   parsing gagal. Layer ini TIDAK BOLEH menyentuh FFI langsung — selalu lewat Concurrency Layer.
4. **Concurrency Layer (Dart Isolate + Foreground Service):** worker background yang menangani
   panggilan FFI, komunikasi via SendPort/ReceivePort, dijaga tetap hidup oleh foreground
   service saat app di-background.
5. **Native Inference & Storage Layer (C/C++, SQLite, ObjectBox):** `llama.cpp` (NDK) untuk
   inferensi; SQLite untuk riwayat percakapan; ObjectBox untuk semantic memory.

## Strategi Model — Tingkatan Berdasarkan RAM Device

Kecepatan sangat bergantung chipset, bukan cuma RAM (mis. Snapdragon 8 Elite jauh lebih baik
dari 8 Gen 3 di RAM yang sama) — jangan hanya patok RAM di kode, sediakan juga cara override
manual oleh user.

| Tier | RAM device min. | Model rekomendasi | Ukuran (Q4_K_M) | Cocok untuk |
|---|---|---|---|---|
| Ringan | 4 GB | Gemma 3 1B | ~720 MB | HP lama/low-end |
| Standar (default) | 6 GB | Qwen 3 1.7B / SmolLM 2 1.7B | ~1.1 GB | Titik seimbang mayoritas HP kelas menengah |
| Lanjut | 8 GB+ | Phi-4-mini 3.8B / Llama 3.2 3B | ~2.2–2.7 GB | HP flagship, reasoning & tool-calling lebih andal |

Model uji untuk development:
- `gemma-3-1b-it-Q4_K_M.gguf` (tier ringan)
- `qwen3-1.7b-instruct-Q4_K_M.gguf` (tier standar, default)
- `phi-4-mini-instruct-Q4_K_M.gguf` (tier lanjut)

## Risiko yang harus diantisipasi di kode (bukan hanya dokumentasi)

| Risiko | Mitigasi wajib di implementasi |
|---|---|
| Model kecil tidak konsisten hasilkan JSON valid | Validator skema ketat + 1x re-prompt otomatis + fallback ke teks biasa |
| Thermal throttling saat sesi panjang | Batasi context window, batasi thread CPU, beri jeda antar generate panjang |
| OS Android mematikan proses background | Foreground Service dengan notification persisten — WAJIB, bukan opsional |
| User memuat model terlalu besar untuk RAM device | Deteksi RAM saat startup + warning sebelum load model besar |
