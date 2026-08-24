# Monorepo Restructuring Implementation Plan (Revisi)

> Revisi dari draft Antigravity — 2 koreksi ditandai `[REVISI]`. Sisanya tidak diubah.

We will finish restructuring the A.U.R.A project into a monorepo containing:
- `aura_core/` (Flutter **plugin** package containing database, memory, agents, tools, and utils — lihat catatan REVISI di bawah soal klasifikasi ini)
- `aura_mobile/` (existing Flutter Android UI calling `aura_core`)
- `aura_desktop/` (new Flutter Desktop UI calling `aura_core`)

## [REVISI] Catatan klasifikasi `aura_core`

Draft asli menyebut `aura_core` sebagai *"pure, platform-agnostic Dart package"* dan minta *"remove all dependencies on Flutter"*. Ini **tidak konsisten** dengan dependency yang sama-sama diminta di draft: `tflite_flutter` dan `objectbox_flutter_libs` — keduanya adalah **Flutter plugin**, bukan pure Dart package. Konsekuensinya:
- `aura_core` butuh Flutter SDK untuk build, bukan cuma Dart SDK.
- `aura_core` butuh folder platform (`android/`, `windows/`, `linux/`, dst) untuk bundling native library kedua plugin itu.

**Keputusan:** `aura_core` dibuat sebagai **Flutter plugin package**, bukan pure Dart package biasa. Kalau belum di-generate dengan template yang benar, jalankan ulang:
```
flutter create --template=plugin --platforms=android,windows,linux aura_core
```
(atau tambahkan folder platform secara manual ke `aura_core` yang sudah ada). Semua logic tetap platform-agnostic dari sisi *code* (tidak ada `if (Platform.isAndroid)` dsb di dalam `aura_core`), tapi secara *packaging* dia tetap Flutter plugin karena kebutuhan native binding.

## Proposed Changes

---

### Component: `aura_core` (Core Flutter Plugin Package)

Tujuan: logic (Dart code) tetap platform-agnostic — tidak ada `import 'package:flutter/material.dart'` atau widget apapun — meski packaging-nya Flutter plugin (lihat catatan REVISI di atas).

#### [REVISI] `objectbox.g.dart` dan `objectbox-model.json`
Draft asli menandai kedua file ini `[NEW]` di `aura_core/lib/objectbox.g.dart` (root `lib/`). Tapi dari restrukturisasi manual sebelumnya, kedua file ini **sudah dipindah** ke `aura_core/lib/memory/`. Karena `objectbox.g.dart` adalah file hasil generate (bukan ditulis manual), jangan pindahkan file lama — **hapus saja**, lalu generate ulang dari nol:

1. Hapus file `objectbox.g.dart` di lokasi manapun dia sekarang berada (baik di `aura_core/lib/` maupun `aura_core/lib/memory/`).
2. Pastikan semua class `@Entity` (termasuk `memory_entry.dart`) sudah ada di lokasi final di dalam `aura_core/lib/memory/`.
3. Baru jalankan `dart run build_runner build` di `aura_core/` (lihat bagian Verification Plan) — biarkan ObjectBox generate `objectbox.g.dart` sendiri di lokasi default (biasanya `aura_core/lib/objectbox.g.dart`, root `lib/`).
4. Sesuaikan import di `objectbox_store.dart` mengikuti lokasi hasil generate yang sebenarnya (jangan asumsikan path sebelum benar-benar generate).

`objectbox-model.json` juga dihasilkan/diupdate otomatis oleh proses generate — tidak perlu dipindah manual.

#### [MODIFY] [pubspec.yaml](file:///l:/dev_app/aura_Desktop/aura/aura_core/pubspec.yaml)
Add dependencies:
- `objectbox: ^5.3.2`
- `objectbox_flutter_libs: ^5.3.2`
- `tflite_flutter: ^0.12.1`
- `path: ^1.9.1`

Add `dev_dependencies`:
- `build_runner: ^2.4.0`
- `objectbox_generator: ^5.3.2`

#### [MODIFY] [objectbox_store.dart](file:///l:/dev_app/aura_Desktop/aura/aura_core/lib/memory/objectbox_store.dart)
- Remove `import 'package:path_provider/path_provider.dart';`
- Change `open()` to take a path string: `open({required String directoryPath})`
- Import `objectbox.g.dart` dari lokasi hasil generate yang sebenarnya (lihat catatan REVISI di atas — jangan asumsikan `../objectbox.g.dart` sebelum verifikasi)

#### [MODIFY] [embedding_service.dart](file:///l:/dev_app/aura_Desktop/aura/aura_core/lib/memory/embedding_service.dart)
- Remove `import 'package:flutter/services.dart';`
- Change `init()` to accept `Uint8List modelBytes` and `String tokenizerJson` as parameters. This avoids calling `rootBundle` inside the core package.
- Add `import 'dart:typed_data';`

