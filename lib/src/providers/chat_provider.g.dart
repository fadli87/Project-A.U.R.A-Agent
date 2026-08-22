// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages the active chat session and message list.
/// Bridges the UI with the database and inference worker.

@ProviderFor(ChatNotifier)
final chatProvider = ChatNotifierProvider._();

/// Manages the active chat session and message list.
/// Bridges the UI with the database and inference worker.
final class ChatNotifierProvider
    extends $NotifierProvider<ChatNotifier, ChatState> {
  /// Manages the active chat session and message list.
  /// Bridges the UI with the database and inference worker.
  ChatNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatNotifierHash();

  @$internal
  @override
  ChatNotifier create() => ChatNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatState>(value),
    );
  }
}

String _$chatNotifierHash() => r'de754495e4473c9bf11544e61af51ecfea1d36ca';

/// Manages the active chat session and message list.
/// Bridges the UI with the database and inference worker.

abstract class _$ChatNotifier extends $Notifier<ChatState> {
  ChatState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ChatState, ChatState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatState, ChatState>,
              ChatState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Provider for all chat sessions (sidebar / history list)

@ProviderFor(allSessions)
final allSessionsProvider = AllSessionsProvider._();

/// Provider for all chat sessions (sidebar / history list)

final class AllSessionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ChatSession>>,
          List<ChatSession>,
          FutureOr<List<ChatSession>>
        >
    with
        $FutureModifier<List<ChatSession>>,
        $FutureProvider<List<ChatSession>> {
  /// Provider for all chat sessions (sidebar / history list)
  AllSessionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allSessionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allSessionsHash();

  @$internal
  @override
  $FutureProviderElement<List<ChatSession>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ChatSession>> create(Ref ref) {
    return allSessions(ref);
  }
}

String _$allSessionsHash() => r'aedef33f9eae69a1ba8a0222770fcc9e753cee86';
