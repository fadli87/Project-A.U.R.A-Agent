# AURA — Offline Personal Agentic AI (Android)

Agentic AI pribadi yang berjalan **100% offline** di Android — inferensi lokal via `llama.cpp`, tanpa bergantung pada API cloud apapun.

## Stack Teknologi

| Layer | Pilihan |
|---|---|
| Frontend | Flutter |
| State Management | Riverpod |
| AI Engine | `llama_flutter_android` (llama.cpp via Dart FFI) |
| Storage Riwayat | SQLite (`sqflite`) |
| Vector Store | ObjectBox (HNSW native Dart, v4+) |
| Concurrency | Dart Isolate + Android Foreground Service |

## Model yang Didukung (Format GGUF, Kuantisasi Q4_K_M)

| Tier | RAM Min | Model |
|---|---|---|
| Ringan | 4 GB | Gemma 3 1B |
| Standar (default) | 6 GB | Qwen3 1.7B / SmolLM2 1.7B |
| Lanjut | 8 GB+ | Phi-4-mini 3.8B / Llama 3.2 3B |

## Struktur Proyek

```
lib/
├── main.dart
└── src/
    ├── native/          # GGUF model classes
    ├── concurrency/     # Dart Isolate + inference worker
    ├── providers/       # Riverpod state management
    ├── storage/         # SQLite chat history
    ├── memory/          # ObjectBox vector store (Fase 4)
    ├── agent/           # Agentic loop + tool calling (Fase 5)
    │   └── tools/
    └── ui/
        ├── screens/
        ├── widgets/
        └── theme/
```

## Fase Pembangunan

- **Fase 1** ✅ Environment Setup & Foundation
- **Fase 2** 🔄 FFI Bridge & Foreground Service
- **Fase 3** ⏳ Riverpod State & Chat UI Polish
- **Fase 4** ⏳ Persistent Memory (SQLite + ObjectBox)
- **Fase 5** ⏳ Agentic Tool-Calling & Permission System
- **Fase 6** ⏳ Testing, Optimasi Performa & Thermal

## Setup Dev Environment

### Prerequisites
- Flutter 3.47.1+
- Android SDK di `L:\SDK\Android` (NDK 28.2 atau 30.0, CMake 3.22.1)
- Device fisik Android arm64 untuk testing (emulator tidak akurat untuk performa llama.cpp)

### Setup
```bash
dart pub get
dart run build_runner build
```

### Accept Android Licenses (satu kali)
```powershell
$env:ANDROID_HOME = "L:\SDK\Android"
flutter doctor --android-licenses
```

## llama.cpp Commit Dipakai
> **TODO (Fase 2):** Catat commit hash llama.cpp yang dipakai setelah integrasi selesai.

## Catatan Performa
- Inferensi lokal di HP kelas menengah bisa memakan waktu lebih lama dari API cloud
- UI selalu menampilkan status "generating..." yang jelas
- Thread CPU dibatasi untuk mengurangi thermal throttling
- RAM device dideteksi saat startup untuk rekomendasi tier model

## Non-Goals (di luar scope v1)
- Multi-user / multi-device sync
- Vision/multimodal
- Model >4B parameter
- Voice input/output
