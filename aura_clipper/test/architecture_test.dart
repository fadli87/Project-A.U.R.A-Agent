import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Architectural Purity', () {
    test('lib/src/pipeline and lib/src/analysis have ZERO imports from desktop/', () {
      final libDir = Directory('lib/src');
      expect(libDir.existsSync(), isTrue, reason: 'lib/src directory must exist');

      final targetDirs = [
        Directory('lib/src/pipeline'),
        Directory('lib/src/analysis'),
      ];

      final violations = <String>[];

      for (final dir in targetDirs) {
        if (!dir.existsSync()) continue;
        final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
        for (final file in files) {
          final content = file.readAsStringSync();
          final lines = content.split('\n');
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if ((line.trim().startsWith('import ') || line.trim().startsWith('export ')) &&
                (line.contains('desktop/') || line.contains('/desktop'))) {
              violations.add('${file.path}:${i + 1}: $line');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Violations found: Core pipeline and analysis modules must not depend on desktop implementation:\n${violations.join('\n')}',
      );
    });
  });
}
