import 'package:test/test.dart';
import 'package:aura_core/src/llm_router/combo_strategy.dart';

void main() {
  group('combo_strategy - CapabilityDetector', () {
    test('detectRequired detects vision, pdf, and audio from trailing user message', () {
      final body = {
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Old turn with image'},
              {'type': 'image_url', 'image_url': {'url': 'http://example.com/old.png'}},
            ]
          },
          {'role': 'assistant', 'content': 'Understood'},
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'New turn with document'},
              {'type': 'document', 'mimeType': 'application/pdf'},
            ]
          }
        ],
        'tools': [
          {
            'type': 'function',
            'function': {'name': 'calculator'}
          }
        ]
      };

      final caps = CapabilityDetector.detectRequired(body);
      // Only trailing user message is scanned for modalities
      expect(caps.contains(ModelCapability.pdf), isTrue);
      expect(caps.contains(ModelCapability.vision), isFalse); // Old turn vision is ignored
      expect(caps.contains(ModelCapability.tools), isTrue);
    });

    test('reorderByCapabilities moves matching models to front', () {
      final models = ['model_text', 'model_vision_pdf', 'model_vision_only'];
      final required = {ModelCapability.vision, ModelCapability.pdf};

      bool checker(String model, ModelCapability cap) {
        if (model == 'model_vision_pdf') return true;
        if (model == 'model_vision_only' && cap == ModelCapability.vision) return true;
        return false;
      }

      final reordered = CapabilityDetector.reorderByCapabilities(
        models,
        required,
        checker,
      );

      expect(reordered[0], equals('model_vision_pdf'));
      expect(reordered.contains('model_text'), isTrue);
      expect(reordered.contains('model_vision_only'), isTrue);
    });
  });

  group('combo_strategy - Turn Detection', () {
    test('detectNewTurn returns true for user turn with text and false for tool turn', () {
      final userTurn = {
        'messages': [
          {'role': 'assistant', 'content': 'Done'},
          {'role': 'user', 'content': 'What next?'}
        ]
      };
      expect(detectNewTurn(userTurn), isTrue);

      final toolTurn = {
        'messages': [
          {
            'role': 'assistant',
            'content': 'Searching...',
          },
          {
            'role': 'tool',
            'content': 'Search result output',
          }
        ]
      };
      expect(detectNewTurn(toolTurn), isFalse);
    });
  });

  group('combo_strategy - ComboStrategyManager', () {
    late ComboStrategyManager manager;

    setUp(() {
      manager = ComboStrategyManager();
    });

    test('fallback returns identical order', () {
      final models = ['m1', 'm2', 'm3'];
      final result = manager.apply(
        strategy: ComboStrategy.fallback,
        models: models,
      );
      expect(result, equals(['m1', 'm2', 'm3']));
    });

    test('roundRobin rotates on every new turn', () {
      final models = ['m1', 'm2', 'm3'];

      final turn1 = manager.apply(
        strategy: ComboStrategy.roundRobin,
        models: models,
        comboName: 'test_combo',
        newTurn: true,
      );
      expect(turn1, equals(['m1', 'm2', 'm3']));

      final turn2 = manager.apply(
        strategy: ComboStrategy.roundRobin,
        models: models,
        comboName: 'test_combo',
        newTurn: true,
      );
      expect(turn2, equals(['m2', 'm3', 'm1']));

      final turn3 = manager.apply(
        strategy: ComboStrategy.roundRobin,
        models: models,
        comboName: 'test_combo',
        newTurn: true,
      );
      expect(turn3, equals(['m3', 'm1', 'm2']));
    });

    test('sticky sticks for specified turns before rotating', () {
      final models = ['m1', 'm2'];

      // stickyLimit = 2
      final turn1 = manager.apply(
        strategy: ComboStrategy.sticky,
        models: models,
        comboName: 'sticky_combo',
        stickyLimit: 2,
        newTurn: true,
      );
      expect(turn1, equals(['m1', 'm2']));

      final turn2 = manager.apply(
        strategy: ComboStrategy.sticky,
        models: models,
        comboName: 'sticky_combo',
        stickyLimit: 2,
        newTurn: true,
      );
      // Still on m1
      expect(turn2, equals(['m1', 'm2']));

      final turn3 = manager.apply(
        strategy: ComboStrategy.sticky,
        models: models,
        comboName: 'sticky_combo',
        stickyLimit: 2,
        newTurn: true,
      );
      // Rotates to m2
      expect(turn3, equals(['m2', 'm1']));
    });
  });
}
