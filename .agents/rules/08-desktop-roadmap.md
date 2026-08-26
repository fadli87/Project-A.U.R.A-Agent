# Rule: Roadmap Desktop (Windows/Linux/macOS) — SEDANG DIKERJAKAN (status diperbarui)

> **Status: AKTIF DIKERJAKAN** di monorepo (`aura_core` + `aura_mobile` + `aura_desktop`).
> Opsi A (subprocess + HTTP local) sudah dipilih dan TERBUKTI JALAN di `aura_desktop`
> (`desktop_chat_provider.dart`, `local_llm_service.dart`) setelah fix timing + alias —
> lihat Insiden 6 di `.agents/rules/00-checklist-insiden.md` untuk detail bug yang sudah
> diperbaiki. Bagian roadmap di bawah ini sekarang jadi referensi arsitektur yang sudah
> divalidasi, bukan lagi rencana teoretis semata.

## Kenapa desktop realistis untuk project ini
~70-80% kode (UI Flutter, Riverpod state, database SQLite/ObjectBox untuk memori/persona/
skills, Agent Orchestration Layer untuk tool-calling) adalah Dart murni — portable ke
desktop tanpa perubahan, karena Flutter native mendukung Windows/Linux/macOS. Yang HARUS
diganti hanya satu layer: inference engine.

## Masalah: `llama_flutter_android` tidak jalan di desktop
Plugin ini spesifik Android (JNI/Kotlin/Android NDK) — tidak ada jalur ke Windows/Linux/
macOS. Desktop butuh inference engine terpisah.

## Dua opsi inference engine untuk desktop

**Opsi A — Subprocess + HTTP local (DIREKOMENDASIKAN saat waktunya tiba):**
Jalankan `llama-server` (binary bawaan llama.cpp) sebagai proses terpisah, app bicara ke
`localhost` via HTTP. Tidak perlu compile FFI binding khusus per-OS — tinggal bundle binary
`llama-server` yang sudah dikompilasi untuk tiap platform. Pola yang sama dipakai LM Studio
di balik layar. Lebih sederhana untuk dikelola dibanding opsi B.

**Opsi B — FFI native langsung:**
Compile llama.cpp untuk tiap OS, pakai Dart FFI langsung (mis. `llama_cpp_dart`, yang
historisnya mendukung desktop/CLI juga, tidak cuma mobile). Lebih cepat (tanpa overhead
HTTP local) tapi effort maintain native binding jauh lebih besar. Baru pertimbangkan opsi
ini kalau Opsi A terbukti tidak cukup cepat.

## Catatan hardware yang relevan (dari mesin yang sudah ada)
- PC alternate (GPU Quadro K2000, arsitektur Kepler) — kemungkinan besar TIDAK memberi
  percepatan berarti lewat CUDA di llama.cpp modern (GPU terlalu tua). Jangan andalkan GPU
  ini untuk akselerasi.
- Keunggulan desktop dibanding HP bukan di GPU, tapi RAM & CPU jauh lebih lega —
  memungkinkan menjalankan model 7B-13B dengan nyaman di CPU saja, jauh di atas tier
  "Lanjut" (4B) yang jadi batas atas di mobile (lihat `.agents/rules/02-architecture.md`).
- Kalau nanti desktop benar-benar dikerjakan, model tier baru ("Desktop") perlu didefinisikan
  terpisah dari 3 tier mobile yang sudah ada — jangan paksa model besar itu juga jadi opsi
  di Android.

## Insurance murah yang relevan SEKARANG (satu-satunya bagian actionable)
Saat membangun pemanggilan inference di Fase 2 (`.agents/workflows/fase-2-ffi-bridge.md`),
sebaiknya bungkus panggilan ke `llama_flutter_android` di balik satu
interface/abstraction class (mis. `InferenceEngine` dengan method `loadModel()`,
`generate()`, dst) — BUKAN memanggil plugin itu langsung tersebar di banyak tempat di kode.
Ini tidak menambah effort berarti sekarang, tapi kalau desktop dikerjakan nanti, tinggal
buat implementasi baru dari interface yang sama (mis. `DesktopInferenceEngine` pakai Opsi A
di atas) tanpa bongkar ulang Agent Orchestration Layer, UI, atau state management yang
sudah jalan. Ini rekomendasi arsitektur, bukan requirement wajib — kalau sudah terlanjur
dipanggil langsung, tidak perlu buru-buru refactor sebelum desktop benar-benar mulai.
