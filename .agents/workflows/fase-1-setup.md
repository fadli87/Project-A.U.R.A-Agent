# Workflow: Fase 1 — Environment Setup & Foundation (REVISI: pakai package)

> **Update:** Fase ini direvisi untuk memakai package `llama_flutter_android` (^0.2.6),
> BUKAN compile llama.cpp custom manual. Lihat `.agents/rules/01-overview-stack.md` untuk
> alasan keputusan ini. Langkah CMakeLists/JNI manual di versi lama workflow ini sudah
> deprecated — jangan dikerjakan kecuali plugin terbukti tidak cukup nanti di Fase 6.

**Tujuan:** Siapkan project Flutter dan integrasikan `llama_flutter_android` sebagai
inference engine.
**Deliverable akhir:** shell app Flutter yang bisa memuat model GGUF via plugin ini, tanpa
crash, dengan Foreground Service aktif otomatis.

## Langkah

1. Pastikan `llama_flutter_android: ^0.2.6` ada di `pubspec.yaml` (versi PIN, jangan pakai
   `any` atau range terbuka), lalu `flutter pub get`.
2. Baca source `InferenceService.kt` dan `jni_wrapper.cpp` di repo plugin
   (github.com/dragneel2074/Llama-Flutter) — minimal sekali baca sebelum lanjut, supaya
   familiar dengan cara kerja internalnya.
3. Cek `AndroidManifest.xml` — pastikan permission dan `<service>` untuk Foreground
   Service dari plugin sudah otomatis ter-merge (biasanya otomatis lewat manifest
   merger Android, tapi tetap verifikasi manual).
4. Panggil `LlamaController().detectGpu()` di kode minimal, log hasilnya (device name,
   dukungan Vulkan, info memori, rekomendasi layer count) — ini validasi awal bahwa
   plugin native-nya termuat dengan benar di device fisik.
5. Download satu model tier ringan (`gemma-3-1b-it-Q4_K_M.gguf`) ke storage device untuk
   pengujian.
6. Panggil `controller.loadModel(modelPath: ..., threads: 4, contextSize: 2048)` — pastikan
   berhasil tanpa crash dan notification Foreground Service muncul.
7. Jalankan di device fisik (bukan emulator) untuk validasi paling awal.

## Referensi jika stuck
`.agents/rules/04-reference-projects.md` — plugin ini SEKARANG jadi dependency langsung,
bukan cuma referensi. Kalau ada bug plugin, cek issue tracker repo-nya dulu sebelum patch
sendiri.

## Definition of Done
- [ ] `llama_flutter_android` ter-install dengan versi ter-pin
- [ ] `detectGpu()` berhasil dipanggil dan hasilnya masuk akal (bukan error/null)
- [ ] Model tier ringan berhasil dimuat via `loadModel()` di device fisik tanpa crash
- [ ] Notification Foreground Service muncul saat model dimuat
