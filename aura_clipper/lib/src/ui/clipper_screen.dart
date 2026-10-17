import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clipper_host_config.dart';
import 'clipper_controller.dart';
import 'clip_preview_player.dart';
import 'clip_list_view.dart';
import 'export_panel.dart';
import 'clipper_settings_dialog.dart';
import '../models/video_job.dart';

/// Layar utama AURA Clipper dengan tata letak dua kolom:
/// - Kiri: Input URL, rentang/fokus, kontrol analisis, riwayat job, pengaturan tool.
/// - Kanan: Progres stage, pratinjau klip (fvp Direct3D), daftar kandidat momen, dan panel ekspor.
class ClipperScreen extends ConsumerStatefulWidget {
  final ClipperHostConfig config;

  const ClipperScreen({
    super.key,
    required this.config,
  });

  @override
  ConsumerState<ClipperScreen> createState() => _ClipperScreenState();
}

class _ClipperScreenState extends ConsumerState<ClipperScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _focusController;
  late final TextEditingController _fromSecController;
  late final TextEditingController _toSecController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _focusController = TextEditingController();
    _fromSecController = TextEditingController();
    _toSecController = TextEditingController();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _focusController.dispose();
    _fromSecController.dispose();
    _toSecController.dispose();
    super.dispose();
  }

  void _pasteFromClipboard(ClipperNotifier notifier) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      _urlController.text = data.text!.trim();
      notifier.setUrl(data.text!.trim());
    }
  }

  void _openSettingsDialog(BuildContext context, ClipperState state, ClipperNotifier notifier) {
    showDialog(
      context: context,
      builder: (_) => ClipperSettingsDialog(
        currentSettings: state.settings,
        initialCheckResults: state.toolCheckResults,
        onSave: (s) => notifier.updateSettings(s),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clipperControllerProvider(widget.config));
    final notifier = ref.read(clipperControllerProvider(widget.config).notifier);

    // Sinkronisasi input field jika diubah secara programatik (misalnya saat klik riwayat)
    if (_urlController.text != state.url && !state.isRunning) {
      _urlController.text = state.url;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF13131A),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ==============================================================
          // KOLOM KIRI: INPUT & KONTROL PIPELINE (LEBAR: 380px)
          // ==============================================================
          Container(
            width: 380,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Material(
              color: const Color(0xFF181824),
              child: Column(
              children: [
                // Header Bar Kolom Kiri
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.content_cut, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AURA Clipper',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              'AI Video Repurposing Studio',
                              style: TextStyle(fontSize: 11, color: Colors.white54),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white60, size: 20),
                        onPressed: () => _openSettingsDialog(context, state, notifier),
                        tooltip: 'Pengaturan Clipper & Tool',
                      ),
                    ],
                  ),
                ),

                // Form Input & Opsi Analisis
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Input URL Video
                        const Text(
                          'Tautan Video YouTube',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _urlController,
                          enabled: !state.isRunning,
                          onChanged: notifier.setUrl,
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'https://www.youtube.com/watch?v=...',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                            prefixIcon: const Icon(Icons.link, size: 18, color: Colors.white60),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_urlController.text.isNotEmpty && !state.isRunning)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: Colors.white38),
                                    onPressed: () {
                                      _urlController.clear();
                                      notifier.setUrl('');
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.paste, size: 16, color: Color(0xFF7C4DFF)),
                                  tooltip: 'Tempel dari Clipboard',
                                  onPressed: !state.isRunning ? () => _pasteFromClipboard(notifier) : null,
                                ),
                              ],
                            ),
                            filled: true,
                            fillColor: const Color(0xFF13131A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Opsi Rentang Waktu (from - to)
                        const Text(
                          'Rentang Waktu Analisis (Opsional)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _fromSecController,
                                enabled: !state.isRunning,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 13, color: Colors.white),
                                onChanged: (v) {
                                  final val = int.tryParse(v);
                                  notifier.setRange(fromSec: val, toSec: state.toSec);
                                },
                                decoration: InputDecoration(
                                  labelText: 'Dari (detik)',
                                  hintText: '0',
                                  filled: true,
                                  fillColor: const Color(0xFF13131A),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _toSecController,
                                enabled: !state.isRunning,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 13, color: Colors.white),
                                onChanged: (v) {
                                  final val = int.tryParse(v);
                                  notifier.setRange(fromSec: state.fromSec, toSec: val);
                                },
                                decoration: InputDecoration(
                                  labelText: 'Sampai (detik)',
                                  hintText: 'Maks',
                                  filled: true,
                                  fillColor: const Color(0xFF13131A),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Custom Focus
                        const Text(
                          'Fokus Khusus (Opsional)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _focusController,
                          enabled: !state.isRunning,
                          onChanged: notifier.setFocus,
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Contoh: momen debat panas, punchline lucu...',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                            prefixIcon: const Icon(Icons.filter_center_focus, size: 18, color: Colors.white60),
                            filled: true,
                            fillColor: const Color(0xFF13131A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Slider Jumlah Klip Maksimum
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Target Jumlah Klip',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            ),
                            Text(
                              '${state.maxClips} klip',
                              style: const TextStyle(color: Color(0xFF7C4DFF), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Slider(
                          value: state.maxClips.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          activeColor: const Color(0xFF7C4DFF),
                          onChanged: !state.isRunning ? (v) => notifier.setMaxClips(v.round()) : null,
                        ),
                        const SizedBox(height: 8),

                        // Force Whisper Checkbox
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Paksa Whisper Transcriber', style: TextStyle(fontSize: 13, color: Colors.white70)),
                          subtitle: const Text('Abaikan caption YouTube bawaan jika tersedia', style: TextStyle(fontSize: 11, color: Colors.white38)),
                          value: state.forceWhisper,
                          activeColor: const Color(0xFF7C4DFF),
                          onChanged: !state.isRunning ? (v) => notifier.setForceWhisper(v ?? false) : null,
                        ),
                        const SizedBox(height: 16),

                        // Action Button: Mulai Analisis / Batal
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: state.isRunning
                              ? OutlinedButton.icon(
                                  onPressed: notifier.cancelPipeline,
                                  icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 18),
                                  label: const Text('Batal Proses', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.redAccent),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () => notifier.startPipeline(),
                                  icon: const Icon(Icons.bolt, color: Colors.white, size: 20),
                                  label: const Text('Mulai Analisis Video', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C4DFF),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),

                        // Error Banner jika ada
                        if (state.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Gagal Memproses',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  state.errorMessage!,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                if (state.rawLogPath != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Log mentah: ${state.rawLogPath}',
                                    style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Riwayat Video Job
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.history, size: 16, color: Colors.white60),
                            const SizedBox(width: 6),
                            Text(
                              'Riwayat Video (${state.historyJobs.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            ),
                            const Spacer(),
                            if (state.historyJobs.isNotEmpty && !state.isRunning)
                              IconButton(
                                icon: const Icon(Icons.delete_sweep, size: 16, color: Colors.white38),
                                tooltip: 'Bersihkan Riwayat & Cache Job',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => notifier.clearJobCache(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (state.historyJobs.isEmpty)
                          const Text('Belum ada riwayat job.', style: TextStyle(color: Colors.white30, fontSize: 12))
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: state.historyJobs.length,
                            itemBuilder: (context, i) {
                              final job = state.historyJobs[i];
                              final isCurrent = state.currentJob?.id == job.id;
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  job.status == VideoJobStatus.done
                                      ? Icons.check_circle
                                      : (job.status == VideoJobStatus.error ? Icons.error : Icons.pending),
                                  size: 16,
                                  color: job.status == VideoJobStatus.done ? const Color(0xFF00E676) : Colors.white38,
                                ),
                                title: Text(
                                  job.title ?? job.url,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isCurrent ? const Color(0xFF7C4DFF) : Colors.white70,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${job.status.name} • ${job.createdAt.day}/${job.createdAt.month}/${job.createdAt.year}',
                                  style: const TextStyle(fontSize: 10, color: Colors.white38),
                                ),
                                onTap: !state.isRunning ? () => notifier.loadJob(job) : null,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                // Legal Reminder Footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFF13131A),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: Colors.white38),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Pastikan Anda memiliki izin atas hak cipta video yang diunduh.',
                          style: TextStyle(fontSize: 10, color: Colors.white38),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

          // ==============================================================
          // KOLOM KANAN: PROGRES, PRATINJAU VIDEO, KANDIDAT & EKSPOR
          // ==============================================================
          Expanded(
            child: Container(
              color: const Color(0xFF13131A),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stage Progress Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A24),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              state.isRunning
                                  ? Icons.sync
                                  : (state.activeStage == VideoJobStatus.done ? Icons.task_alt : Icons.info_outline),
                              size: 18,
                              color: state.isRunning
                                  ? const Color(0xFF7C4DFF)
                                  : (state.activeStage == VideoJobStatus.done ? const Color(0xFF00E676) : Colors.white60),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              state.activeStage != null
                                  ? 'Status: ${state.activeStage!.name.toUpperCase()}'
                                  : 'AURA Clipper Studio',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            ),
                            const Spacer(),
                            if (state.isRunning)
                              Text(
                                '${(state.progressFraction * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Color(0xFF7C4DFF),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                          ],
                        ),
                        if (state.isRunning) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: state.progressFraction > 0 ? state.progressFraction : null,
                              backgroundColor: Colors.white10,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C4DFF)),
                              minHeight: 6,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          state.progressMessage,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Area Pratinjau Video (jika kandidat dipilih & video ada)
                  if (state.selectedCandidate != null &&
                      state.currentJob?.localVideoPath != null &&
                      File(state.currentJob!.localVideoPath!).existsSync()) ...[
                    Text(
                      'Pratinjau Momen: "${state.selectedCandidate!.title}"',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    ClipPreviewPlayer(
                      videoPath: state.currentJob!.localVideoPath!,
                      startTime: state.selectedCandidate!.startTime,
                      endTime: state.selectedCandidate!.endTime,
                      autoPlay: true,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Daftar Kandidat Klip
                  Expanded(
                    child: ClipListView(
                      candidates: state.candidates,
                      selectedCandidate: state.selectedCandidate,
                      checkedTitles: state.checkedCandidateTitles,
                      onSelect: (c) => notifier.selectCandidate(c),
                      onToggleCheck: (c) => notifier.toggleCandidateChecked(c),
                      onToggleAll: (all) => notifier.toggleAllCandidates(all),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Panel Ekspor Klip Terpilih
                  ExportPanel(
                    selectedCount: state.checkedCandidateTitles.length,
                    isExporting: state.isExporting,
                    exportProgress: state.exportProgress,
                    exportMessage: state.exportMessage,
                    exportedPaths: state.exportedPaths,
                    outputFolder: state.lastExportFolder ?? state.settings.outputDir,
                    onPickFolder: () async {
                      if (widget.config.onPickOutputFolder != null) {
                        final picked = await widget.config.onPickOutputFolder!();
                        if (picked != null) {
                          await notifier.updateSettings(state.settings.copyWith(outputDir: picked));
                        }
                      }
                    },
                    onExport: () => notifier.exportSelected(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
