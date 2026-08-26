import 'skill_manager_screen.dart';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aura_core/aura_core.dart';
import '../../providers/settings_provider.dart';
import '../theme/app_theme.dart';

/// Settings screen — Fase 8: Backup/Restore + Advanced (Safety Cap)
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExporting = false;
  bool _isRestoring = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Backup & Restore Section ──────────────────────────────────────
          _SectionHeader(
            icon: Icons.backup_outlined,
            label: 'Backup & Restore',
          ),

          // Reminder banner — muncul kalau sudah >7 hari sejak backup terakhir
          if (settings.shouldRemindBackup)
            _BackupReminderBanner(lastBackupDate: settings.lastBackupDate!),

          // Backup info card
          _InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (settings.neverBackedUp)
                  const Text(
                    'Anda belum pernah membuat backup. Backup melindungi riwayat chat, persona, dan skills dari risiko uninstall.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: AppTheme.statusReady, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Backup terakhir: ${_formatDate(settings.lastBackupDate!)}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.upload_outlined,
                        label: 'Export Backup',
                        isLoading: _isExporting,
                        onTap: _exportBackup,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.download_outlined,
                        label: 'Restore Backup',
                        isLoading: _isRestoring,
                        onTap: _pickAndRestoreBackup,
                        variant: _ButtonVariant.outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Advanced Section ──────────────────────────────────────────────
                    // ─── Customization Section ───
          _SectionHeader(
            icon: Icons.palette_outlined,
            label: 'Kustomisasi (Customization)',
          ),
          _InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.extension_outlined, color: AppTheme.primary),
                  title: const Text(
                    'Skill Manager',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: const Text(
                    'Aktifkan, nonaktifkan, atau tambahkan kemampuan (skills) baru asisten AURA.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SkillManagerScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          _SectionHeader(
            icon: Icons.tune_outlined,
            label: 'Lanjutan (Advanced)',
          ),

          _InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.loop_outlined,
                        size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Batas Iterasi Agentic Loop',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Maksimum langkah tool-call per giliran. Lebih tinggi = lebih kuat tapi lebih boros baterai.',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${settings.maxAgentIterations}',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.primary,
                    inactiveTrackColor: AppTheme.border,
                    thumbColor: AppTheme.primary,
                    overlayColor: AppTheme.primary.withValues(alpha: 0.15),
                    valueIndicatorColor: AppTheme.primary,
                    showValueIndicator: ShowValueIndicator.onDrag,
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: settings.maxAgentIterations.toDouble(),
                    min: 4,
                    max: 16,
                    divisions: 12,
                    label: '${settings.maxAgentIterations} langkah',
                    onChanged: (v) {
                      ref
                          .read(settingsProvider.notifier)
                          .setMaxAgentIterations(v.round());
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('4 (hemat baterai)',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 10)),
                    const Text('16 (maksimal)',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          Card(
            color: AppTheme.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.border, width: 1),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pencarian Internet Mendalam',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Saat aktif, pertanyaan pencarian Anda akan dikirim ke internet (DuckDuckGo/SearXNG). Riwayat chat dan data pribadi lain TETAP tidak pernah dikirim — hanya query pencarian spesifik yang dipicu oleh pencarian mendalam.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Aktifkan Deep Search',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    ),
                    value: settings.isDeepSearchEnabled,
                    activeTrackColor: AppTheme.primary,
                    onChanged: (val) {
                      ref
                          .read(settingsProvider.notifier)
                          .setDeepSearchEnabled(val);
                    },
                  ),
                  if (settings.isDeepSearchEnabled) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'SearXNG Instance Fallback URL',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: settings.searxngUrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. https://searx.be/',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      onChanged: (val) {
                        ref
                          .read(settingsProvider.notifier)
                          .setSearxngUrl(val.trim());
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Export ────────────────────────────────────────────────────────────────

  Future<void> _exportBackup() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final jsonData = await BackupService.instance.exportBackupData();
      final bytes = utf8.encode(jsonData);

      final result = await FilePickerPlatform.instance.saveFile(
        dialogTitle: 'Simpan Backup AURA',
        fileName:
            'aura_backup_${DateTime.now().toIso8601String().substring(0, 10)}.aurabackup',
        mimeType: 'application/octet-stream',
        bytes: bytes,
      );

      if (!mounted) return;

      if (result != null) {
        // Catat waktu backup berhasil
        await ref.read(settingsProvider.notifier).recordBackupNow();
        _showSnack('✅ Backup berhasil disimpan!', isError: false);
      }
    } catch (e) {
      if (mounted) _showSnack('❌ Gagal export: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ─── Restore ───────────────────────────────────────────────────────────────

  Future<void> _pickAndRestoreBackup() async {
    if (_isRestoring) return;

    final pickedFiles = await FilePickerPlatform.instance.pickFiles(
      dialogTitle: 'Pilih File Backup AURA',
      type: FileType.any,
    );

    if (pickedFiles.isEmpty) return;
    final pickedPath = pickedFiles.first.path;
    if (pickedPath == null || pickedPath.isEmpty) return;

    final fileContent = await File(pickedPath).readAsString();
    final jsonString = fileContent;

    // Validate first before any UI
    final validation = BackupService.instance.validateBackup(jsonString);
    if (!mounted) return;

    if (!validation.isValid) {
      _showSnack('❌ ${validation.errorMessage}', isError: true);
      return;
    }

    // Show confirmation dialog with backup summary
    final confirmed = await _showRestoreConfirmDialog(validation);
    if (!mounted || !confirmed) return;

    setState(() => _isRestoring = true);
    try {
      final success = await BackupService.instance.restoreBackupData(jsonString);
      if (!mounted) return;

      if (success) {
        _showSnack(
          '✅ Restore berhasil! Restart aplikasi untuk melihat perubahan.',
          isError: false,
        );
      } else {
        _showSnack('❌ Restore gagal. Coba lagi.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<bool> _showRestoreConfirmDialog(BackupValidationResult info) async {
    final exportDate = info.exportedAt != null
        ? _formatDate(info.exportedAt!)
        : 'tidak diketahui';

    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppTheme.warning, size: 22),
                SizedBox(width: 8),
                Text(
                  'Konfirmasi Restore',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ini akan mengganti SELURUH data saat ini dengan isi backup. Aksi ini tidak dapat dibatalkan.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                _RestoreInfoRow(
                    label: 'Tanggal backup', value: exportDate),
                _RestoreInfoRow(
                    label: 'Sesi chat',
                    value: '${info.sessionCount ?? 0} sesi'),
                _RestoreInfoRow(
                    label: 'Pesan',
                    value: '${info.messageCount ?? 0} pesan'),
                _RestoreInfoRow(
                    label: 'Versi skema',
                    value: 'v${info.schemaVersion ?? 1}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Batal',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.error,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Ya, Ganti Semua'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.error : AppTheme.statusReady,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }
}

class _BackupReminderBanner extends StatelessWidget {
  const _BackupReminderBanner({required this.lastBackupDate});
  final DateTime lastBackupDate;

  @override
  Widget build(BuildContext context) {
    final daysSince = DateTime.now().difference(lastBackupDate).inDays;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.warning, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sudah $daysSince hari sejak backup terakhir. Pertimbangkan untuk backup sekarang.',
              style: const TextStyle(
                  color: AppTheme.warning, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ButtonVariant { filled, outlined }

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.variant = _ButtonVariant.filled,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final _ButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    if (variant == _ButtonVariant.outlined) {
      return OutlinedButton.icon(
        onPressed: isLoading ? null : onTap,
        icon: isLoading
            ? const SizedBox(
                width: 14,
                height: 14,
                child:
                    CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textPrimary,
          side: BorderSide(color: AppTheme.border),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: isLoading ? null : onTap,
      icon: isLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.primary,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

class _RestoreInfoRow extends StatelessWidget {
  const _RestoreInfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
