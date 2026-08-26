// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages semantic memory: embeds chat messages and performs HNSW recall.

@ProviderFor(MemoryNotifier)
final memoryProvider = MemoryNotifierProvider._();

/// Manages semantic memory: embeds chat messages and performs HNSW recall.
final class MemoryNotifierProvider
    extends $NotifierProvider<MemoryNotifier, MemoryState> {
  /// Manages semantic memory: embeds chat messages and performs HNSW recall.
  MemoryNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryNotifierHash();

  @$internal
  @override
  MemoryNotifier create() => MemoryNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemoryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemoryState>(value),
    );
  }
}

String _$memoryNotifierHash() => r'c341f92f72b8746b113ca31fcc090f62f7f4c0e9';

/// Manages semantic memory: embeds chat messages and performs HNSW recall.

abstract class _$MemoryNotifier extends $Notifier<MemoryState> {
  MemoryState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MemoryState, MemoryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MemoryState, MemoryState>,
              MemoryState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
