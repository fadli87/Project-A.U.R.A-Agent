// aura_desktop/test/resolve_desktop_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_desktop/src/providers/desktop_settings_provider.dart';
import 'package:aura_desktop/src/providers/resolve_desktop_model.dart';

void main() {
  group('resolveDesktopModelOrCombo', () {
    // ── Single Provider ─────────────────────────────────────────────────────

    test('#1 gemini → default gemini model', () {
      final result = resolveDesktopModelOrCombo(
        const DesktopSettingsState(activeCloudProvider: 'gemini'),
      );
      expect(result, 'gemini/gemini-2.5-flash');
    });

    test('#2 openai + model set → prefixed correctly', () {
      final result = resolveDesktopModelOrCombo(
        const DesktopSettingsState(
          activeCloudProvider: 'openai',
          openaiModel: 'gpt-4o-mini',
        ),
      );
      expect(result, 'openai/gpt-4o-mini');
    });

    test('#3 openai + model already has slash → passthrough', () {
      final result = resolveDesktopModelOrCombo(
        const DesktopSettingsState(
          activeCloudProvider: 'openai',
          openaiModel: 'openai/gpt-4o',
        ),
      );
      expect(result, 'openai/gpt-4o');
    });

    test('#4 anthropic → default claude model', () {
      final result = resolveDesktopModelOrCombo(
        const DesktopSettingsState(activeCloudProvider: 'anthropic'),
      );
      expect(result, 'anthropic/claude-3-5-sonnet-20241022');
    });

    test('#5 groq → default groq model', () {
      final result = resolveDesktopModelOrCombo(
        const DesktopSettingsState(activeCloudProvider: 'groq'),
      );
      expect(result, 'groq/llama-3.3-70b-versatile');
    });

    // ── Combo Mode ───────────────────────────────────────────────────────────

    test('#6 combo bare names → expanded to default models', () {
      final result = resolveDesktopModelOrCombo(
        const DesktopSettingsState(
          activeCloudProvider: 'combo',
          comboModel: 'gemini,openai',
        ),
      );
      expect(result, 'gemini/gemini-2.5-flash,openai/gpt-4o');
    });

    test('#7 combo mixed (bare + full) → normalized', () {
      final result = resolveDesktopModelOrCombo(
        const DesktopSettingsState(
          activeCloudProvider: 'combo',
          comboModel: 'gemini,openai/gpt-4o-mini',
        ),
      );
      expect(result, 'gemini/gemini-2.5-flash,openai/gpt-4o-mini');
    });

    test('#8 combo with empty string → fallback default chain', () {
      final result = resolveDesktopModelOrCombo(
        const DesktopSettingsState(
          activeCloudProvider: 'combo',
          comboModel: '',
        ),
      );
      expect(result, 'gemini/gemini-2.5-flash,openai/gpt-4o');
    });

    test('#9 combo full paths → passthrough unchanged', () {
      final result = resolveDesktopModelOrCombo(
        const DesktopSettingsState(
          activeCloudProvider: 'combo',
          comboModel: 'gemini/gemini-2.5-flash,anthropic/claude-3-5-sonnet-20241022',
        ),
      );
      expect(result, 'gemini/gemini-2.5-flash,anthropic/claude-3-5-sonnet-20241022');
    });

    // ── Passthrough / Unknown ────────────────────────────────────────────────

    test('#10 provider already has slash → passthrough', () {
      final result = resolveDesktopModelOrCombo(
        const DesktopSettingsState(activeCloudProvider: 'openai/gpt-4o'),
      );
      expect(result, 'openai/gpt-4o');
    });

    test('#11 unknown bare provider → fail-fast sentinel', () {
      final result = resolveDesktopModelOrCombo(
        const DesktopSettingsState(activeCloudProvider: 'custom-llm'),
      );
      expect(result, 'custom-llm/custom-llm');
    });
  });
}
