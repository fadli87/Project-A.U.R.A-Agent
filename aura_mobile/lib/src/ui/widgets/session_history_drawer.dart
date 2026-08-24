import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/chat_provider.dart';
import '../../providers/model_provider.dart';
import '../theme/app_theme.dart';
import 'package:aura_core/aura_core.dart';

/// Drawer showing all past chat sessions with swipe-to-delete support.
class SessionHistoryDrawer extends ConsumerWidget {
  const SessionHistoryDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(allSessionsProvider);
    final chatState = ref.watch(chatProvider);

    return Drawer(
      backgroundColor: AppTheme.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Riwayat Chat',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppTheme.border, height: 1),

            // ── New Session Button ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final modelState = ref.read(modelProvider);
                    await ref.read(chatProvider.notifier).startNewSession(
                          modelName: modelState.activeModel?.name,
                        );
                    ref.invalidate(allSessionsProvider);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Chat Baru'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Session List ────────────────────────────────────────
            Expanded(
              child: sessionsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
                error: (e, _) => Center(
                  child: Text('Gagal memuat riwayat', style: TextStyle(color: AppTheme.error)),
                ),
                data: (sessions) {
                  if (sessions.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Belum ada riwayat chat.\nMulai percakapan pertama Anda!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final isActive = chatState.sessionId == session.id;

                      return Dismissible(
                        key: ValueKey(session.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.delete_outline, color: AppTheme.error),
                        ),
                        onDismissed: (_) async {
                          await ref.read(chatProvider.notifier).deleteSession(session.id);
                          ref.invalidate(allSessionsProvider);
                        },
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          selected: isActive,
                          selectedTileColor: AppTheme.primary.withValues(alpha: 0.12),
                          leading: Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: isActive ? AppTheme.primary : AppTheme.textSecondary,
                            size: 18,
                          ),
                          title: Text(
                            EmojiParser.replaceShortcodes(session.title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isActive ? AppTheme.primary : AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            _formatDate(session.updatedAt),
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          onTap: () async {
                            await ref.read(chatProvider.notifier).loadSession(session.id);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays}h lalu';
    return '${date.day}/${date.month}/${date.year}';
  }
}
