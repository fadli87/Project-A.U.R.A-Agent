// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages GGUF model discovery, loading, and unloading.
/// This provider is the bridge between UI and the native inference engine.

@ProviderFor(ModelNotifier)
final modelProvider = ModelNotifierProvider._();

/// Manages GGUF model discovery, loading, and unloading.
/// This provider is the bridge between UI and the native inference engine.
final class ModelNotifierProvider
    extends $NotifierProvider<ModelNotifier, ModelState> {
  /// Manages GGUF model discovery, loading, and unloading.
  /// This provider is the bridge between UI and the native inference engine.
  ModelNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelNotifierHash();

  @$internal
  @override
  ModelNotifier create() => ModelNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelState>(value),
    );
  }
}

String _$modelNotifierHash() => r'bfb29e07d36badf30d2fdc175dad8381df00457c';

/// Manages GGUF model discovery, loading, and unloading.
/// This provider is the bridge between UI and the native inference engine.

abstract class _$ModelNotifier extends $Notifier<ModelState> {
  ModelState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ModelState, ModelState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ModelState, ModelState>,
              ModelState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
