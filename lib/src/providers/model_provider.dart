import 'dart:io';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
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

  /// Scan the app's model directory for .gguf files
  Future<void> scanForModels() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDirPath = path_lib.join(appDir.path, 'models');
      final modelsDir = Directory(modelsDirPath);

      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }

      final List<GgufModel> models = [];
      final List<FileSystemEntity> entities = await modelsDir.list().toList();

      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.gguf')) {
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

          models.add(
            GgufModel(
              path: entity.path,
              name: filename,
              sizeBytes: sizeBytes,
              tier: tier,
            ),
          );
        }
      }

      state = state.copyWith(availableModels: models);
    } catch (e) {
      setError('Gagal memindai model: ${e.toString()}');
    }
  }

  /// Load a GGUF model into memory.
  Future<void> loadModel(GgufModel model) async {
    // Safety check: warn user if model may exceed device RAM
    final estimatedRam = (model.sizeBytes / (1024 * 1024)).ceil() * 2;
    if (estimatedRam > state.deviceRamMb * 0.8) {
      // More than 80% of device RAM — show warning but allow override
      state = state.copyWith(
        errorMessage:
            'PERINGATAN: Model ini mungkin terlalu besar untuk device Anda '
            '(${model.sizeFormatted} vs ${state.deviceRamFormatted} RAM). '
            'Lanjutkan dengan risiko OOM.',
      );
    }

    state = state.copyWith(
      status: ModelStatus.loading,
      loadingProgress: 0.0,
      clearError: true,
    );

    try {
      if (Platform.isAndroid) {
        final gpu = await controller.detectGpu();
        await controller.loadModel(
          modelPath: model.path,
          threads: 4,
          contextSize: 2048,
          gpuLayers: gpu.recommendedGpuLayers,
        );
      } else {
        // Simulate load delay for UI testing/design on non-Android
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      final loaded = model.copyWith(isLoaded: true);
      state = state.copyWith(
        status: ModelStatus.ready,
        activeModel: loaded,
        loadingProgress: 1.0,
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
    if (!state.hasModel) return;

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
    );
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
