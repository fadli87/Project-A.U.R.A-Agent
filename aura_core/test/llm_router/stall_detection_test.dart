import 'dart:async';
import 'package:test/test.dart';
import 'package:aura_core/src/llm_router/stall_detection.dart';

void main() {
  group('StallDetectionTransformer', () {
    test('passes data normally when chunks arrive in time', () async {
      final controller = StreamController<String>();
      final received = <String>[];

      final stream = controller.stream.withStallDetection(
        timeout: const Duration(milliseconds: 100),
      );

      final sub = stream.listen(received.add);

      controller.add('chunk 1');
      await Future.delayed(const Duration(milliseconds: 20));
      controller.add('chunk 2');
      await Future.delayed(const Duration(milliseconds: 20));
      controller.add('chunk 3');
      await controller.close();

      await sub.asFuture();
      expect(received, equals(['chunk 1', 'chunk 2', 'chunk 3']));
    });

    test('throws StallTimeoutException when stream stops receiving data', () async {
      final controller = StreamController<String>();
      final received = <String>[];

      final stream = controller.stream.withStallDetection(
        timeout: const Duration(milliseconds: 60),
        label: 'test_stream',
      );

      Object? thrownError;
      final completer = Completer<void>();

      stream.listen(
        received.add,
        onError: (err) {
          thrownError = err;
          completer.complete();
        },
      );

      controller.add('first');
      // Diam tanpa data lebih lama dari 60ms
      await Future.delayed(const Duration(milliseconds: 120));
      await completer.future;

      expect(thrownError, isA<StallTimeoutException>());
      final stallErr = thrownError as StallTimeoutException;
      expect(stallErr.label, equals('test_stream'));
      expect(received, equals(['first']));

      await controller.close();
    });
  });
}
