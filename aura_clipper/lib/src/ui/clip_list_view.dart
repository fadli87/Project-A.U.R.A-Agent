import 'package:flutter/material.dart';
import '../models/clip_candidate.dart';

/// Tampilan daftar kandidat momen terbaik yang diurutkan berdasarkan skor viralitas.
class ClipListView extends StatelessWidget {
  final List<ClipCandidate> candidates;
  final ClipCandidate? selectedCandidate;
  final Set<String> checkedTitles;
  final ValueChanged<ClipCandidate> onSelect;
  final ValueChanged<ClipCandidate> onToggleCheck;
  final ValueChanged<bool> onToggleAll;

  const ClipListView({
    super.key,
    required this.candidates,
    this.selectedCandidate,
    required this.checkedTitles,
    required this.onSelect,
    required this.onToggleCheck,
    required this.onToggleAll,
  });

  Color _getScoreColor(int score) {
    if (score >= 90) return const Color(0xFF00E676);
    if (score >= 80) return const Color(0xFF00BFA5);
    if (score >= 70) return const Color(0xFFFFB300);
    return Colors.grey;
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.movie_creation_outlined, size: 48, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(height: 12),
              const Text(
                'Belum ada kandidat klip.',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'Masukkan link video YouTube di sebelah kiri dan klik "Mulai Analisis".',
                style: TextStyle(color: Colors.white30, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final allSelected = checkedTitles.length == candidates.length && candidates.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // List header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F2C),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Checkbox(
                value: allSelected,
                onChanged: (v) => onToggleAll(v ?? false),
                activeColor: const Color(0xFF7C4DFF),
              ),
              Text(
                'Kandidat Klip (${candidates.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
              const Spacer(),
              Text(
                '${checkedTitles.length} dipilih untuk ekspor',
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
        ),

        // Items list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: candidates.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final c = candidates[index];
              final isSelected = selectedCandidate?.title == c.title &&
                  selectedCandidate?.startTime == c.startTime;
              final isChecked = checkedTitles.contains(c.title);
              final scoreColor = _getScoreColor(c.score);
              final duration = c.endTime - c.startTime;

              return InkWell(
                onTap: () => onSelect(c),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF28283C) : const Color(0xFF1A1A24),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF7C4DFF) : Colors.white.withValues(alpha: 0.05),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Checkbox for export
                      Checkbox(
                        value: isChecked,
                        onChanged: (_) => onToggleCheck(c),
                        activeColor: const Color(0xFF7C4DFF),
                      ),

                      // Rank & Score badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: scoreColor.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${c.score}',
                              style: TextStyle(
                                color: scoreColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const Text(
                              'SKOR',
                              style: TextStyle(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Clip metadata
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_formatDuration(c.startTime)} - ${_formatDuration(c.endTime)} (${duration.inSeconds}s)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (c.reason.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                c.reason,
                                style: const TextStyle(fontSize: 12, color: Colors.white60, height: 1.3),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Preview button indicator
                      IconButton(
                        icon: Icon(
                          isSelected ? Icons.play_circle_fill : Icons.play_circle_outline,
                          color: isSelected ? const Color(0xFF7C4DFF) : Colors.white38,
                          size: 26,
                        ),
                        onPressed: () => onSelect(c),
                        tooltip: 'Pratinjau Klip Ini',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
