import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:aura_core/aura_core.dart';

class DesktopPlatformService implements PlatformService {
  DesktopPlatformService._();
  static final DesktopPlatformService instance = DesktopPlatformService._();

  @override
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String content,
    required DateTime time,
    required int sessionId,
  }) async {
    debugPrint('Desktop Alarm Scheduled: $title at $time');
  }

  @override
  Future<void> cancelReminder(int id) async {
    debugPrint('Desktop Alarm Cancelled: $id');
  }

  @override
  Future<void> searchWeb(String query) async {
    final encoded = Uri.encodeComponent(query);
    final url = 'https://www.google.com/search?q=$encoded';
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', url]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    }
  }
}
