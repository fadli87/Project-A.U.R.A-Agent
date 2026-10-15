import 'package:flutter_test/flutter_test.dart';
import 'package:aura_clipper/aura_clipper.dart';

void main() {
  group('ClipDatabase (inMemory)', () {
    late ClipDatabase db;

    setUp(() {
      db = ClipDatabase.inMemory();
    });

    tearDown(() {
      db.dispose();
    });

    test('round-trip saveJob and getJob', () {
      final now = DateTime.now();
      final job = VideoJob(
        id: 'job_123',
        url: 'https://www.youtube.com/watch?v=abcdefghijk',
        status: VideoJobStatus.downloading,
        progress: 0.25,
        title: 'Test Video',
        durationSeconds: 120,
        createdAt: now,
      );

      db.saveJob(job);

      final fetched = db.getJob('job_123');
      expect(fetched, isNotNull);
      expect(fetched!.id, 'job_123');
      expect(fetched.url, 'https://www.youtube.com/watch?v=abcdefghijk');
      expect(fetched.status, VideoJobStatus.downloading);
      expect(fetched.progress, 0.25);
      expect(fetched.title, 'Test Video');
      expect(fetched.durationSeconds, 120);
    });

    test('round-trip saveJob with VideoJobStatus.cancelled', () {
      final now = DateTime.now();
      final job = VideoJob(
        id: 'job_cancelled_1',
        url: 'https://youtube.com/watch?v=cancel',
        status: VideoJobStatus.cancelled,
        progress: 0.45,
        errorMessage: 'Dibatalkan oleh user',
        createdAt: now,
      );

      db.saveJob(job);
      final fetched = db.getJob('job_cancelled_1');
      expect(fetched, isNotNull);
      expect(fetched!.status, VideoJobStatus.cancelled);
      expect(fetched.errorMessage, 'Dibatalkan oleh user');
    });

    test('safe fallback for unknown status string', () {
      final now = DateTime.now();
      final job = VideoJob(
        id: 'job_corrupted',
        url: 'https://youtube.com/watch?v=xyz',
        createdAt: now,
      );
      db.saveJob(job);

      final list = db.getJobs();
      expect(list.any((j) => j.id == 'job_corrupted'), isTrue);
    });

    test('saveCandidates and getCandidates ordered by score', () {
      final now = DateTime.now();
      final job = VideoJob(id: 'job_candidates', url: 'https://youtube.com', createdAt: now);
      db.saveJob(job);

      final candidates = [
        ClipCandidate(
          title: 'Low Score Clip',
          startTime: const Duration(seconds: 10),
          endTime: const Duration(seconds: 40),
          score: 50,
          reason: 'Fairly interesting',
        ),
        ClipCandidate(
          title: 'Viral Clip',
          startTime: const Duration(seconds: 60),
          endTime: const Duration(seconds: 90),
          score: 95,
          reason: 'High energy hook',
          isSelected: true,
        ),
      ];

      db.saveCandidates('job_candidates', candidates);

      final fetched = db.getCandidates('job_candidates');
      expect(fetched.length, 2);
      expect(fetched.first.title, 'Viral Clip'); // Order by score DESC
      expect(fetched.first.score, 95);
      expect(fetched.first.isSelected, isTrue);
      expect(fetched.last.score, 50);
    });

    test('foreign key cascade delete removes candidates when job is deleted', () {
      final now = DateTime.now();
      final job = VideoJob(id: 'job_to_delete', url: 'https://youtube.com', createdAt: now);
      db.saveJob(job);

      db.saveCandidates('job_to_delete', [
        ClipCandidate(
          title: 'Clip 1',
          startTime: const Duration(seconds: 5),
          endTime: const Duration(seconds: 25),
          score: 80,
          reason: 'Good moment',
        ),
      ]);

      expect(db.getCandidates('job_to_delete').length, 1);

      // Hapus job
      db.deleteJob('job_to_delete');

      expect(db.getJob('job_to_delete'), isNull);
      // Kandidat harus otomatis terhapus karena ON DELETE CASCADE
      expect(db.getCandidates('job_to_delete'), isEmpty);
    });
  });
}
