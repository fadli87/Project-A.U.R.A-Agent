import 'package:flutter/material.dart';
import '../models/clip_candidate.dart';

class ExportPanel extends StatelessWidget {
  final ClipCandidate candidate;
  final VoidCallback onExport;

  const ExportPanel({
    super.key,
    required this.candidate,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export Clip: ${candidate.title}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Duration: ${(candidate.endTime - candidate.startTime).inSeconds} seconds'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onExport,
              child: const Text('Export Now'),
            ),
          ],
        ),
      ),
    );
  }
}
