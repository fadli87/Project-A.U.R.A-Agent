/// Represents a single GGUF model available on the device.
class GgufModel {
  const GgufModel({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.tier,
    this.isLoaded = false,
  });

  /// Absolute file path to the .gguf file
  final String path;

  /// Display name (derived from filename)
  final String name;

  /// File size in bytes
  final int sizeBytes;

  /// Recommended RAM tier for this model
  final ModelTier tier;

  /// Whether this model is currently loaded in memory
  final bool isLoaded;

  String get sizeFormatted {
    if (sizeBytes >= 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }

  GgufModel copyWith({
    String? path,
    String? name,
    int? sizeBytes,
    ModelTier? tier,
    bool? isLoaded,
  }) {
    return GgufModel(
      path: path ?? this.path,
      name: name ?? this.name,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      tier: tier ?? this.tier,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  @override
  String toString() => 'GgufModel(name: $name, tier: $tier, loaded: $isLoaded)';
}

/// Model tier based on device RAM requirements
enum ModelTier {
  /// Tier Ringan: 4 GB RAM min, ~720 MB model (e.g. Gemma 3 1B Q4_K_M)
  light,

  /// Tier Standar: 6 GB RAM min, ~1.1 GB model (e.g. Qwen3 1.7B / SmolLM2 1.7B Q4_K_M)
  standard,

  /// Tier Lanjut: 8 GB+ RAM min, ~2.2-2.7 GB model (e.g. Phi-4-mini 3.8B / Llama 3.2 3B Q4_K_M)
  advanced;

  String get displayName {
    switch (this) {
      case ModelTier.light:
        return 'Ringan';
      case ModelTier.standard:
        return 'Standar';
      case ModelTier.advanced:
        return 'Lanjut';
    }
  }

  /// Minimum device RAM in GB for this tier
  int get minRamGb {
    switch (this) {
      case ModelTier.light:
        return 4;
      case ModelTier.standard:
        return 6;
      case ModelTier.advanced:
        return 8;
    }
  }

  String get description {
    switch (this) {
      case ModelTier.light:
        return 'Gemma 3 1B — HP lama/low-end (4 GB RAM)';
      case ModelTier.standard:
        return 'Qwen3 1.7B / SmolLM2 — Kelas menengah (6 GB RAM)';
      case ModelTier.advanced:
        return 'Phi-4-mini 3.8B / Llama 3.2 3B — Flagship (8+ GB RAM)';
    }
  }
}

/// Status of model loading lifecycle
enum ModelStatus {
  none,
  loading,
  ready,
  error,
  unloading,
}

/// Determines the recommended model tier based on device RAM (in MB)
ModelTier recommendTierForRam(int deviceRamMb) {
  if (deviceRamMb >= 8 * 1024) return ModelTier.advanced;
  if (deviceRamMb >= 6 * 1024) return ModelTier.standard;
  return ModelTier.light;
}
