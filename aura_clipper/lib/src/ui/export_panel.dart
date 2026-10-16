import 'dart:io';
import 'package:flutter/material.dart';

/// Panel kontrol untuk mengekspor klip terpilih ke format MP4 melalui FFmpeg.
class ExportPanel extends StatelessWidget {
  final int selectedCount;
  final bool isExporting;
  final double exportProgress;
  final String? exportMessage;
  final List<String> exportedPaths;
  final String? outputFolder;
  final VoidCallback onPickFolder;
  final VoidCallback onExport;
  final ValueChanged<String>? onOpenFolder;

  const ExportPanel({
    super.key,
    required this.selectedCount,
    required this.isExporting,
    required this.exportProgress,
    this.exportMessage,
    required this.exportedPaths,
    this.outputFolder,
    required this.onPickFolder,
    required this.onExport,
    this.onOpenFolder,
  });

  void _openExplorer(String path) {
    if (onOpenFolder != null) {
      onOpenFolder!(path);
      return;
    }

    try {
      if (Platform.isWindows) {
        Process.run('explorer.exe', [path]);
      } else if (Platform.isMacOS) {
        Process.run('open', [path]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [path]);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final effectiveFolder = outputFolder ?? 'Folder default: <workDir>/exports';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.output, size: 20, color: Color(0xFF7C4DFF)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ekspor Klip Video',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: selectedCount > 0 ? const Color(0xFF7C4DFF).withValues(alpha: 0.2) : Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selectedCount > 0 ? const Color(0xFF7C4DFF) : Colors.white12,
                  ),
                ),
                child: Text(
                  '$selectedCount Klip Dipilih',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selectedCount > 0 ? Colors.white : Colors.white54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Output folder row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_open, size: 16, color: Colors.white60),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          effectiveFolder,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: isExporting ? null : onPickFolder,
                icon: const Icon(Icons.folder, size: 16),
                label: const Text('Pilih Folder'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Export progress bar if exporting
          if (isExporting) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: exportProgress > 0 ? exportProgress : null,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            if (exportMessage != null)
              Text(
                exportMessage!,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            const SizedBox(height: 8),
          ],

          // Action buttons & completed status
          Row(
            children: [
              if (!isExporting && exportedPaths.isNotEmpty && outputFolder != null) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openExplorer(outputFolder!),
                    icon: const Icon(Icons.folder_shared, size: 18),
                    label: const Text('Buka Folder di File Explorer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isExporting || selectedCount == 0 ? null : onExport,
                  icon: isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.movie_creation, size: 18),
                  label: Text(
                    isExporting ? 'Mengekspor Klip...' : 'Ekspor $selectedCount Klip Terpilih',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white30,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
