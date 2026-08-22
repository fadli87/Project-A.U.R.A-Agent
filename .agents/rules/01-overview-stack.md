# Rule: Visi & Tech Stack — Offline Personal Agentic AI (Android)

Baca ini sebelum mengerjakan task apa pun di project ini.

## Visi
Membangun Agentic AI pribadi yang berjalan 100% offline di Android — meniru pengalaman
Hermes Agent (Nous Research: reasoning + tool use + memory) tapi tanpa bergantung pada
API cloud apa pun. Semua inferensi, memori, dan eksekusi tool terjadi di perangkat.

Bukan sekadar chatbot: siklus kerja yang benar adalah
`prompt → reasoning → (opsional) tool call → observasi hasil tool → lanjut reasoning → jawaban final`.

## Ekspektasi performa (WAJIB diingat, jangan overpromise)
Berdasarkan pengalaman lapangan sebelumnya (LM Studio di laptop CPU-only, satu prompt
bisa >1 jam), inferensi lokal di HP kelas menengah TIDAK akan secepat Gemini Flash/API
cloud. Jangan tulis kode atau UI yang mengasumsikan respons instan. Selalu tampilkan
status "generating..." yang jelas dan indikator progres.

## Non-Goals (di luar scope v1 — JANGAN implementasikan kecuali diminta eksplisit)
- Multi-user / multi-device sync
- Vision/multimodal
- Model >4B parameter
- Voice input/output

## Tech Stack (final, jangan ganti tanpa alasan kuat)

| Layer | Pilihan | Catatan |
|---|---|---|
| Frontend | Flutter | |
| State management | Riverpod | |
| AI engine | **`llama_flutter_android` package (^0.2.6)** | KEPUTUSAN FINAL (lihat catatan di bawah): pakai plugin siap pakai, bukan compile llama.cpp custom. Plugin ini sudah membungkus arsitektur yang sama persis yang direncanakan di sini: Dart → Pigeon → Kotlin coroutines → Foreground Service (InferenceService.kt) → JNI → llama.cpp, plus GPU/RAM detection bawaan (`detectGpu()`). JANGAN tulis ulang CMakeLists/JNI bridge sendiri kecuali plugin ini terbukti tidak cukup di Fase 6 |
| Storage riwayat | SQLite (`sqflite`) | |
| Vector store | **ObjectBox** (vector search HNSW native Dart, v4.0+) | JANGAN pakai `sqlite-vec` — tidak ada binding Dart resmi |
| Concurrency | Dart Isolate **+ Android Foreground Service** | Isolate saja TIDAK CUKUP — OS Android bisa membekukan/mematikan proses background tanpa foreground service |
| Background scheduling (opsional) | `WorkManager` | Untuk task terjadwal non-real-time (mis. ringkasan harian) |

## Kuantisasi model
Default **Q4_K_M** untuk semua model GGUF — standar mobile 2026, mempertahankan ±95%
kualitas model asli di ukuran seperempatnya. Jangan default ke Q8_0 atau F16 di mobile.

## Catatan keputusan: llama_flutter_android
Adopsi plugin ini masih kecil (ratusan downloads, single maintainer) — sebelum
bergantung berat padanya di Fase 2 dan seterusnya, baca dulu source `InferenceService.kt`
dan `jni_wrapper.cpp` di repo-nya (github.com/dragneel2074/Llama-Flutter) supaya familiar
dan bisa fork/patch sendiri kalau ada bug dan maintainer tidak responsif. Pin versi persis
di `pubspec.yaml`, jangan pakai range terbuka.

## Non-Functional Requirements yang wajib dipatuhi kode
- Deteksi RAM device saat startup, rekomendasikan tier model yang sesuai — jangan biarkan
  user memuat model yang berpotensi OOM tanpa peringatan.
- Batasi context window default dan jumlah thread CPU llama.cpp untuk mengurangi thermal
  throttling pada sesi panjang.
- Zero network permission untuk fitur inferensi inti — semua data (riwayat, memori) tidak
  boleh pernah keluar device.
- Target parsing sukses tool-call JSON ≥ 95% pada model tier menengah ke atas; di bawah
  itu, fallback ke re-prompt otomatis sebelum menyerah ke jawaban teks biasa.

## Konvensi editing — jangan bertele-tele untuk fix mekanis sederhana
Untuk error konfigurasi yang solusinya sudah eksplisit disebutkan di pesan error (mis.
"requires Android NDK X.X.X", "minSdkVersion cannot be smaller than Y") — LANGSUNG terapkan
angka dari pesan error itu ke file yang relevan (`android/app/build.gradle.kts`), tanpa
menjelaskan panjang lebar dulu atau meminta konfirmasi berulang. Tampilkan diff singkat
setelah selesai, bukan sebelum mengerjakan. Ini berlaku untuk semua fix mekanis serupa
(version bump, dependency pin), bukan cuma NDK/minSdk — simpan penjelasan panjang untuk
keputusan yang benar-benar butuh judgment (mis. pilih arsitektur, ganti library).

## Angka SDK final — SUDAH DIPUTUSKAN, jangan dinegosiasikan ulang tiap ada plugin baru
```
compileSdk = 36
minSdk     = 26
ndkVersion = "26.1.10909125"
```
Set ini SEKALI di `android/app/build.gradle.kts` DAN di blok `subprojects { afterEvaluate }`
pada `android/build.gradle.kts` (kalau blok force-override itu masih ada). JANGAN naikkan
angka bertahap (34→35→36→...) tiap kali plugin baru mengeluh — pakai 36 dari awal. Kalau
suatu saat ADA plugin yang butuh lebih tinggi dari ini, itu sinyal untuk mengecek dulu
apakah plugin tersebut benar-benar diperlukan SEKARANG (lihat aturan dependency di bawah)
sebelum menaikkan angka lagi.

## Dependency & urutan fase — BOLEH maju cepat, ini keputusan sadar
Update: user secara eksplisit memutuskan Antigravity BOLEH mengerjakan bagian dari fase
yang lebih jauh (mis. Fase 4 Memory) sambil fase sebelumnya belum 100% selesai, demi
kecepatan — dan menerima risiko build jadi lebih kompleks lebih cepat sebagai
konsekuensinya. JANGAN lagi menahan diri hanya karena "belum waktunya sesuai fase".
Yang tetap berlaku: JANGAN tinggalkan dependency yang benar-benar tidak terpakai di
`pubspec.yaml` (dead weight) — kalau suatu package memang dipakai di kode (seperti
`tflite_flutter` di `embedding_service.dart`), itu sah ada meski fase resminya belum tiba.
Tetap catat progres lintas-fase ini di komentar/README supaya jelas bagian mana yang sudah
jalan duluan, supaya tidak membingungkan saat sampai ke workflow fase terkait nanti.
