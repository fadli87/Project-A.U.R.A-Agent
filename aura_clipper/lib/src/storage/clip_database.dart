import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;
import '../models/video_job.dart';
import '../models/clip_candidate.dart';

class ClipDatabase {
  final Database _db;

  ClipDatabase(this._db);

  /// Membuka database di path file SQLite tertentu dan menjalankan migrasi skema.
  static Future<ClipDatabase> init(String dbDir) async {
    final dbPath = p.join(dbDir, 'clipper.db');
    final db = sqlite3.open(dbPath);
    return _create(db);
  }

  /// Membuka database in-memory untuk keperluan testing.
  static ClipDatabase inMemory() {
    final db = sqlite3.openInMemory();
    return _create(db);
  }

  static ClipDatabase _create(Database db) {
    // Wajib aktifkan foreign keys di setiap koneksi SQLite
    db.execute('PRAGMA foreign_keys = ON;');

    final currentVersion = db.userVersion;
    if (currentVersion < 1) {
      db.execute('''
        CREATE TABLE IF NOT EXISTS video_jobs (
          id TEXT PRIMARY KEY,
          url TEXT NOT NULL,
          status TEXT NOT NULL,
          progress REAL DEFAULT 0.0,
          title TEXT,
          duration_seconds INTEGER,
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

      db.userVersion = 1;
    }

    return ClipDatabase(db);
  }

  /// Menyimpan atau memperbarui data VideoJob.
  void saveJob(VideoJob job) {
    final stmt = _db.prepare('''
      INSERT INTO video_jobs (
        id, url, status, progress, title, duration_seconds,
        local_video_path, transcript_path, error_message, created_at, updated_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        status = excluded.status,
        progress = excluded.progress,
        title = excluded.title,
        duration_seconds = excluded.duration_seconds,
        local_video_path = excluded.local_video_path,
        transcript_path = excluded.transcript_path,
        error_message = excluded.error_message,
        updated_at = excluded.updated_at
    ''');

    try {
      stmt.execute([
        job.id,
        job.url,
        job.status.name,
        job.progress,
        job.title,
        job.durationSeconds,
        job.localVideoPath,
        job.transcriptPath,
        job.errorMessage,
        job.createdAt.millisecondsSinceEpoch,
        job.updatedAt?.millisecondsSinceEpoch,
      ]);
    } finally {
      stmt.dispose();
    }
  }

  /// Menghapus job berdasarkan id (cascade delete akan menghapus kandidat terkait).
  void deleteJob(String jobId) {
    final stmt = _db.prepare('DELETE FROM video_jobs WHERE id = ?');
    try {
      stmt.execute([jobId]);
    } finally {
      stmt.dispose();
    }
  }

  /// Mengambil VideoJob berdasarkan id.
  VideoJob? getJob(String jobId) {
    final ResultSet rs = _db.select('SELECT * FROM video_jobs WHERE id = ?', [jobId]);
    if (rs.isEmpty) return null;
    return _rowToJob(rs.first);
  }

  /// Mengambil semua VideoJob diurutkan dari yang terbaru.
  List<VideoJob> getJobs() {
    final ResultSet rs = _db.select('SELECT * FROM video_jobs ORDER BY created_at DESC');
    return rs.map(_rowToJob).toList();
  }

  VideoJob _rowToJob(Row row) {
    final statusStr = row['status'] as String? ?? '';
    final status = VideoJobStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => VideoJobStatus.pending,
    );

    return VideoJob(
      id: row['id'] as String,
      url: row['url'] as String,
      status: status,
      progress: (row['progress'] as num?)?.toDouble() ?? 0.0,
      title: row['title'] as String?,
      durationSeconds: row['duration_seconds'] as int?,
      localVideoPath: row['local_video_path'] as String?,
      transcriptPath: row['transcript_path'] as String?,
      errorMessage: row['error_message'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: row['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int)
          : null,
    );
  }

  /// Menyimpan daftar kandidat klip ke dalam transaksi atomik.
  void saveCandidates(String jobId, List<ClipCandidate> candidates) {
    _db.execute('BEGIN TRANSACTION;');
    try {
      _db.execute('DELETE FROM clip_candidates WHERE job_id = ?', [jobId]);

      final stmt = _db.prepare('''
        INSERT INTO clip_candidates (job_id, title, start_seconds, end_seconds, score, reason, is_selected)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''');

      try {
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
      } finally {
        stmt.dispose();
      }

      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Mengambil kandidat klip untuk suatu job diurutkan berdasarkan skor tertinggi.
  List<ClipCandidate> getCandidates(String jobId) {
    final ResultSet rs = _db.select(
      'SELECT * FROM clip_candidates WHERE job_id = ? ORDER BY score DESC',
      [jobId],
    );

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

  /// Menghapus semua riwayat job dan seluruh kandidatnya.
  void clearAllJobs() {
    _db.execute('DELETE FROM video_jobs;');
  }

  /// Menutup koneksi database.
  void dispose() {
    _db.dispose();
  }
}
