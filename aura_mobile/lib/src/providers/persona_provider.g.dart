// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'persona_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PersonaNotifier)
final personaProvider = PersonaNotifierProvider._();

final class PersonaNotifierProvider
    extends $NotifierProvider<PersonaNotifier, PersonaState> {
  PersonaNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personaProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personaNotifierHash();

  @$internal
  @override
  PersonaNotifier create() => PersonaNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PersonaState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PersonaState>(value),
    );
  }
}

String _$personaNotifierHash() => r'243f2426075c38b6434f673c52e4854e716387af';

abstract class _$PersonaNotifier extends $Notifier<PersonaState> {
  PersonaState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PersonaState, PersonaState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PersonaState, PersonaState>,
              PersonaState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
