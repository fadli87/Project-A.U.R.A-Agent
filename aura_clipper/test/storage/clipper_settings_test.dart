import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_clipper/aura_clipper.dart';

void main() {
  group('ClipperSettings & ClipperSettingsStore', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('clipper_settings_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('default settings has standard values', () {
      const settings = ClipperSettings();
      expect(settings.ytDlpPath, 'yt-dlp');
      expect(settings.ffmpegPath, 'ffmpeg');
      expect(settings.whisperPath, 'whisper-cli');
      expect(settings.whisperModelName, 'ggml-base.bin');
      expect(settings.language, 'auto');
      expect(settings.allowedHosts, contains('youtube.com'));
    });

    test('round-trip save and load from store', () async {
      final store = ClipperSettingsStore.fromDirectory(tempDir);
      
      // Load awal menghasilkan default
      final initial = await store.load();
      expect(initial.language, 'auto');

      // Modifikasi dan simpan
      final updated = initial.copyWith(
        language: 'id',
        whisperModelName: 'ggml-medium.bin',
        outputDir: '/custom/output',
      );
      await store.save(updated);

      // Muat ulang dari file
      final reloadedStore = ClipperSettingsStore.fromDirectory(tempDir);
      final loaded = await reloadedStore.load();

      expect(loaded.language, 'id');
      expect(loaded.whisperModelName, 'ggml-medium.bin');
      expect(loaded.outputDir, '/custom/output');
      expect(loaded.ytDlpPath, 'yt-dlp');
    });

    test('customModel serializes and deserializes properly', () async {
      final store = ClipperSettingsStore.fromDirectory(tempDir);
      final initial = await store.load();
      expect(initial.customModel, isNull);

      final withModel = initial.copyWith(customModel: 'gemini/gemini-3.8-flash');
      await store.save(withModel);

      final reloadedStore = ClipperSettingsStore.fromDirectory(tempDir);
      final loaded = await reloadedStore.load();
      expect(loaded.customModel, 'gemini/gemini-3.8-flash');

      // Test clearing customModel
      final cleared = loaded.copyWith(clearCustomModel: true);
      expect(cleared.customModel, isNull);
    });
  });
}
