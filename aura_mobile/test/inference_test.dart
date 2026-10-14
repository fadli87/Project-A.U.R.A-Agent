import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_core/aura_core.dart';
import 'package:aura/src/providers/inference_provider.dart';
import 'package:aura/src/providers/settings_provider.dart';
import 'package:aura/src/ui/screens/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSecureStorage extends SecureStorageService {
  final Map<String, String> _data = {};

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  SecureStorageService.instance = MockSecureStorage();
  group('InferenceNotifier Tests', () {
    test('Initial state is idle', () {
      final container = ProviderContainer();
      final state = container.read(inferenceProvider);
      expect(state.status, InferenceStatus.idle);
      expect(state.text, '');
      expect(state.metrics.tokensGenerated, 0);
    });

    test('generate() fails gracefully when no model is loaded', () async {
      final container = ProviderContainer();
      final notifier = container.read(inferenceProvider.notifier);

      await notifier.generate(prompt: 'Halo');
      final state = container.read(inferenceProvider);

      expect(state.status, InferenceStatus.error);
      expect(state.errorMessage, contains('Tidak ada model GGUF'));
    });

    test('formatPrompt() formats Qwen / ChatML prompt correctly', () {
      final container = ProviderContainer();
      final notifier = container.read(inferenceProvider.notifier);

      // Default Qwen / ChatML format when no model is loaded
      final formattedQwen = notifier.formatPrompt('Siapa kamu?', systemPrompt: 'Kamu adalah asisten.');
      expect(formattedQwen, contains('<|im_start|>system'));
      expect(formattedQwen, contains('Kamu adalah asisten.'));
      expect(formattedQwen, contains('<|im_start|>user\nSiapa kamu?\n<|im_end|>'));
      expect(formattedQwen, contains('<|im_start|>assistant\n'));
    });

    test('reset() restores idle state', () {
      final container = ProviderContainer();
      final notifier = container.read(inferenceProvider.notifier);

      notifier.reset();
      final state = container.read(inferenceProvider);

      expect(state.status, InferenceStatus.idle);
      expect(state.text, '');
      expect(state.metrics.tokensGenerated, 0);
    });

    test('llmRouterClientProvider returns valid LlmRouterClient singleton', () {
      final container = ProviderContainer();
      final client = container.read(llmRouterClientProvider);
      expect(client, isNotNull);
      expect(client, isA<LlmRouterClient>());
    });

    test('toggleCloudAssistant flips useCloudAssistant boolean', () {
      final container = ProviderContainer();
      final notifier = container.read(inferenceProvider.notifier);

      expect(container.read(inferenceProvider).useCloudAssistant, isFalse);
      notifier.toggleCloudAssistant();
      expect(container.read(inferenceProvider).useCloudAssistant, isTrue);
      notifier.toggleCloudAssistant();
      expect(container.read(inferenceProvider).useCloudAssistant, isFalse);
    });

    test('generate() with useCloudAssistant true and empty API keys reports error', () async {
      final container = ProviderContainer();
      final notifier = container.read(inferenceProvider.notifier);
      notifier.toggleCloudAssistant();

      await notifier.generate(prompt: 'Halo Cloud');
      final state = container.read(inferenceProvider);

      expect(state.status, InferenceStatus.error);
      expect(state.errorMessage, contains('API Key Cloud kosong'));
    });

    test('InferenceState copyWith correctly handles fallbackNotice and activeProvider', () {
      const state = InferenceState();
      expect(state.fallbackNotice, isNull);
      expect(state.activeProvider, isNull);

      final updated = state.copyWith(
        fallbackNotice: 'Cloud kuota habis, beralih ke lokal.',
        activeProvider: 'gemini',
      );
      expect(updated.fallbackNotice, 'Cloud kuota habis, beralih ke lokal.');
      expect(updated.activeProvider, 'gemini');
    });
  });

  group('Model Tier Classification Tests', () {
    test('Classifies models into appropriate tiers by RAM and file size', () {
      expect(recommendTierForRam(3000), ModelTier.light);
      expect(recommendTierForRam(4096), ModelTier.light);
      expect(recommendTierForRam(6144), ModelTier.standard);
      expect(recommendTierForRam(8192), ModelTier.advanced);
      expect(recommendTierForRam(12288), ModelTier.advanced);
    });
  });

  group('resolveCloudModelOrCombo Tests', () {
    // ── Single provider: mapping ke model default konkret ──────────────────
    test('Single provider: gemini → gemini/gemini-2.5-flash', () {
      expect(
        resolveCloudModelOrCombo(const SettingsState(activeCloudProvider: 'gemini')),
        'gemini/gemini-2.5-flash',
      );
    });

    test('Single provider: openai (empty model) → openai/gpt-4o', () {
      expect(
        resolveCloudModelOrCombo(const SettingsState(activeCloudProvider: 'openai', openaiModel: '')),
        'openai/gpt-4o',
      );
    });

    test('Single provider: openai (model: gpt-4o-mini) → openai/gpt-4o-mini', () {
      expect(
        resolveCloudModelOrCombo(const SettingsState(activeCloudProvider: 'openai', openaiModel: 'gpt-4o-mini')),
        'openai/gpt-4o-mini',
      );
    });

    test('Single provider: anthropic → anthropic/claude-3-5-sonnet-20241022', () {
      expect(
        resolveCloudModelOrCombo(const SettingsState(activeCloudProvider: 'anthropic')),
        'anthropic/claude-3-5-sonnet-20241022',
      );
    });

    test('Single provider: groq → groq/llama-3.3-70b-versatile', () {
      expect(
        resolveCloudModelOrCombo(const SettingsState(activeCloudProvider: 'groq')),
        'groq/llama-3.3-70b-versatile',
      );
    });

    // ── Passthrough: sudah berformat 'provider/model' ─────────────────────
    test('Passthrough: openai/custom-ft dikembalikan utuh', () {
      expect(
        resolveCloudModelOrCombo(const SettingsState(activeCloudProvider: 'openai/custom-ft')),
        'openai/custom-ft',
      );
    });

    // ── Combo sentinel: normalisasi bare provider names ───────────────────
    test('Combo: bare names gemini,openai → model konkret lengkap', () {
      // MENGGANTIKAN: test lama yang berharap 'gemini,openai' passthrough via activeCloudProvider.
      // Sekarang combo hanya bisa lewat sentinel activeCloudProvider='combo' + comboModel.
      expect(
        resolveCloudModelOrCombo(const SettingsState(
          activeCloudProvider: 'combo',
          comboModel: 'gemini,openai',
        )),
        'gemini/gemini-2.5-flash,openai/gpt-4o',
      );
    });

    test('Combo: model campuran (ada yg sudah punya slash) → normalisasi sebagian', () {
      expect(
        resolveCloudModelOrCombo(const SettingsState(
          activeCloudProvider: 'combo',
          comboModel: 'gemini,openai/gpt-4o-mini',
        )),
        'gemini/gemini-2.5-flash,openai/gpt-4o-mini',
      );
    });

    test('Combo: comboModel kosong → fallback default', () {
      // MENGGANTIKAN: test lama yang berharap 'combo:auto' dikembalikan mentah-mentah.
      // Pseudo-keyword 'combo:auto' dihapus — tidak dikenal oleh backend router.
      // Sekarang string kosong jatuh ke fallback konkret yang aman.
      expect(
        resolveCloudModelOrCombo(const SettingsState(
          activeCloudProvider: 'combo',
          comboModel: '',
        )),
        'gemini/gemini-2.5-flash,openai/gpt-4o',
      );
    });

    test('Combo: chain konkret penuh dikembalikan utuh (no re-normalization)', () {
      expect(
        resolveCloudModelOrCombo(const SettingsState(
          activeCloudProvider: 'combo',
          comboModel: 'gemini/gemini-2.5-flash,openai/gpt-4o',
        )),
        'gemini/gemini-2.5-flash,openai/gpt-4o',
      );
    });

    // ── Alias 'google' sudah dihapus (Keputusan D) ───────────────────────
    test('Alias google dihapus: menghasilkan fail-fast string, bukan gemini', () {
      // Keputusan D: alias 'google' tidak lagi dikenali sebagai Gemini.
      // Router akan melempar FormatException untuk 'google/google' — perilaku ini disengaja.
      expect(
        resolveCloudModelOrCombo(const SettingsState(activeCloudProvider: 'google')),
        'google/google',
      );
    });
  });

  group('pruneHistoryForContext Tests', () {
    test('Preserves tool call and observation pairing without orphan tool messages', () {
      final now = DateTime.now();
      final messages = [
        ChatMessage(id: 1, sessionId: 1, role: MessageRole.user, content: 'User 1', timestamp: now),
        ChatMessage(id: 2, sessionId: 1, role: MessageRole.assistant, content: 'Call tool', timestamp: now, toolCallJson: '{"id":"call_1"}'),
        ChatMessage(id: 3, sessionId: 1, role: MessageRole.tool, content: 'Result 1', timestamp: now, toolCallId: 'call_1'),
        ChatMessage(id: 4, sessionId: 1, role: MessageRole.tool, content: 'Result 2', timestamp: now, toolCallId: 'call_2'),
        ChatMessage(id: 5, sessionId: 1, role: MessageRole.assistant, content: 'Assistant final', timestamp: now),
        ChatMessage(id: 6, sessionId: 1, role: MessageRole.user, content: 'User 2', timestamp: now),
      ];

      // Truncation with maxMessages = 3 would naively start at index 3 (Result 2), which is an orphan tool!
      // pruneHistoryForContext steps back to index 1 (Assistant with toolCallJson)
      final pruned = pruneHistoryForContext(messages, maxMessages: 3);
      expect(pruned.first.role, MessageRole.assistant);
      expect(pruned.first.content, 'Call tool');
      expect(pruned.any((m) => m.content == 'Result 1'), isTrue);
      expect(pruned.any((m) => m.content == 'Result 2'), isTrue);
      expect(pruned.last.content, 'User 2');
    });
  });
}
