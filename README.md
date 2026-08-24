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
| Pengaturan Persisten | SharedPreferences |

## Model yang Didukung (Format GGUF, Kuantisasi Q4_K_M)

| Tier | RAM Min | Model |
|---|---|---|
| Ringan | 4 GB | Gemma 3 1B |
| Standar (default) | 6 GB | Qwen3 1.7B / SmolLM2 1.7B |
| Lanjut | 8 GB+ | Phi-4-mini 3.8B / Llama 3.2 3B |

## Fitur Utama

- **Agentic Loop** — Model dapat memanggil tools (cari info, buat catatan, dsb.) secara otomatis dalam satu giliran, dengan safety cap iterasi yang dapat dikonfigurasi (default 8, range 4–16)
- **Permission System** — Tools sensitif memerlukan persetujuan eksplisit pengguna sebelum dieksekusi (`PermissionApprovalCard`)
- **Persona & Skills** — System prompt dapat dikustomisasi dengan persona aktif + skills index + tool-calling schema
- **Persistent Memory** — Riwayat chat + vektor memori tersimpan lokal di SQLite + ObjectBox
- **Backup & Restore** — Export/import data ke file `.aurabackup` dengan validasi `schema_version`, dialog konfirmasi, dan reminder pasif setiap 7 hari
- **Settings UI** — Layar pengaturan untuk manajemen backup dan konfigurasi lanjutan agentic loop

## Struktur Proyek

```
lib/
├── main.dart
└── src/
    ├── native/          # GGUF model classes
    ├── concurrency/     # Dart Isolate + inference worker
    ├── providers/       # Riverpod state management
    │   ├── chat_provider.dart
    │   ├── inference_provider.dart
    │   ├── model_provider.dart
    │   ├── persona_provider.dart
    │   └── settings_provider.dart    ← Fase 8
    ├── storage/         # SQLite chat history + backup
    │   ├── chat_database.dart
    │   └── backup_service.dart       ← Fase 8
    ├── memory/          # ObjectBox vector store
    ├── agent/           # Agentic loop + tool registry
    │   └── agent_tools.dart
    └── ui/
        ├── screens/
        │   ├── chat_screen.dart      # Agentic loop entry point
        │   ├── settings_screen.dart  ← Fase 8
        │   └── model_manager_screen.dart
        ├── widgets/
        │   └── permission_approval_card.dart
        └── theme/
```

## Fase Pembangunan

| Fase | Status | Deskripsi |
|---|---|---|
| **Fase 1** | ✅ | Environment Setup & Foundation (`llama_flutter_android`) |
| **Fase 2** | ✅ | Integrasi Streaming & Concurrency |
| **Fase 3** | ✅ | Riverpod State & Chat UI Polish (Model Manager & Smooth UI) |
| **Fase 4** | ✅ | Persistent Memory (SQLite Chat History + ObjectBox HNSW Vector Store) |
| **Fase 5** | ✅ | Agentic Tool-Calling & Permission System |
| **Fase 6** | ✅ | Testing & Zero-Error Performance Verification |
| **Fase 7** | ✅ | Persona, Skills & Memory Snapshot (Hermes Agent System Prompt) |
| **Fase 8** | ✅ | Backup/Restore & Agentic Loop Safety Cap |
| **Fase 9** | 🔜 | Polish, Edge Cases & Production Hardening |

## Agentic Loop (Fase 8)

```
User kirim → [Iterasi 1/N] → Inference stream → ada tool-call?
  ├── YA (sensitif)  → PermissionApprovalCard → izin / tolak
  ├── YA (aman)      → auto-execute → addToolObservation → lanjut iterasi
  └── TIDAK          → jawaban final → selesai

[Iterasi ke-N tercapai] → ⚠️ Pesan partial + berhenti paksa
```

Safety cap dapat diatur dari **Pengaturan → Lanjutan** (4–16 langkah).

## Setup Dev Environment

### Prerequisites
- Flutter 3.44.6+ / Dart 3.12.2+
- Android SDK di `D:\Projects\DEV\Android\Sdk` (NDK, Build-tools 37.0.0, CMake)
- Device fisik Android arm64 untuk testing (emulator tidak akurat untuk performa llama.cpp)

### Setup
```bash
flutter pub get
dart run build_runner build
```

### Accept Android Licenses (satu kali)
```powershell
$env:ANDROID_HOME = "D:\Projects\DEV\Android\Sdk"
flutter doctor --android-licenses
```

## Engine Inferensi
Menggunakan `llama_flutter_android: ^0.2.6` (menjalankan llama.cpp native arm64 dengan Vulkan GPU offloading opsional di Android).

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
