import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AlarmService {
  AlarmService._() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static final AlarmService instance = AlarmService._();

  static const MethodChannel _channel = MethodChannel('com.aura.aura/system');

  /// Callback to execute when a notification is tapped
  Function(int)? onNotificationTap;

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String content,
    required DateTime time,
    required int sessionId,
  }) async {
    try {
      await _channel.invokeMethod('scheduleAlarm', {
        'id': id,
        'title': title,
        'content': content,
        'timeInMillis': time.millisecondsSinceEpoch,
        'sessionId': sessionId,
      });
    } on PlatformException catch (e) {
      debugPrint('Failed to schedule alarm: ${e.message}');
    }
  }

  Future<void> cancelReminder(int id) async {
    try {
      await _channel.invokeMethod('cancelAlarm', {
        'id': id,
      });
    } on PlatformException catch (e) {
      debugPrint('Failed to cancel alarm: ${e.message}');
    }
  }

  Future<int?> getLaunchSessionId() async {
    try {
      final int? sessionId = await _channel.invokeMethod('getLaunchSessionId');
      return sessionId;
    } on PlatformException catch (e) {
      debugPrint('Failed to get launch session ID: ${e.message}');
      return null;
    }
  }

  Future<void> searchWeb(String query) async {
    try {
      await _channel.invokeMethod('searchWeb', {
        'query': query,
      });
    } on PlatformException catch (e) {
      debugPrint('Failed to open web search: ${e.message}');
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationTap':
        final sessionId = call.arguments as int?;
        if (sessionId != null && onNotificationTap != null) {
          onNotificationTap!(sessionId);
        }
        break;
      default:
        debugPrint('Method not implemented in AlarmService: ${call.method}');
    }
  }
}
