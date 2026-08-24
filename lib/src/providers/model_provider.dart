import 'dart:io';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../native/gguf_model.dart';

part 'model_provider.g.dart';

/// State for the model loading subsystem
class ModelState {
  const ModelState({
    this.availableModels = const [],
    this.activeModel,
    this.status = ModelStatus.none,
    this.deviceRamMb = 0,
    this.errorMessage,
    this.loadingProgress = 0.0,
  });

  final List<GgufModel> availableModels;
  final GgufModel? activeModel;
  final ModelStatus status;

  /// Total device RAM in MB (detected at runtime)
  final int deviceRamMb;

  final String? errorMessage;

  /// Loading progress 0.0–1.0 (if plugin provides it)
  final double loadingProgress;

  bool get isReady => status == ModelStatus.ready;
  bool get isLoading => status == ModelStatus.loading;
  bool get hasError => status == ModelStatus.error;
  bool get hasModel => activeModel != null;

  /// Recommended tier based on detected device RAM
  ModelTier get recommendedTier => recommendTierForRam(deviceRamMb);

  String get deviceRamFormatted {
    if (deviceRamMb == 0) return 'Unknown';
    if (deviceRamMb >= 1024) return '${(deviceRamMb / 1024).toStringAsFixed(1)} GB';
    return '$deviceRamMb MB';
  }

  ModelState copyWith({
    List<GgufModel>? availableModels,
    GgufModel? activeModel,
    ModelStatus? status,
    int? deviceRamMb,
    String? errorMessage,
    double? loadingProgress,
    bool clearError = false,
    bool clearActiveModel = false,
  }) {
    return ModelState(
      availableModels: availableModels ?? this.availableModels,
      activeModel: clearActiveModel ? null : (activeModel ?? this.activeModel),
      status: status ?? this.status,
      deviceRamMb: deviceRamMb ?? this.deviceRamMb,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      loadingProgress: loadingProgress ?? this.loadingProgress,
    );
  }
}

/// Manages GGUF model discovery, loading, and unloading.
/// This provider is the bridge between UI and the native inference engine.
@riverpod
class ModelNotifier extends _$ModelNotifier {
  LlamaController? _controller;

  LlamaController get controller => _controller ??= LlamaController();

  @override
  ModelState build() => const ModelState();

  /// Called at app startup: detect device RAM and scan for .gguf files
  Future<void> initialize() async {
    final ramMb = await _detectDeviceRam();
    state = state.copyWith(deviceRamMb: ramMb);

    // Scan default model directory
    await scanForModels();
  }

  /// Detect device total RAM in MB.
  Future<int> _detectDeviceRam() async {
    if (Platform.isAndroid) {
      try {
        final gpu = await controller.detectGpu();
        return gpu.deviceLocalMemoryBytes ~/ (1024 * 1024);
      } catch (e) {
        return 6 * 1024; // Fallback: 6 GB
      }
    }
    return 6 * 1024; // Default for non-Android platforms (e.g. testing)
  }

  /// Scan the app's model directory and external download folders for .gguf files
  Future<void> scanForModels() async {
    try {
      final List<Directory> searchDirs = [];

      // 1. App Documents Directory
      final appDir = await getApplicationDocumentsDirectory();
      final appModelsDir = Directory(path_lib.join(appDir.path, 'models'));
      if (!await appModelsDir.exists()) {
        await appModelsDir.create(recursive: true);
      }
      searchDirs.add(appModelsDir);

      // 2. App External Storage Directories
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final extModelsDir = Directory(path_lib.join(extDir.path, 'models'));
          if (!await extModelsDir.exists()) {
            await extModelsDir.create(recursive: true);
          }
          searchDirs.add(extModelsDir);
          searchDirs.add(extDir);
        }
      } catch (_) {}

      // 3. Android Common Storage & Download Directories
      if (Platform.isAndroid) {
        final List<String> pathsToTry = [
          '/sdcard/Download',
          '/sdcard/Download/Models',
          '/sdcard/Download/models',
          '/sdcard/Documents',
          '/sdcard/Documents/Models',
          '/sdcard/Documents/models',
          '/sdcard/Models',
          '/sdcard/models',
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Download/Models',
          '/storage/emulated/0/Download/models',
          '/storage/emulated/0/Documents',
          '/storage/emulated/0/Documents/Models',
          '/storage/emulated/0/Documents/models',
          '/storage/emulated/0/Models',
          '/storage/emulated/0/models',
        ];
        for (final p in pathsToTry) {
          final d = Directory(p);
          if (await d.exists()) {
            searchDirs.add(d);
          }
        }
      }

      final Map<String, GgufModel> modelsMap = {};

      for (final dir in searchDirs) {
        try {
          final List<FileSystemEntity> entities = await dir.list().toList();
          for (final entity in entities) {
            if (entity is File && entity.path.toLowerCase().endsWith('.gguf')) {
              final stat = await entity.stat();
              final sizeBytes = stat.size;
              final filename = path_lib.basename(entity.path);

              // Determine tier based on size
              ModelTier tier;
              if (sizeBytes < 1.0 * 1024 * 1024 * 1024) {
                tier = ModelTier.light;
              } else if (sizeBytes < 2.0 * 1024 * 1024 * 1024) {
                tier = ModelTier.standard;
              } else {
                tier = ModelTier.advanced;
              }

              // Use filename as key to prevent duplicate listings
              modelsMap[filename] = GgufModel(
                path: entity.path,
                name: filename,
                sizeBytes: sizeBytes,
                tier: tier,
              );
            }
          }
        } catch (_) {
          // Ignore directory read errors for non-existent or restricted paths
        }
      }

