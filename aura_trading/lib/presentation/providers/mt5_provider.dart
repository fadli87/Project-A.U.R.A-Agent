import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/sources/mt5/mt5_client.dart';
import '../../data/sources/mt5/mt5_models.dart';
import '../../data/sources/mt5/mt5_repository.dart';

// Minimal startWith extension — avoids adding rxdart dependency.
extension _StreamStartWith<T> on Stream<T> {
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}


// ────────────────────────────────────────────────────────────────
// Singleton repository provider (manual Riverpod — no code-gen)
// ────────────────────────────────────────────────────────────────

/// Provides the [Mt5Repository] implementation backed by [Mt5Client].
final mt5RepositoryProvider = Provider<Mt5Repository>((ref) {
  return Mt5RepositoryImpl(client: Mt5Client());
});

// ────────────────────────────────────────────────────────────────
// Connection Status — polled every 10 seconds
// ────────────────────────────────────────────────────────────────

/// Auto-refresh connection status every 10 seconds.
final mt5ConnectionStatusProvider = StreamProvider.autoDispose<bool>((ref) {
  final repo = ref.watch(mt5RepositoryProvider);
  return Stream.periodic(const Duration(seconds: 10), (_) => 0)
      .startWith(0)
      .asyncMap((_) => repo.isConnected());
});

// ────────────────────────────────────────────────────────────────
// Account Info — refreshed on demand or when connection changes
// ────────────────────────────────────────────────────────────────

/// Fetches live account info from MT5. Auto-disposes when not watched.
final mt5AccountProvider = FutureProvider.autoDispose<Mt5AccountInfo?>((ref) {
  final repo = ref.watch(mt5RepositoryProvider);
  return repo.getAccountInfo();
});

// ────────────────────────────────────────────────────────────────
// Open Positions — polled every 15 seconds while visible
// ────────────────────────────────────────────────────────────────

/// Streams open positions with periodic refresh (15 s).
final mt5PositionsProvider =
    StreamProvider.autoDispose<List<Mt5Position>>((ref) {
  final repo = ref.watch(mt5RepositoryProvider);
  return Stream.periodic(const Duration(seconds: 15), (_) => 0)
      .startWith(0)
      .asyncMap((_) => repo.getOpenPositions());
});

// ────────────────────────────────────────────────────────────────
// Manual refresh notifier — call `ref.invalidate(mt5RefreshProvider)`
// to force-refresh account + positions simultaneously.
// ────────────────────────────────────────────────────────────────

/// Notifier that holds a simple counter to trigger manual re-fetch.
class _Mt5RefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state = state + 1;
}

/// Incrementing counter that other providers can watch to trigger re-fetch.
final mt5RefreshCounterProvider =
    NotifierProvider<_Mt5RefreshNotifier, int>(_Mt5RefreshNotifier.new);

/// Manually refreshable account info (watches refresh counter).
final mt5AccountRefreshableProvider =
    FutureProvider.autoDispose<Mt5AccountInfo?>((ref) {
  ref.watch(mt5RefreshCounterProvider); // depend on manual refresh signal
  final repo = ref.watch(mt5RepositoryProvider);
  return repo.getAccountInfo();
});

/// Manually refreshable positions (watches refresh counter).
final mt5PositionsRefreshableProvider =
    FutureProvider.autoDispose<List<Mt5Position>>((ref) {
  ref.watch(mt5RefreshCounterProvider); // depend on manual refresh signal
  final repo = ref.watch(mt5RepositoryProvider);
  return repo.getOpenPositions();
});
