import 'package:flutter/material.dart';
import '../storage/clipper_settings.dart';
import '../desktop/tool_check.dart';

/// Dialog pengaturan untuk mengonfigurasi path tool eksternal, model Whisper, dan mengecek kesiapan sistem.
class ClipperSettingsDialog extends StatefulWidget {
  final ClipperSettings currentSettings;
  final ValueChanged<ClipperSettings> onSave;
  final Map<String, ToolCheckResult>? initialCheckResults;

  const ClipperSettingsDialog({
    super.key,
    required this.currentSettings,
    required this.onSave,
    this.initialCheckResults,
  });

  @override
  State<ClipperSettingsDialog> createState() => _ClipperSettingsDialogState();
}

class _ClipperSettingsDialogState extends State<ClipperSettingsDialog> {
  late final TextEditingController _ytDlpController;
  late final TextEditingController _ffmpegController;
  late final TextEditingController _whisperController;
  late final TextEditingController _whisperModelController;
  late final TextEditingController _languageController;
  late final TextEditingController _outputDirController;

  Map<String, ToolCheckResult>? _toolResults;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    final s = widget.currentSettings;
    _ytDlpController = TextEditingController(text: s.ytDlpPath);
    _ffmpegController = TextEditingController(text: s.ffmpegPath);
    _whisperController = TextEditingController(text: s.whisperPath);
    _whisperModelController = TextEditingController(text: s.whisperModelName);
    _languageController = TextEditingController(text: s.language);
    _outputDirController = TextEditingController(text: s.outputDir ?? '');
    _toolResults = widget.initialCheckResults;
  }

  @override
  void dispose() {
    _ytDlpController.dispose();
    _ffmpegController.dispose();
    _whisperController.dispose();
    _whisperModelController.dispose();
    _languageController.dispose();
    _outputDirController.dispose();
    super.dispose();
  }

  ClipperSettings _buildSettings() {
    return widget.currentSettings.copyWith(
      ytDlpPath: _ytDlpController.text.trim().isNotEmpty ? _ytDlpController.text.trim() : 'yt-dlp',
      ffmpegPath: _ffmpegController.text.trim().isNotEmpty ? _ffmpegController.text.trim() : 'ffmpeg',
      whisperPath: _whisperController.text.trim().isNotEmpty ? _whisperController.text.trim() : 'whisper-cli',
      whisperModelName: _whisperModelController.text.trim().isNotEmpty
          ? _whisperModelController.text.trim()
          : 'ggml-base.bin',
      language: _languageController.text.trim().isNotEmpty ? _languageController.text.trim() : 'auto',
      outputDir: _outputDirController.text.trim().isNotEmpty ? _outputDirController.text.trim() : null,
    );
  }

  Future<void> _runCheck() async {
    setState(() => _isChecking = true);
    final current = _buildSettings();
    final checker = ToolCheck();
    final list = await checker.checkAll(
      ytDlpPath: current.ytDlpPath,
      ffmpegPath: current.ffmpegPath,
      whisperPath: current.whisperPath,
    );
    final results = {for (final r in list) r.name: r};
    if (mounted) {
      setState(() {
        _toolResults = results;
        _isChecking = false;
      });
    }
  }

  Widget _buildToolItem(String key, String displayName, ToolCheckResult? res) {
    final isAvail = res?.isAvailable ?? false;
    final isFailed = res != null && !isAvail;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAvail
            ? const Color(0xFF00E676).withValues(alpha: 0.08)
            : isFailed
                ? const Color(0xFFFF5252).withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAvail
              ? const Color(0xFF00E676).withValues(alpha: 0.3)
              : isFailed
                  ? const Color(0xFFFF5252).withValues(alpha: 0.3)
                  : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAvail ? Icons.check_circle : (isFailed ? Icons.cancel : Icons.help_outline),
                size: 18,
                color: isAvail
                    ? const Color(0xFF00E676)
                    : isFailed
                        ? const Color(0xFFFF5252)
                        : Colors.white54,
              ),
              const SizedBox(width: 8),
              Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
              const Spacer(),
              if (res != null)
                Text(
                  isAvail ? 'Siap (${res.version ?? "OK"})' : 'Tidak Ditemukan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isAvail ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                  ),
                ),
            ],
          ),
          if (isFailed && res.installGuide.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              res.installGuide,
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1B24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.settings, color: Color(0xFF7C4DFF), size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'Pengaturan AURA Clipper',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Legal reminder banner (Rule 19, Keamanan Butir 9)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.gavel, color: Colors.amber, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Perhatian Legal: Pastikan Anda memiliki hak cipta atau izin untuk mengunduh, menganalisis, dan membagikan ulang konten video ini.',
                        style: TextStyle(color: Colors.amber, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section: Status Tool Eksternal
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Kesiapan Tool Eksternal',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          TextButton.icon(
                            onPressed: _isChecking ? null : _runCheck,
                            icon: _isChecking
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.refresh, size: 16),
                            label: const Text('Cek Tool'),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF7C4DFF)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildToolItem('yt-dlp', 'yt-dlp (Pengunduh Video & Caption)', _toolResults?['yt-dlp']),
                      _buildToolItem('ffmpeg', 'FFmpeg (Ekstraksi Audio & Kliping)', _toolResults?['ffmpeg']),
                      _buildToolItem('whisper', 'whisper.cpp (Transkripsi Lokal Opsional)', _toolResults?['whisper']),
                      const SizedBox(height: 16),

                      // Section: Path Executable
                      const Text(
                        'Konfigurasi Lokasi Executable',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ytDlpController,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Path yt-dlp',
                          hintText: 'yt-dlp atau C:\\path\\to\\yt-dlp.exe',
                          prefixIcon: Icon(Icons.download, size: 18),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _ffmpegController,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Path FFmpeg',
                          hintText: 'ffmpeg atau C:\\path\\to\\ffmpeg.exe',
                          prefixIcon: Icon(Icons.movie, size: 18),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _whisperController,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Path whisper-cli (whisper.cpp)',
                          hintText: 'whisper-cli atau C:\\path\\to\\whisper-cli.exe',
                          prefixIcon: Icon(Icons.mic, size: 18),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _whisperModelController,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Nama / Path Model Whisper (.bin)',
                          hintText: 'ggml-base.bin atau path absolut model',
                          prefixIcon: Icon(Icons.layers, size: 18),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _languageController,
                              style: const TextStyle(fontSize: 13, color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Bahasa Default',
                                hintText: 'id, en, auto',
                                prefixIcon: Icon(Icons.language, size: 18),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _outputDirController,
                              style: const TextStyle(fontSize: 13, color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Folder Ekspor Default (Opsional)',
                                hintText: 'Biarkan kosong untuk default',
                                prefixIcon: Icon(Icons.folder, size: 18),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Footer buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Batal', style: TextStyle(color: Colors.white60)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final updated = _buildSettings();
                      widget.onSave(updated);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Simpan Pengaturan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