      state = state.copyWith(availableModels: modelsMap.values.toList());
    } catch (e) {
      setError('Gagal memindai model: ${e.toString()}');
    }
  }

  /// Manually register a model from a specific file path
  Future<void> addModelFromPath(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      setError('File model tidak ditemukan di: $filePath');
      return;
    }

    final stat = await file.stat();
    final sizeBytes = stat.size;
    final filename = path_lib.basename(file.path);

    ModelTier tier;
    if (sizeBytes < 1.0 * 1024 * 1024 * 1024) {
      tier = ModelTier.light;
    } else if (sizeBytes < 2.0 * 1024 * 1024 * 1024) {
      tier = ModelTier.standard;
    } else {
      tier = ModelTier.advanced;
    }

    final newModel = GgufModel(
      path: file.path,
      name: filename,
      sizeBytes: sizeBytes,
      tier: tier,
    );

    final currentModels = List<GgufModel>.from(state.availableModels);
    currentModels.removeWhere((m) => m.name == filename);
    currentModels.add(newModel);

    state = state.copyWith(availableModels: currentModels);
  }

  bool _isPickingFile = false;

  /// Open the system file picker to select and import a .gguf model file
  Future<bool> importModelWithPicker() async {
    if (_isPickingFile) return false;
    _isPickingFile = true;
    try {
      final pickedFiles = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gguf'],
      );

      if (pickedFiles == null || pickedFiles.isEmpty) {
        return false;
      }

      final pickedPath = pickedFiles.first.path;
      if (pickedPath == null || pickedPath.isEmpty) {
        return false;
      }

      final sourceFile = File(pickedPath);
      if (!await sourceFile.exists()) {
        setError('Berkas yang dipilih tidak dapat diakses.');
        return false;
      }

      // Copy to app external files directory / models or app documents directory
      Directory targetDir;
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          targetDir = Directory(path_lib.join(extDir.path, 'models'));
        } else {
          final appDir = await getApplicationDocumentsDirectory();
          targetDir = Directory(path_lib.join(appDir.path, 'models'));
        }
      } catch (_) {
        final appDir = await getApplicationDocumentsDirectory();
        targetDir = Directory(path_lib.join(appDir.path, 'models'));
      }

      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final filename = path_lib.basename(sourceFile.path);
      final destPath = path_lib.join(targetDir.path, filename);
      final destFile = File(destPath);

      // If source and dest are different, copy the file
      if (sourceFile.path != destFile.path && !await destFile.exists()) {
        state = state.copyWith(
          status: ModelStatus.loading,
          errorMessage: 'Menyalin berkas model ($filename)...',
        );
        await sourceFile.copy(destPath);
      }

      await scanForModels();
      state = state.copyWith(
        status: ModelStatus.none,
        clearError: true,
      );
      return true;
    } catch (e) {
      setError('Gagal mengimpor model: ${e.toString()}');
      return false;
    } finally {
      _isPickingFile = false;
    }
  }

  /// Load a GGUF model into memory.
  /// If a model is already loaded, it automatically unloads the previous model first.
  Future<void> loadModel(GgufModel model) async {
    // If the exact same model is already loaded and ready, do nothing
    if (state.activeModel?.path == model.path && state.isReady) {
      return;
    }

    // Unload previous model cleanly if active
    if (state.activeModel != null && _controller != null) {
      state = state.copyWith(
        status: ModelStatus.unloading,
        loadingProgress: 0.0,
      );
      try {
        await _controller?.dispose();
      } catch (_) {}
      _controller = null;
    }

    state = state.copyWith(
      status: ModelStatus.loading,
      loadingProgress: 0.2,
      clearError: true,
    );

    try {
      if (Platform.isAndroid) {
        final gpu = await controller.detectGpu();
        try {
          await controller.loadModel(
            modelPath: model.path,
            threads: 4,
            contextSize: 2048,
            gpuLayers: gpu.recommendedGpuLayers,
          );
        } catch (_) {
          // Fallback to CPU-only if GPU offloading fails
          await controller.loadModel(
            modelPath: model.path,
            threads: 4,
            contextSize: 2048,
            gpuLayers: 0,
          );
        }
      } else {
        // Simulate load delay for UI testing/design on non-Android
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      final loaded = model.copyWith(isLoaded: true);
      state = state.copyWith(
        status: ModelStatus.ready,
        activeModel: loaded,
        loadingProgress: 1.0,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: ModelStatus.error,
        errorMessage: 'Gagal memuat model: ${e.toString()}',
      );
    }
  }

  /// Unload the active model and free memory
  Future<void> unloadModel() async {
    if (!state.hasModel && _controller == null) return;

    state = state.copyWith(status: ModelStatus.unloading);
    if (Platform.isAndroid) {
      try {
        await _controller?.dispose();
        _controller = null;
      } catch (e) {
        // ignore
      }
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    state = state.copyWith(
      status: ModelStatus.none,
      clearActiveModel: true,
      clearError: true,
    );
  }

  /// Explicitly eject/unload the loaded model from memory
  Future<void> ejectModel() async {
    await unloadModel();
  }

  void updateProgress(double progress) {
    state = state.copyWith(loadingProgress: progress);
  }

  void setError(String message) {
    state = state.copyWith(
      status: ModelStatus.error,
      errorMessage: message,
    );
  }
}
