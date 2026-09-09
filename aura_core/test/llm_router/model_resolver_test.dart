import 'package:test/test.dart';
import 'package:aura_core/src/llm_router/model_resolver.dart';

void main() {
  group('ModelResolver', () {
    test('stripModelContextMarker removes trailing [1m]', () {
      expect(ModelResolver.stripModelContextMarker('claude-opus-5[1m]'), equals('claude-opus-5'));
      expect(ModelResolver.stripModelContextMarker('claude-sonnet[1M]'), equals('claude-sonnet'));
      expect(ModelResolver.stripModelContextMarker('gpt-4o'), equals('gpt-4o'));
      expect(ModelResolver.stripModelContextMarker('a[1m'), equals('a[1m'));
    });

    test('resolveProviderAlias maps curated aliases correctly', () {
      const resolver = ModelResolver();
      expect(resolver.resolveProviderAlias('oa'), equals('openai'));
      expect(resolver.resolveProviderAlias('ant'), equals('anthropic'));
      expect(resolver.resolveProviderAlias('cc'), equals('claude'));
      expect(resolver.resolveProviderAlias('gc'), equals('gemini'));
      expect(resolver.resolveProviderAlias('gq'), equals('groq'));
      expect(resolver.resolveProviderAlias('ds'), equals('deepseek'));
      expect(resolver.resolveProviderAlias('or'), equals('openrouter'));
      expect(resolver.resolveProviderAlias('mm'), equals('mistral'));
      expect(resolver.resolveProviderAlias('unknown'), equals('unknown'));
    });

    test('flattenComboModels flattens nested combos, dedupes consecutive, and guards cycles', () {
      final combos = <String, List<String>>{
        'speed_tier': ['groq/llama-3.3-70b', 'deepseek/deepseek-chat'],
        'smart_tier': ['openai/gpt-4o', 'ant/claude-3-5-sonnet'],
        'super_combo': ['speed_tier', 'smart_tier'],
        'inner_only': ['deepseek/deepseek-chat'],
        'cycle_a': ['cycle_b', 'openai/gpt-4o'],
        'cycle_b': ['cycle_a', 'groq/llama-3.3-70b'],
      };

      final resolver = ModelResolver(
        comboLookup: (name) => combos[name],
      );

      // 1. Nested expansion & alias normalization
      final flat = resolver.flattenComboModels(['super_combo']);
      expect(flat, equals([
        'groq/llama-3.3-70b',
        'deepseek/deepseek-chat',
        'openai/gpt-4o',
        'anthropic/claude-3-5-sonnet',
      ]));

      // 2. Consecutive deduplication (e.g. inner-only + same leaf)
      final deduped = resolver.flattenComboModels(['inner_only', 'deepseek/deepseek-chat']);
      expect(deduped, equals(['deepseek/deepseek-chat']));

      // 2. Cycle detection guard
      final cycleFlat = resolver.flattenComboModels(['cycle_a']);
      expect(cycleFlat, contains('openai/gpt-4o'));
      expect(cycleFlat, contains('groq/llama-3.3-70b'));
    });

    test('resolveModel resolves standard provider/model format', () {
      const resolver = ModelResolver();
      final info = resolver.resolveModel('oa/gpt-4o');
      expect(info.provider, equals('openai'));
      expect(info.model, equals('gpt-4o'));
    });

    test('resolveModel resolves model alias', () {
      final resolver = ModelResolver(
        aliasLookup: (alias) => alias == 'flash' ? 'gc/gemini-2.0-flash' : null,
      );

      final info = resolver.resolveModel('flash');
      expect(info.provider, equals('gemini'));
      expect(info.model, equals('gemini-2.0-flash'));
    });

    test('resolveModel resolves combo name to first concrete model with flattened list', () {
      final resolver = ModelResolver(
        comboLookup: (name) => name == 'smart' ? ['openai/gpt-4o', 'ant/claude-3-5-sonnet'] : null,
      );

      final info = resolver.resolveModel('smart');
      expect(info.provider, equals('openai'));
      expect(info.model, equals('gpt-4o'));
      expect(info.comboModels, equals(['openai/gpt-4o', 'anthropic/claude-3-5-sonnet']));
    });

    test('resolveModel resolves bare provider alias if provider is active', () {
      final resolver = ModelResolver(
        isProviderActive: (p) => p == 'groq',
      );

      final info = resolver.resolveModel('gq');
      expect(info.provider, equals('groq'));
      expect(info.model, equals(''));
    });
  });
}
