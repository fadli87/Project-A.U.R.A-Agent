import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura/src/native/gguf_model.dart';
import 'package:aura/src/providers/inference_provider.dart';

void main() {
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
}
