// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'knowledge_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(KnowledgeNotifier)
final knowledgeProvider = KnowledgeNotifierProvider._();

final class KnowledgeNotifierProvider
    extends $NotifierProvider<KnowledgeNotifier, KnowledgeState> {
  KnowledgeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'knowledgeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$knowledgeNotifierHash();

  @$internal
  @override
  KnowledgeNotifier create() => KnowledgeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KnowledgeState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KnowledgeState>(value),
    );
  }
}

String _$knowledgeNotifierHash() => r'2a86f560773af4e09a5a0f44649c367072d5354c';

abstract class _$KnowledgeNotifier extends $Notifier<KnowledgeState> {
  KnowledgeState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<KnowledgeState, KnowledgeState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<KnowledgeState, KnowledgeState>,
              KnowledgeState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
