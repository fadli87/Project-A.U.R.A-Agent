import 'package:flutter_test/flutter_test.dart';
import 'package:aura_clipper/aura_clipper_desktop.dart';

void main() {
  group('Pure Argument Builders & Parsers', () {
    test('YtDlpDownloader url validation & args', () {
      const allowed = ['youtube.com', 'youtu.be'];

      expect(YtDlpDownloader.isValidUrl('https://www.youtube.com/watch?v=123', allowed), isTrue);
      expect(YtDlpDownloader.isValidUrl('https://youtu.be/123', allowed), isTrue);
      expect(YtDlpDownloader.isValidUrl('http://youtube.com/video', allowed), isTrue);
      expect(YtDlpDownloader.isValidUrl('https://evil.com/video', allowed), isFalse);
      expect(YtDlpDownloader.isValidUrl('file:///etc/passwd', allowed), isFalse);
      expect(YtDlpDownloader.isValidUrl('not-a-url', allowed), isFalse);

      final dumpArgs = YtDlpDownloader.buildDumpJsonArgs(url: 'https://youtu.be/123');
      expect(dumpArgs, contains('--dump-json'));
      expect(dumpArgs, contains('--no-playlist'));
      expect(dumpArgs, contains('--'));
      // Wajib ada -- sebelum URL untuk mencegah flag injection
      expect(dumpArgs.indexOf('--'), dumpArgs.indexOf('https://youtu.be/123') - 1);

      final dlArgs = YtDlpDownloader.buildDownloadArgs(
        url: 'https://youtu.be/123',
        outputTemplate: '/jobs/1/%(id)s.%(ext)s',
      );
      expect(dlArgs, contains('-o'));
      expect(dlArgs, contains('/jobs/1/%(id)s.%(ext)s'));
      expect(dlArgs, contains('--'));
      expect(dlArgs.indexOf('--'), dlArgs.indexOf('https://youtu.be/123') - 1);
    });

    test('YtDlpDownloader parseProgress handles typical stdout lines', () {
      expect(YtDlpDownloader.parseProgress('[download]  12.5% of 10.00MiB at 2.00MiB/s'), closeTo(0.125, 0.001));
      expect(YtDlpDownloader.parseProgress('[download] 100.0% of 10.00MiB at 2.00MiB/s'), closeTo(1.0, 0.001));
      expect(YtDlpDownloader.parseProgress('[download] Destination: video.mp4'), isNull);
      expect(YtDlpDownloader.parseProgress('Random log line'), isNull);
    });

    test('WhisperCppTranscriber arg builder', () {
      final ffmpegArgs = WhisperCppTranscriber.buildFfmpegExtractArgs(
        videoPath: '/path/video.mp4',
        wavPath: '/path/video.wav',
      );
      expect(ffmpegArgs, contains('-ar'));
      expect(ffmpegArgs, contains('16000'));
      expect(ffmpegArgs, contains('-ac'));
      expect(ffmpegArgs, contains('1'));
      expect(ffmpegArgs.last, '/path/video.wav');

      final whisperArgs = WhisperCppTranscriber.buildWhisperArgs(
        modelPath: '/models/ggml-base.bin',
        wavPath: '/path/video.wav',
        outputPrefix: '/path/video',
        language: 'id',
      );
      expect(whisperArgs, contains('-m'));
      expect(whisperArgs, contains('/models/ggml-base.bin'));
      expect(whisperArgs, contains('-l'));
      expect(whisperArgs, contains('id'));
      expect(whisperArgs, contains('--output-json'));
    });

    test('FfmpegExporter arg builder and safe filename', () {
      final exportArgs = FfmpegExporter.buildExportArgs(
        sourceVideoPath: '/path/video.mp4',
        startTime: const Duration(seconds: 15),
        endTime: const Duration(seconds: 45),
        outputPath: '/path/out.mp4',
      );

      expect(exportArgs, contains('-c:v'));
      expect(exportArgs, contains('libx264'));
      expect(exportArgs, contains('-movflags'));
      expect(exportArgs, contains('+faststart'));
      expect(exportArgs, contains('-ss'));
      expect(exportArgs, contains('15.00'));
      expect(exportArgs, contains('-to'));
      expect(exportArgs, contains('45.00'));

      final name = FfmpegExporter.buildOutputFileName(
        baseName: 'My Awesome Video! [1080p]',
        startTime: const Duration(minutes: 1, seconds: 5),
        endTime: const Duration(minutes: 1, seconds: 35),
      );
      expect(name, 'My_Awesome_Video___1080p__1m05s-1m35s.mp4');
    });
  });
}
