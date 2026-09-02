import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Controller to start and stop the local Python MT5 Bridge Service on Desktop (Windows).
class Mt5ServiceLauncher {
  static const String bridgeUrl = 'http://127.0.0.1:8088';
  static Process? _processHandle;

  /// Checks if the MT5 bridge service is currently running on http://127.0.0.1:8088.
  static Future<bool> isRunning() async {
    try {
      final response = await http
          .get(Uri.parse('$bridgeUrl/health'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Starts the MT5 service python process.
  static Future<bool> startService() async {
    if (await isRunning()) {
      debugPrint('[Mt5ServiceLauncher] Service is already running.');
      return true;
    }

    try {
      // Find script location
      final currentDir = Directory.current.path;
      final scriptCandidates = [
        '$currentDir/tools/mt5_bridge/mt5_service.py',
        '$currentDir/../tools/mt5_bridge/mt5_service.py',
        'c:/DevApp/AURA_MonoRepo/Project-A.U.R.A-Agent/tools/mt5_bridge/mt5_service.py',
      ];

      String? targetScript;
      for (final path in scriptCandidates) {
        if (File(path).existsSync()) {
          targetScript = path;
          break;
        }
      }

      if (targetScript == null) {
        debugPrint('[Mt5ServiceLauncher] Could not locate mt5_service.py script.');
        return false;
      }

      // Detect Python command ('python' or 'py')
      final pythonCmd = Platform.isWindows ? 'python' : 'python3';

      debugPrint('[Mt5ServiceLauncher] Launching MT5 bridge: $pythonCmd "$targetScript"');
      _processHandle = await Process.start(
        pythonCmd,
        [targetScript],
        environment: {
          'PYTHONIOENCODING': 'utf-8',
          'PYTHONUTF8': '1',
        },
        mode: ProcessStartMode.detachedWithStdio,
      );

      // Poll until online (up to 6 seconds)
      for (int i = 0; i < 12; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await isRunning()) {
          debugPrint('[Mt5ServiceLauncher] MT5 bridge service started successfully!');
          return true;
        }
      }

      return await isRunning();
    } catch (e) {
      debugPrint('[Mt5ServiceLauncher] Failed to start MT5 service: $e');
      return false;
    }
  }

  /// Stops the running MT5 bridge service via /shutdown HTTP request or process termination.
  static Future<bool> stopService() async {
    try {
      // Send shutdown request first
      await http
          .post(Uri.parse('$bridgeUrl/shutdown'))
          .timeout(const Duration(seconds: 2))
          .catchError((_) => http.Response('', 500));
    } catch (_) {}

    if (_processHandle != null) {
      _processHandle!.kill();
      _processHandle = null;
    }

    // Windows fallback kill if needed
    if (Platform.isWindows) {
      try {
        await Process.run('cmd', [
          '/c',
          'for /f "tokens=5" %a in (\'netstat -aon ^| findstr :8088 ^| findstr LISTENING\') do taskkill /F /PID %a'
        ]);
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 500));
    return !(await isRunning());
  }
}
