enum VideoJobStatus {
  pending,
  downloading,
  transcribing,
  analyzing,
  done,
  error,
}

class VideoJob {
  final String id;
  final String url;
  final VideoJobStatus status;
  final double progress;
  final String? title;
  final int? durationSeconds;
  final String? localVideoPath;
  final String? transcriptPath;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? updatedAt;

  VideoJob({
    required this.id,
    required this.url,
    this.status = VideoJobStatus.pending,
    this.progress = 0.0,
    this.title,
    this.durationSeconds,
    this.localVideoPath,
    this.transcriptPath,
    this.errorMessage,
    required this.createdAt,
    this.updatedAt,
  });

  VideoJob copyWith({
    String? id,
    String? url,
    VideoJobStatus? status,
    double? progress,
    String? title,
    int? durationSeconds,
    String? localVideoPath,
    String? transcriptPath,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VideoJob(
      id: id ?? this.id,
      url: url ?? this.url,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      title: title ?? this.title,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      localVideoPath: localVideoPath ?? this.localVideoPath,
      transcriptPath: transcriptPath ?? this.transcriptPath,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
