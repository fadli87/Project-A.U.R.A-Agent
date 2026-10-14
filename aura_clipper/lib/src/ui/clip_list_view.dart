import 'package:flutter/material.dart';
import '../models/clip_candidate.dart';

class ClipListView extends StatelessWidget {
  final List<ClipCandidate> candidates;
  final Function(ClipCandidate) onSelect;

  const ClipListView({
    super.key,
    required this.candidates,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: candidates.length,
      itemBuilder: (context, index) {
        final c = candidates[index];
        return ListTile(
          title: Text(c.title),
          subtitle: Text('Score: ${c.score} | Reason: ${c.reason}'),
          trailing: Text('${c.startTime.inSeconds}s - ${c.endTime.inSeconds}s'),
          onTap: () => onSelect(c),
        );
      },
    );
  }
}
