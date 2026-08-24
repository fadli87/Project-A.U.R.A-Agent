import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_provider.g.dart';

/// Keys untuk SharedPreferences
class _PrefKeys {
  static const maxAgentIterations = 'max_agent_iterations';
  static const lastBackupTimestamp = 'last_backup_timestamp_ms';
}

/// State untuk pengaturan aplikasi
class SettingsState {
  const SettingsState({
    this.maxAgentIterations = 8,
    this.lastBackupTimestamp,
  });

  /// Batas iterasi agentic loop per giliran (Rule 06-backup-safety-cap.md)
  /// Default 8, range 4–16, dapat diubah di Settings (advanced).
  final int maxAgentIterations;

  /// Timestamp (ms) backup terakhir, null jika belum pernah backup.
  final int? lastBackupTimestamp;

  /// Apakah sudah >7 hari sejak backup terakhir
  bool get shouldRemindBackup {
    if (lastBackupTimestamp == null) return false;
    final last = DateTime.fromMillisecondsSinceEpoch(lastBackupTimestamp!);
    return DateTime.now().difference(last).inDays >= 7;
  }

  /// Apakah belum pernah backup sama sekali
  bool get neverBackedUp => lastBackupTimestamp == null;

  DateTime? get lastBackupDate => lastBackupTimestamp != null
      ? DateTime.fromMillisecondsSinceEpoch(lastBackupTimestamp!)
      : null;

  SettingsState copyWith({
    int? maxAgentIterations,
    int? lastBackupTimestamp,
    bool clearBackupTimestamp = false,
  }) {
    return SettingsState(
      maxAgentIterations: maxAgentIterations ?? this.maxAgentIterations,
      lastBackupTimestamp: clearBackupTimestamp
          ? null
          : (lastBackupTimestamp ?? this.lastBackupTimestamp),
    );
  }
}

@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  @override
  SettingsState build() {
    _load();
    return const SettingsState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final maxIter = prefs.getInt(_PrefKeys.maxAgentIterations) ?? 8;
    final lastBackup = prefs.getInt(_PrefKeys.lastBackupTimestamp);
    state = SettingsState(
      maxAgentIterations: maxIter.clamp(4, 16),
      lastBackupTimestamp: lastBackup,
    );
  }

  /// Simpan maxAgentIterations baru (range 4–16)
  Future<void> setMaxAgentIterations(int value) async {
    final clamped = value.clamp(4, 16);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_PrefKeys.maxAgentIterations, clamped);
    state = state.copyWith(maxAgentIterations: clamped);
  }

  /// Dipanggil setelah export backup berhasil — catat timestamp sekarang
  Future<void> recordBackupNow() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_PrefKeys.lastBackupTimestamp, now);
    state = state.copyWith(lastBackupTimestamp: now);
  }
}
