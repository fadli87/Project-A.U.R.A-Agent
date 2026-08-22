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
  /// Reads from /proc/meminfo on Android.
  Future<int> _detectDeviceRam() async {
    // TODO: Implement via platform channel or llama_flutter_android RAM API
    // For now returns a placeholder — will be replaced in Fase 2
    return 6 * 1024; // Default: assume 6 GB until platform channel is implemented
  }

  /// Scan the app's model directory for .gguf files
  Future<void> scanForModels() async {
    // TODO: Implement file scanning via path_provider + Directory.list()
    // Will be implemented in Fase 2 once file system access is established
    state = state.copyWith(availableModels: []);
  }

  /// Load a GGUF model into memory.
  ///
  /// Emits status updates: loading → ready (or error).
  /// IMPORTANT: This must run on the inference isolate, not the main isolate.
  /// The actual FFI call is done by InferenceWorker; this method just tracks state.
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
      // TODO: Delegate to InferenceWorker (Fase 2)
      // For now, simulate load delay for UI testing
      await Future<void>.delayed(const Duration(milliseconds: 500));

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
    // TODO: Call InferenceWorker.unload() (Fase 2)
    await Future<void>.delayed(const Duration(milliseconds: 200));
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
