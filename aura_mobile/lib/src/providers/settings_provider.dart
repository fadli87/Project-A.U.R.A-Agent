import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_provider.g.dart';

/// Keys untuk SharedPreferences
class _PrefKeys {
  static const maxAgentIterations = 'max_agent_iterations';
  static const lastBackupTimestamp = 'last_backup_timestamp_ms';
  static const isDeepSearchEnabled = 'is_deep_search_enabled';
  static const searxngUrl = 'searxng_url';
  static const useDesktopAssistant = 'use_desktop_assistant';
  static const desktopIp = 'desktop_ip';
  static const desktopPort = 'desktop_port';
  static const desktopPin = 'desktop_pin';
  static const activeCloudProvider = 'active_cloud_provider';
  static const openaiModel = 'openai_model';
}

/// State untuk pengaturan aplikasi
class SettingsState {
  const SettingsState({
    this.maxAgentIterations = 8,
    this.lastBackupTimestamp,
    this.isDeepSearchEnabled = false,
    this.searxngUrl = 'https://searx.be/',
    this.useDesktopAssistant = false,
    this.desktopIp = '',
    this.desktopPort = '8080',
    this.desktopPin = '',
    this.activeCloudProvider = 'gemini',
    this.openaiModel = 'gpt-4o-mini',
  });

  /// Batas iterasi agentic loop per giliran (Rule 06-backup-safety-cap.md)
  /// Default 8, range 4–16, dapat diubah di Settings (advanced).
  final int maxAgentIterations;

  /// Timestamp (ms) backup terakhir, null jika belum pernah backup.
  final int? lastBackupTimestamp;

  /// Apakah pencarian internet mendalam diaktifkan (Fase 9)
  final bool isDeepSearchEnabled;

  /// URL instance SearXNG fallback (Fase 9)
  final String searxngUrl;

  /// Apakah asisten di-routing ke Desktop (Fase 12)
  final bool useDesktopAssistant;
  final String desktopIp;
  final String desktopPort;
  final String desktopPin;
  final String activeCloudProvider;
  final String openaiModel;

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
    bool? isDeepSearchEnabled,
    String? searxngUrl,
    bool? useDesktopAssistant,
    String? desktopIp,
    String? desktopPort,
    String? desktopPin,
    String? activeCloudProvider,
    String? openaiModel,
    bool clearBackupTimestamp = false,
  }) {
    return SettingsState(
      maxAgentIterations: maxAgentIterations ?? this.maxAgentIterations,
      lastBackupTimestamp: clearBackupTimestamp
          ? null
          : (lastBackupTimestamp ?? this.lastBackupTimestamp),
      isDeepSearchEnabled: isDeepSearchEnabled ?? this.isDeepSearchEnabled,
      searxngUrl: searxngUrl ?? this.searxngUrl,
      useDesktopAssistant: useDesktopAssistant ?? this.useDesktopAssistant,
      desktopIp: desktopIp ?? this.desktopIp,
      desktopPort: desktopPort ?? this.desktopPort,
      desktopPin: desktopPin ?? this.desktopPin,
      activeCloudProvider: activeCloudProvider ?? this.activeCloudProvider,
      openaiModel: openaiModel ?? this.openaiModel,
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
    final deepSearch = prefs.getBool(_PrefKeys.isDeepSearchEnabled) ?? false;
    final url = prefs.getString(_PrefKeys.searxngUrl) ?? 'https://searx.be/';
    final useDesktop = prefs.getBool(_PrefKeys.useDesktopAssistant) ?? false;
    final ip = prefs.getString(_PrefKeys.desktopIp) ?? '';
    final port = prefs.getString(_PrefKeys.desktopPort) ?? '8080';
    final pin = prefs.getString(_PrefKeys.desktopPin) ?? '';
    final cloudProvider = prefs.getString(_PrefKeys.activeCloudProvider) ?? 'gemini';
    final model = prefs.getString(_PrefKeys.openaiModel) ?? 'gpt-4o-mini';

    state = SettingsState(
      maxAgentIterations: maxIter.clamp(4, 16),
      lastBackupTimestamp: lastBackup,
      isDeepSearchEnabled: deepSearch,
      searxngUrl: url,
      useDesktopAssistant: useDesktop,
      desktopIp: ip,
      desktopPort: port,
      desktopPin: pin,
      activeCloudProvider: cloudProvider,
      openaiModel: model,
    );
  }

  /// Simpan maxAgentIterations baru (range 4–16)
  Future<void> setMaxAgentIterations(int value) async {
    final clamped = value.clamp(4, 16);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_PrefKeys.maxAgentIterations, clamped);
    state = state.copyWith(maxAgentIterations: clamped);
  }

  /// Simpan isDeepSearchEnabled baru
  Future<void> setDeepSearchEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_PrefKeys.isDeepSearchEnabled, value);
    state = state.copyWith(isDeepSearchEnabled: value);
  }

  /// Simpan searxngUrl baru
  Future<void> setSearxngUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefKeys.searxngUrl, value);
    state = state.copyWith(searxngUrl: value);
  }

  /// Dipanggil setelah export backup berhasil – catat timestamp sekarang
  Future<void> recordBackupNow() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_PrefKeys.lastBackupTimestamp, now);
    state = state.copyWith(lastBackupTimestamp: now);
  }

  Future<void> setUseDesktopAssistant(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_PrefKeys.useDesktopAssistant, value);
    state = state.copyWith(useDesktopAssistant: value);
  }

  Future<void> setDesktopIp(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefKeys.desktopIp, value.trim());
    state = state.copyWith(desktopIp: value.trim());
  }

  Future<void> setDesktopPort(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefKeys.desktopPort, value.trim());
    state = state.copyWith(desktopPort: value.trim());
  }

  Future<void> setDesktopPin(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefKeys.desktopPin, value.trim());
    state = state.copyWith(desktopPin: value.trim());
  }

  Future<void> setActiveCloudProvider(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefKeys.activeCloudProvider, value.trim());
    state = state.copyWith(activeCloudProvider: value.trim());
  }

  Future<void> setOpenaiModel(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefKeys.openaiModel, value.trim());
    state = state.copyWith(openaiModel: value.trim());
  }
}
