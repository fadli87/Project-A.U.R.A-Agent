# Workflow: Fase 1 — Environment Setup & Foundation

**Tujuan:** Siapkan project Flutter, NDK, dan compile `llama.cpp` untuk Android ARM64.
**Deliverable akhir:** shell app Flutter yang bisa load `.so` library via FFI, tanpa crash.

## Langkah

1. Inisialisasi project Flutter baru (`flutter create`) dengan nama package yang jelas
   untuk project ini.
2. Setup Android NDK dan CMake di `android/app/build.gradle` — pastikan target ABI
   `arm64-v8a` diaktifkan.
3. Clone `llama.cpp` ke dalam `src/cpp` sebagai submodule atau vendored copy — catat versi
   commit yang dipakai di README project untuk reproducibility.
4. Tulis `CMakeLists.txt` yang meng-compile `llama.cpp` jadi `libllama_bridge.so` untuk
   `arm64-v8a`.
5. Build project dan verifikasi `.so` berhasil dihasilkan.
6. Buat shell app Flutter minimal yang memuat `.so` tersebut lewat `dart:ffi` — cukup
   verifikasi library termuat tanpa error, belum perlu memanggil fungsi inference apa pun.
7. Jalankan di device fisik (bukan emulator) untuk validasi paling awal — cek log untuk
   error linking/ABI mismatch.

## Referensi jika stuck
Cek `.agents/rules/04-reference-projects.md` — terutama Llama-Flutter untuk pola
CMakeLists dan struktur folder native.

## Definition of Done
- [ ] `libllama_bridge.so` ter-build untuk arm64-v8a
- [ ] App Flutter berhasil load `.so` via FFI tanpa crash di device fisik
- [ ] Versi commit llama.cpp yang dipakai tercatat
