import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_clipper/aura_clipper_ui.dart';

void main() {
  group('Clipper UI Widget Tests', () {
    testWidgets('ClipperScreen renders header, input controls, and action buttons', (tester) async {
      final config = ClipperHostConfig(
        modelOrCombo: 'gemini/gemini-3.5-flash-lite',
        apiKeys: const {'gemini': 'test_key'},
        workDir: Directory.systemTemp,
      );

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ClipperScreen(config: config),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Memastikan header muncul
      expect(find.text('AURA Clipper'), findsOneWidget);
      expect(find.text('AI Video Repurposing Studio'), findsOneWidget);

      // Memastikan field URL dan tombol Mulai Analisis Video muncul
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Mulai Analisis Video'), findsOneWidget);
    });

    testWidgets('ClipListView displays candidates with scores and checkboxes', (tester) async {
      final candidates = [
        ClipCandidate(
          title: 'Kandidat 1 Viral Hook',
          startTime: const Duration(seconds: 10),
          endTime: const Duration(seconds: 45),
          score: 95,
          reason: 'Pernyataan pembuka sangat kuat',
        ),
        ClipCandidate(
          title: 'Kandidat 2 Momen Lucu',
          startTime: const Duration(seconds: 60),
          endTime: const Duration(seconds: 90),
          score: 82,
          reason: 'Reaksi tawa audiens',
        ),
      ];

      ClipCandidate? selected;
      final checked = <String>{candidates.first.title};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClipListView(
              candidates: candidates,
              selectedCandidate: selected,
              checkedTitles: checked,
              onSelect: (c) => selected = c,
              onToggleCheck: (c) {
                if (checked.contains(c.title)) {
                  checked.remove(c.title);
                } else {
                  checked.add(c.title);
                }
              },
              onToggleAll: (selectAll) {
                if (selectAll) {
                  checked.addAll(candidates.map((c) => c.title));
                } else {
                  checked.clear();
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Cek teks kandidat
      expect(find.text('Kandidat 1 Viral Hook'), findsOneWidget);
      expect(find.text('Kandidat 2 Momen Lucu'), findsOneWidget);
      expect(find.text('95'), findsOneWidget);
      expect(find.text('82'), findsOneWidget);

      // Cek durasi diformat
      expect(find.textContaining('35s'), findsOneWidget);
      expect(find.textContaining('30s'), findsOneWidget);

      // Klik kandidat kedua
      await tester.tap(find.text('Kandidat 2 Momen Lucu'));
      await tester.pumpAndSettle();
      expect(selected, candidates[1]);
    });

    testWidgets('ExportPanel shows selected count and export button', (tester) async {
      var exportTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportPanel(
              selectedCount: 3,
              isExporting: false,
              exportProgress: 0.0,
              exportedPaths: const [],
              outputFolder: 'C:/exports',
              onExport: () => exportTriggered = true,
              onPickFolder: () {},
              onOpenFolder: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ekspor 3 Klip Terpilih'), findsOneWidget);
      expect(find.text('C:/exports'), findsOneWidget);

      await tester.tap(find.text('Ekspor 3 Klip Terpilih'));
      await tester.pumpAndSettle();
      expect(exportTriggered, isTrue);
    });
  });
}
