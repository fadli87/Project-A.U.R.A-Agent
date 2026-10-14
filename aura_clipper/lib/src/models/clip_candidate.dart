class ClipCandidate {
  final String title;
  final Duration startTime;
  final Duration endTime;
  final int score;
  final String reason;
  final bool isSelected;

  ClipCandidate({
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.score,
    required this.reason,
    this.isSelected = false,
  });

  ClipCandidate copyWith({
    String? title,
    Duration? startTime,
    Duration? endTime,
    int? score,
    String? reason,
    bool? isSelected,
  }) {
    return ClipCandidate(
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      score: score ?? this.score,
      reason: reason ?? this.reason,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
