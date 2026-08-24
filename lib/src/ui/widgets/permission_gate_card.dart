import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aura/src/agent/agent_tools.dart';
import 'package:aura/src/ui/theme/app_theme.dart';

/// Permission-gate approval card widget for sensitive tool execution
class PermissionGateCard extends StatelessWidget {
  final ToolCallRequest request;
  final AgentTool tool;
  final VoidCallback onAllow;
  final VoidCallback onDeny;

  const PermissionGateCard({
    super.key,
    required this.request,
    required this.tool,
    required this.onAllow,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, color: AppTheme.secondary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Permintaan Izin Akses Tool',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'AURA meminta izin untuk menjalankan aksi sensitif:',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alat: ${tool.name}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Argumen: ${request.arguments}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: onDeny,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.statusError,
                  side: const BorderSide(color: AppTheme.statusError),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Tolak'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onAllow,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  foregroundColor: Colors.black,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Izinkan'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
