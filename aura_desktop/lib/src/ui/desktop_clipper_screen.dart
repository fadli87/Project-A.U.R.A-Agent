import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:aura_core/storage/secure_storage_service.dart';
import 'package:aura_clipper/aura_clipper_ui.dart';

import '../providers/desktop_settings_provider.dart';
import '../providers/resolve_desktop_model.dart';

/// Screen integrasi host (`aura_desktop`) untuk AURA Clipper.
/// Berfungsi sebagai satu-satunya perekat antara konfigurasi desktop (settings, secure keys)
/// dan UI mandiri `ClipperScreen`.
class DesktopClipperScreen extends ConsumerStatefulWidget {
  const DesktopClipperScreen({super.key});

  @override
  ConsumerState<DesktopClipperScreen> createState() => _DesktopClipperScreenState();
}

class _DesktopClipperScreenState extends ConsumerState<DesktopClipperScreen> {
  Directory? _workDir;
  Map<String, String> _apiKeys = {};
  bool _isLoadingKeys = true;

  @override
  void initState() {
    super.initState();
    _loadHostEnvironment();
  }

  Future<void> _loadHostEnvironment() async {
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final clipperDir = Directory(p.join(appSupportDir.path, 'clipper'));
      if (!clipperDir.existsSync()) {
        clipperDir.createSync(recursive: true);
      }

      final storage = SecureStorageService.instance;
      final geminiKey = await storage.read('gemini_api_key');
      final openaiKey = await storage.read('openai_api_key');
      final anthropicKey = await storage.read('anthropic_api_key');
      final groqKey = await storage.read('groq_api_key');

      final keys = <String, String>{};
      if (geminiKey != null && geminiKey.trim().isNotEmpty) {
        keys['gemini'] = geminiKey.trim();
      }
      if (openaiKey != null && openaiKey.trim().isNotEmpty) {
        keys['openai'] = openaiKey.trim();
      }
      if (anthropicKey != null && anthropicKey.trim().isNotEmpty) {
        keys['anthropic'] = anthropicKey.trim();
      }
      if (groqKey != null && groqKey.trim().isNotEmpty) {
        keys['groq'] = groqKey.trim();
      }

      if (mounted) {
        setState(() {
          _workDir = clipperDir;
          _apiKeys = keys;
          _isLoadingKeys = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingKeys = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingKeys) {
      return const Scaffold(
        backgroundColor: Color(0xFF13131A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7C4DFF)),
        ),
      );
    }

    // Resolusi modelOrCombo sesuai konfigurasi desktop settings
    final desktopSettings = ref.watch(desktopSettingsProvider);
    final modelOrCombo = resolveDesktopModelOrCombo(desktopSettings);

    // Jika tidak ada API key sama sekali, tampilkan pesan ramah mengarahkan ke Settings
    if (_apiKeys.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF13131A),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1B24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.key_off, size: 48, color: Color(0xFF7C4DFF)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'API Key Belum Dikonfigurasi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'AURA Clipper membutuhkan minimal satu API key (Gemini, OpenAI, Claude, atau Groq) untuk mendeteksi momen viral video secara cerdas.',
                  style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Beri tahu user membuka Server Settings di bilah samping
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Buka tombol Server Settings (ikon gerigi) di pojok kiri bawah untuk memasukkan API key.'),
                        backgroundColor: Color(0xFF7C4DFF),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Petunjuk Pengaturan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final effectiveWorkDir = _workDir ?? Directory(p.join(Directory.systemTemp.path, 'aura_clipper'));

    final hostConfig = ClipperHostConfig(
      modelOrCombo: modelOrCombo,
      apiKeys: _apiKeys,
      workDir: effectiveWorkDir,
      onPickOutputFolder: () async {
        return await FilePickerPlatform.instance.getDirectoryPath(
          dialogTitle: 'Pilih Folder Tujuan Ekspor Klip Video',
        );
      },
    );

    return ClipperScreen(config: hostConfig);
  }
}
