/// Platform-agnostic interface for system/alarm operations.
abstract class PlatformService {
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String content,
    required DateTime time,
    required int sessionId,
  });

  Future<void> cancelReminder(int id);
  Future<void> searchWeb(String query);
}

/// Service that delegates system operations (alarms, notifications, browser searches)
/// to a platform-specific implementation.
class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  PlatformService? _delegate;

  /// Register the platform-specific implementation of [PlatformService].
  void registerDelegate(PlatformService delegate) {
    _delegate = delegate;
  }

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String content,
    required DateTime time,
    required int sessionId,
  }) async {
    await _delegate?.scheduleReminder(
      id: id,
      title: title,
      content: content,
      time: time,
      sessionId: sessionId,
    );
  }

  Future<void> cancelReminder(int id) async {
    await _delegate?.cancelReminder(id);
  }

  Future<void> searchWeb(String query) async {
    await _delegate?.searchWeb(query);
  }
}
