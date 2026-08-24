import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Permission approval card for sensitive tool calls.
/// Shown when the agent wants to execute a tool that requires explicit user consent.
/// Based on the GGUF Loader Agentic Mode approval card pattern.
///
/// Per rules/03-tool-calling.md: sensitive tools MUST show this dialog.
/// NEVER auto-execute sensitive actions.
class PermissionApprovalCard extends StatelessWidget {
  const PermissionApprovalCard({
    super.key,
    required this.toolName,
    required this.toolDescription,
    required this.parameters,
    required this.onAllow,
    required this.onDeny,
  });

  /// Name of the tool requesting permission (e.g. "create_reminder")
  final String toolName;

  /// Human-readable description of what the tool will do
  final String toolDescription;

  /// Key-value parameters the tool will use (shown for transparency)
  final Map<String, dynamic> parameters;

  final VoidCallback onAllow;
  final VoidCallback onDeny;

  /// Show the approval dialog and return true if user allowed, false if denied.
  static Future<bool> show(
    BuildContext context, {
    required String toolName,
    required String toolDescription,
    required Map<String, dynamic> parameters,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => PermissionApprovalCard(
        toolName: toolName,
        toolDescription: toolDescription,
        parameters: parameters,
        onAllow: () => Navigator.of(ctx).pop(true),
        onDeny: () => Navigator.of(ctx).pop(false),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.security, color: AppTheme.warning, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Izin Diperlukan',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'AURA ingin menjalankan: $toolName',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Text(
                  toolDescription,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Parameters
                if (parameters.isNotEmpty) ...[
                  const Text(
                    'Parameter:',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: parameters.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${e.key}: ',
                                style: TextStyle(
                                  color: AppTheme.secondary,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${e.value}',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDeny,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Tolak'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: BorderSide(
                            color: AppTheme.error.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onAllow,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Izinkan'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.statusReady,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),

                // Small disclaimer
                const SizedBox(height: 10),
                const Text(
                  'Izin ini hanya untuk aksi ini. AURA tidak akan mengeksekusi aksi sensitif secara otomatis.',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
