import 'dart:convert';
import 'chat_database.dart';

/// Helper for exporting and importing AURA user data (.aurabackup format)
/// According to Rule 06-backup-safety-cap.md:
/// Backs up SQLite tables (Sessions, Messages, Persona, Skills, MemorySnapshot, UserProfile)
/// Does NOT back up raw GGUF models.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  /// Current schema version — bump whenever SQLite schema changes.
  /// Checked on restore to catch incompatible backup files.
  static const int currentSchemaVersion = 2;

  // ─── Export ────────────────────────────────────────────────────────────────

  /// Export all user data as JSON String formatted for .aurabackup.
  /// Returns the JSON string on success.
  Future<String> exportBackupData() async {
    final db = await ChatDatabase.instance.database;

    final sessions = await db.query('sessions');
    final messages = await db.query('messages');
    final personas = await db.query('Persona');
    final skills = await db.query('Skills');
    final snapshots = await db.query('MemorySnapshot');
    final userProfiles = await db.query('UserProfile');

    final backupPayload = {
      'app': 'AURA',
      'schema_version': currentSchemaVersion,
      'exported_at': DateTime.now().millisecondsSinceEpoch,
      'data': {
        'sessions': sessions,
        'messages': messages,
        'Persona': personas,
        'Skills': skills,
        'MemorySnapshot': snapshots,
        'UserProfile': userProfiles,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(backupPayload);
  }

  // ─── Validate ──────────────────────────────────────────────────────────────

  /// Validate a backup JSON string without performing the restore.
  /// Returns [BackupValidationResult] with error message if invalid.
  BackupValidationResult validateBackup(String jsonString) {
    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonString);

      if (decoded['app'] != 'AURA') {
        return BackupValidationResult.invalid(
            'File ini bukan backup AURA yang valid.');
      }

      if (!decoded.containsKey('data')) {
        return BackupValidationResult.invalid('Format backup rusak: tidak ada bagian data.');
      }

      final fileVersion = decoded['schema_version'] as int? ?? 1;
      if (fileVersion > currentSchemaVersion) {
        return BackupValidationResult.invalid(
          'File backup ini dibuat oleh versi AURA yang lebih baru (skema v$fileVersion). '
          'Silakan update aplikasi terlebih dahulu.',
        );
      }

      // Count items for summary
      final data = decoded['data'] as Map<String, dynamic>;
      final sessionCount = (data['sessions'] as List?)?.length ?? 0;
      final messageCount = (data['messages'] as List?)?.length ?? 0;

      final exportedAt = decoded['exported_at'] as int?;
      final exportDate = exportedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(exportedAt)
          : null;

      return BackupValidationResult.valid(
        schemaVersion: fileVersion,
        sessionCount: sessionCount,
        messageCount: messageCount,
        exportedAt: exportDate,
      );
    } catch (e) {
      return BackupValidationResult.invalid('File tidak dapat dibaca: ${e.toString()}');
    }
  }

  // ─── Restore ───────────────────────────────────────────────────────────────

  /// Restore user data from JSON String (.aurabackup).
  /// REPLACES all current data — caller MUST show confirmation dialog first.
  /// Returns true on success, false on failure.
  Future<bool> restoreBackupData(String jsonString) async {
    // Validate first
    final validation = validateBackup(jsonString);
    if (!validation.isValid) return false;

    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      final data = decoded['data'] as Map<String, dynamic>;
      final db = await ChatDatabase.instance.database;

      await db.transaction((txn) async {
        // Clear current tables
        await txn.delete('messages');
        await txn.delete('sessions');
        await txn.delete('Persona');
        await txn.delete('Skills');
        await txn.delete('MemorySnapshot');
        await txn.delete('UserProfile');

        // Restore sessions
        if (data['sessions'] != null) {
          for (final row in data['sessions'] as List) {
            await txn.insert('sessions', Map<String, dynamic>.from(row as Map));
          }
        }

        // Restore messages
        if (data['messages'] != null) {
          for (final row in data['messages'] as List) {
            await txn.insert('messages', Map<String, dynamic>.from(row as Map));
          }
        }

        // Restore Persona
        if (data['Persona'] != null) {
          for (final row in data['Persona'] as List) {
            await txn.insert('Persona', Map<String, dynamic>.from(row as Map));
          }
        }

        // Restore Skills
        if (data['Skills'] != null) {
          for (final row in data['Skills'] as List) {
            await txn.insert('Skills', Map<String, dynamic>.from(row as Map));
          }
        }

        // Restore MemorySnapshot
        if (data['MemorySnapshot'] != null) {
          for (final row in data['MemorySnapshot'] as List) {
            await txn.insert('MemorySnapshot', Map<String, dynamic>.from(row as Map));
          }
        }

        // Restore UserProfile
        if (data['UserProfile'] != null) {
          for (final row in data['UserProfile'] as List) {
            await txn.insert('UserProfile', Map<String, dynamic>.from(row as Map));
          }
        }
      });

      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Result of backup file validation
class BackupValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int? schemaVersion;
  final int? sessionCount;
  final int? messageCount;
  final DateTime? exportedAt;

  const BackupValidationResult._({
    required this.isValid,
    this.errorMessage,
    this.schemaVersion,
    this.sessionCount,
    this.messageCount,
    this.exportedAt,
  });

  factory BackupValidationResult.valid({
    required int schemaVersion,
    required int sessionCount,
    required int messageCount,
    DateTime? exportedAt,
  }) =>
      BackupValidationResult._(
        isValid: true,
        schemaVersion: schemaVersion,
        sessionCount: sessionCount,
        messageCount: messageCount,
        exportedAt: exportedAt,
      );

  factory BackupValidationResult.invalid(String message) =>
      BackupValidationResult._(isValid: false, errorMessage: message);
}
