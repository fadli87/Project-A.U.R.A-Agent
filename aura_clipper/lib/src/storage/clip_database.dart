import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as path;
import '../models/video_job.dart';
import '../models/clip_candidate.dart';

class ClipDatabase {
  final Database _db;

  ClipDatabase(this._db);

  static Future<ClipDatabase> init(String dbDir) async {
    final dbPath = path.join(dbDir, 'clipper.db');
    final db = sqlite3.open(dbPath);

    db.execute('''
      CREATE TABLE IF NOT EXISTS video_jobs (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        status TEXT NOT NULL,
        local_video_path TEXT,
        transcript_path TEXT,
        error_message TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS clip_candidates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        job_id TEXT NOT NULL,
        title TEXT NOT NULL,
        start_seconds INTEGER NOT NULL,
        end_seconds INTEGER NOT NULL,
        score INTEGER NOT NULL,
        reason TEXT NOT NULL,
        is_selected INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (job_id) REFERENCES video_jobs (id) ON DELETE CASCADE
      )
    ''');

    return ClipDatabase(db);
  }

  void saveJob(VideoJob job) {
    final stmt = _db.prepare('''
      INSERT INTO video_jobs (id, url, status, local_video_path, transcript_path, error_message, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        status = excluded.status,
        local_video_path = excluded.local_video_path,
        transcript_path = excluded.transcript_path,
        error_message = excluded.error_message,
        updated_at = excluded.updated_at
    ''');
    
    stmt.execute([
      job.id,
      job.url,
      job.status.name,
      job.localVideoPath,
      job.transcriptPath,
      job.errorMessage,
      job.createdAt.millisecondsSinceEpoch,
      job.updatedAt?.millisecondsSinceEpoch,
    ]);
    stmt.dispose();
  }

  List<VideoJob> getJobs() {
    final ResultSet rs = _db.select('SELECT * FROM video_jobs ORDER BY created_at DESC');
    return rs.map((row) {
      return VideoJob(
        id: row['id'] as String,
        url: row['url'] as String,
        status: VideoJobStatus.values.firstWhere((e) => e.name == row['status'] as String),
        localVideoPath: row['local_video_path'] as String?,
        transcriptPath: row['transcript_path'] as String?,
        errorMessage: row['error_message'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        updatedAt: row['updated_at'] != null ? DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int) : null,
      );
    }).toList();
  }

  void saveCandidates(String jobId, List<ClipCandidate> candidates) {
    _db.execute('DELETE FROM clip_candidates WHERE job_id = ?', [jobId]);
    
    final stmt = _db.prepare('''
      INSERT INTO clip_candidates (job_id, title, start_seconds, end_seconds, score, reason, is_selected)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''');
    
    for (final c in candidates) {
      stmt.execute([
        jobId,
        c.title,
        c.startTime.inSeconds,
        c.endTime.inSeconds,
        c.score,
        c.reason,
        c.isSelected ? 1 : 0,
      ]);
    }
    stmt.dispose();
  }

  List<ClipCandidate> getCandidates(String jobId) {
    final ResultSet rs = _db.select('SELECT * FROM clip_candidates WHERE job_id = ? ORDER BY score DESC', [jobId]);
    return rs.map((row) {
      return ClipCandidate(
        title: row['title'] as String,
        startTime: Duration(seconds: row['start_seconds'] as int),
        endTime: Duration(seconds: row['end_seconds'] as int),
        score: row['score'] as int,
        reason: row['reason'] as String,
        isSelected: (row['is_selected'] as int) == 1,
      );
    }).toList();
  }
}
