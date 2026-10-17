/// Konstanta default model LLM untuk Aura Desktop.
///
/// Digunakan bersama oleh:
/// - [DesktopSettingsNotifier] (`desktop_settings_provider.dart`)
/// - [resolveDesktopModelOrCombo] (`resolve_desktop_model.dart`)
/// - Pengaturan & ChoiceChips di `main.dart`
class DesktopModelDefaults {
  DesktopModelDefaults._();

  /// Default model Gemini yang didukung dan direkomendasikan API.
  static const String geminiModel = 'gemini-3.8-flash';

  /// Default model OpenAI.
  static const String openaiModel = 'gpt-4o-mini';

  /// Default fallback chain combo.
  static const String comboModel = 'gemini/gemini-3.8-flash,openai/gpt-4o';

  /// Model-model lama yang sudah usang atau dipensiunkan oleh provider.
  static const List<String> deprecatedGeminiModels = [
    'gemini-2.5-flash',
  ];

  /// Memigrasikan string combo dari model yang dipensiunkan ke model aktif terbaru.
  static String migrateCombo(String combo) {
    var result = combo;
    for (final old in deprecatedGeminiModels) {
      result = result.replaceAll(old, geminiModel);
    }
    return result;
  }
}
