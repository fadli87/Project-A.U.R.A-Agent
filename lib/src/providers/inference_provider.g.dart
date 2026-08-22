// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inference_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages local LLM inference, streaming tokens, metrics, and cancellation.

@ProviderFor(InferenceNotifier)
final inferenceProvider = InferenceNotifierProvider._();

/// Manages local LLM inference, streaming tokens, metrics, and cancellation.
final class InferenceNotifierProvider
    extends $NotifierProvider<InferenceNotifier, InferenceState> {
  /// Manages local LLM inference, streaming tokens, metrics, and cancellation.
  InferenceNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inferenceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inferenceNotifierHash();

  @$internal
  @override
  InferenceNotifier create() => InferenceNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InferenceState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InferenceState>(value),
    );
  }
}

String _$inferenceNotifierHash() => r'cc5d0060f6304c66ba38dad10ff2c2e511447692';

/// Manages local LLM inference, streaming tokens, metrics, and cancellation.

abstract class _$InferenceNotifier extends $Notifier<InferenceState> {
  InferenceState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<InferenceState, InferenceState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<InferenceState, InferenceState>,
              InferenceState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
