import 'package:flutter_riverpod/legacy.dart';
import 'package:aura_core/storage/secure_storage_service.dart';
import 'desktop_model_defaults.dart';

/// Keys yang dipakai untuk menyimpan cloud settings desktop di SecureStorage.
/// Dipisah dari mobile (aura_mobile pakai SharedPreferences dengan key berbeda).
abstract class _DesktopSettingsKeys {
  static const activeCloudProvider = 'desktop_active_cloud_provider';
  static const openaiModel = 'desktop_openai_model';
  static const comboModel = 'desktop_combo_model';
}

// ── State ─────────────────────────────────────────────────────────────────────

class DesktopSettingsState {
  /// Provider aktif: 'gemini' | 'openai' | 'anthropic' | 'groq' | 'combo'
  final String activeCloudProvider;

  /// Model OpenAI yang dipilih, mis. 'gpt-4o' atau 'gpt-4o-mini'.
  final String openaiModel;

  /// String chain model untuk mode combo, mis. 'gemini/gemini-3.8-flash,openai/gpt-4o'.
  final String comboModel;

  const DesktopSettingsState({
    this.activeCloudProvider = 'gemini',
    this.openaiModel = DesktopModelDefaults.openaiModel,
    this.comboModel = DesktopModelDefaults.comboModel,
  });

  DesktopSettingsState copyWith({
    String? activeCloudProvider,
    String? openaiModel,
    String? comboModel,
  }) {
    return DesktopSettingsState(
      activeCloudProvider: activeCloudProvider ?? this.activeCloudProvider,
      openaiModel: openaiModel ?? this.openaiModel,
      comboModel: comboModel ?? this.comboModel,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class DesktopSettingsNotifier extends StateNotifier<DesktopSettingsState> {
  DesktopSettingsNotifier() : super(const DesktopSettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final provider = await SecureStorageService.instance.read(
          _DesktopSettingsKeys.activeCloudProvider,
        ) ??
        'gemini';
    final model = await SecureStorageService.instance.read(
          _DesktopSettingsKeys.openaiModel,
        ) ??
        DesktopModelDefaults.openaiModel;
    var combo = await SecureStorageService.instance.read(
          _DesktopSettingsKeys.comboModel,
        ) ??
        DesktopModelDefaults.comboModel;

    // Migrasi ringan: ganti model yang pensiun (mis. gemini-2.5-flash) jika ada di storage
    final migrated = DesktopModelDefaults.migrateCombo(combo);
    if (migrated != combo) {
      combo = migrated;
      await SecureStorageService.instance.write(
        _DesktopSettingsKeys.comboModel,
        combo,
      );
    }

    state = DesktopSettingsState(
      activeCloudProvider: provider,
      openaiModel: model,
      comboModel: combo,
    );
  }

  Future<void> setActiveProvider(String provider) async {
    await SecureStorageService.instance.write(
      _DesktopSettingsKeys.activeCloudProvider,
      provider,
    );
    state = state.copyWith(activeCloudProvider: provider);
  }

  Future<void> setOpenaiModel(String model) async {
    await SecureStorageService.instance.write(
      _DesktopSettingsKeys.openaiModel,
      model,
    );
    state = state.copyWith(openaiModel: model);
  }

  Future<void> setComboModel(String combo) async {
    await SecureStorageService.instance.write(
      _DesktopSettingsKeys.comboModel,
      combo,
    );
    state = state.copyWith(comboModel: combo);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final desktopSettingsProvider =
    StateNotifierProvider<DesktopSettingsNotifier, DesktopSettingsState>(
  (ref) => DesktopSettingsNotifier(),
);