#### [MODIFY] [alarm_service.dart](file:///l:/dev_app/aura_Desktop/aura/aura_core/lib/agent/alarm_service.dart)
- Remove `import 'package:flutter/foundation.dart';` and `import 'package:flutter/services.dart';` (MethodChannels).
- Define a platform-agnostic interface:
  ```dart
  abstract class PlatformService {
    Future<void> scheduleReminder({
      required int id,
      required String title,
      required String content,
      required DateTime time,
      required int sessionId,
    });
    Future<void> cancelReminder(int id);
    Future<void> searchWeb(String query);
  }
  ```
- Change `AlarmService` to delegate execution to a registered `PlatformService`.

#### [MODIFY] [chat_database.dart](file:///l:/dev_app/aura_Desktop/aura/aura_core/lib/storage/chat_database.dart)
- Remove `import 'package:sqflite/sqflite.dart';`.
- Add `import 'package:sqlite3/sqlite3.dart';`.
- Implement `Sqlite3DatabaseWrapper` mimicking `sqflite`'s query, insert, update, delete, and transaction methods so the existing queries do not need to be rewritten.
- Add an `init(String path)` method to set the custom database path dynamically from the client application.

#### [MODIFY] [backup_service.dart](file:///l:/dev_app/aura_Desktop/aura/aura_core/lib/storage/backup_service.dart)
- Fix import from `package:aura/src/storage/chat_database.dart` to local `chat_database.dart`.

#### [MODIFY] [aura_core.dart](file:///l:/dev_app/aura_Desktop/aura/aura_core/lib/aura_core.dart)
- Export all public files:
  ```dart
  export 'agent/agent_tools.dart';
  export 'agent/alarm_service.dart';
  export 'inference/gguf_model.dart';
  export 'memory/memory_entry.dart';
  export 'memory/embedding_service.dart';
  export 'memory/objectbox_store.dart';
  export 'storage/chat_models.dart';
  export 'storage/chat_database.dart';
  export 'storage/backup_service.dart';
  export 'utils/emoji_parser.dart';
  ```
  (Export `objectbox.g.dart` juga kalau `ObjectBoxStore` mengharuskan caller mengakses `Store` type-nya langsung — cek setelah generate.)

---

### Component: `aura_mobile` (Flutter Android App)

#### [DELETE] [objectbox.g.dart](file:///l:/dev_app/aura_Desktop/aura/aura_mobile/lib/objectbox.g.dart)
Delete from `aura_mobile` as it is moved to `aura_core`.

#### [DELETE] [objectbox-model.json](file:///l:/dev_app/aura_Desktop/aura/aura_mobile/lib/objectbox-model.json)
Delete from `aura_mobile`.

#### [MODIFY] [pubspec.yaml](file:///l:/dev_app/aura_Desktop/aura/aura_mobile/pubspec.yaml)
Add path dependency:
```yaml
dependencies:
  aura_core:
    path: ../aura_core
```

#### [MODIFY] [main.dart](file:///l:/dev_app/aura_Desktop/aura/aura_mobile/lib/main.dart)
- Load assets (`minilm_l6_v2.tflite` and `minilm_tokenizer.json`) using `rootBundle` and pass them to `EmbeddingService.instance.init()`.
- Pass documents directory path to `ObjectBoxStore.open()`.
- Initialize `ChatDatabase.instance` with databases path from `sqflite`.
- Create and register `MobilePlatformService` subclassing `PlatformService` inside `AlarmService`.

#### [MODIFY] Update imports in UI and Providers
Modify all files inside `aura_mobile/lib/src/ui/` and `aura_mobile/lib/src/providers/` to use:
```dart
import 'package:aura_core/aura_core.dart';
```
instead of direct relative imports like `../storage/chat_database.dart`.

---

### Component: `aura_desktop` (Flutter Desktop App)

#### [MODIFY] [pubspec.yaml](file:///l:/dev_app/aura_Desktop/aura/aura_desktop/pubspec.yaml)
Add path dependency:
```yaml
dependencies:
  aura_core:
    path: ../aura_core
  flutter_riverpod: ^3.0.0
```

#### [MODIFY] [main.dart](file:///l:/dev_app/aura_Desktop/aura/aura_desktop/lib/main.dart)
- Implement a basic desktop UI that loads GGUF model files from desktop folders.
- Calls `aura_core` classes for chat, memory management, and backups.

---

## Verification Plan

### Automated Tests
- Run `flutter pub get` in `aura_core/`, `aura_mobile/`, and `aura_desktop/`.
- Run `dart run build_runner build` in `aura_core/` to compile ObjectBox files — **lakukan ini sebelum** menyesuaikan import path di `objectbox_store.dart` dan `aura_core.dart`, supaya path yang dipakai sesuai hasil generate yang sebenarnya, bukan asumsi.
- Run static analysis `flutter analyze` in all directories to confirm no import or type errors.

### Manual Verification
- Build and run the Android app `aura_mobile` in debug mode using `flutter build apk --debug`.
- Verify chat memory recall, GGUF loading, and note generation works exactly as before.
- Run `aura_desktop` to verify desktop compilation.
