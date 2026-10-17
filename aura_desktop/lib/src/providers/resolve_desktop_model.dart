import 'desktop_model_defaults.dart';
import 'desktop_settings_provider.dart';

/// Resolves [DesktopSettingsState] menjadi model string yang siap dikirim ke
/// [LlmRouterClient.streamGenerate].
///
/// Logic identik dengan `resolveCloudModelOrCombo()` di `aura_mobile/inference_provider.dart`.
/// Dijaga tetap terpisah (tidak di-extract ke `aura_core`) sampai `aura_clipper`
/// juga membutuhkannya — baru akan di-extract ke shared package.
///
/// Sentinel value: [DesktopSettingsState.activeCloudProvider] == `'combo'`
/// → baca [DesktopSettingsState.comboModel], normalisasi tiap elemen.
String resolveDesktopModelOrCombo(DesktopSettingsState settings) {
  final provider = settings.activeCloudProvider.trim().toLowerCase();

  // ── Mode Combo: sentinel 'combo' ─────────────────────────────────────────
  if (provider == 'combo') {
    final rawCombo = settings.comboModel.trim();
    final target = rawCombo.isNotEmpty
        ? rawCombo
        : DesktopModelDefaults.comboModel;

    return target
        .split(',')
        .map((part) => _normalizeProviderPart(part.trim()))
        .where((p) => p.isNotEmpty)
        .join(',');
  }

  // ── Mode Single Provider ──────────────────────────────────────────────────
  if (provider == 'openai' || provider == 'oa') {
    final m =
        settings.openaiModel.isNotEmpty ? settings.openaiModel : 'gpt-4o';
    return m.contains('/') ? m : 'openai/$m';
  }
  if (provider == 'gemini' || provider == 'gc') {
    return 'gemini/${DesktopModelDefaults.geminiModel}';
  }
  if (provider == 'anthropic' || provider == 'claude') {
    return 'anthropic/claude-3-5-sonnet-20241022';
  }
  if (provider == 'groq' || provider == 'gq') {
    return 'groq/llama-3.3-70b-versatile';
  }

  // Passthrough: sudah berformat 'provider/model' atau 'p1/m1,p2/m2'
  if (provider.contains('/') || provider.contains(',')) {
    return DesktopModelDefaults.migrateCombo(provider);
  }

  // Unknown provider → fail-fast: biarkan router melempar FormatException
  return '$provider/$provider';
}

/// Normalisasi satu elemen combo: bare provider name → default model konkret.
/// Elemen yang sudah memiliki slash '/' dikembalikan utuh (dengan migrasi model pensiun).
String _normalizeProviderPart(String part) {
  if (part.isEmpty) return '';
  if (part.contains('/')) {
    return DesktopModelDefaults.migrateCombo(part);
  }

  switch (part.toLowerCase()) {
    case 'gemini':
    case 'gc':
      return 'gemini/${DesktopModelDefaults.geminiModel}';
    case 'openai':
    case 'oa':
      return 'openai/gpt-4o';
    case 'anthropic':
    case 'claude':
      return 'anthropic/claude-3-5-sonnet-20241022';
    case 'groq':
    case 'gq':
      return 'groq/llama-3.3-70b-versatile';
    default:
      // Unknown bare name → fail-fast di router
      return '$part/$part';
  }
}
