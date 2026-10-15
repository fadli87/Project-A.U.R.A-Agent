import 'package:flutter_test/flutter_test.dart';
import 'package:aura_clipper/aura_clipper_desktop.dart';
import 'package:aura_clipper/aura_clipper_ui.dart';

void main() {
  test('AURA Clipper barrel exports exist and instantiate properly', () {
    // Model
    final job = VideoJob(
      id: 'job_test',
      url: 'https://youtube.com',
      createdAt: DateTime.now(),
    );
    expect(job.status, VideoJobStatus.pending);
    expect(job.progress, 0.0);

    final clip = ClipCandidate(
      title: 'Clip',
      startTime: Duration.zero,
      endTime: const Duration(seconds: 30),
      score: 80,
      reason: 'Hook',
    );
    expect(clip.score, 80);

    // Settings
    const settings = ClipperSettings();
    expect(settings.ytDlpPath, 'yt-dlp');

    // UI Stubs
    const screen = ClipperScreen();
    expect(screen, isNotNull);

    // Desktop
    final downloader = YtDlpDownloader(ytDlpPath: 'yt-dlp');
    expect(downloader.allowedHosts, contains('youtube.com'));
  });
}
