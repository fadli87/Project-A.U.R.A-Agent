import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'src/memory/objectbox_store.dart';
import 'src/memory/embedding_service.dart';
import 'src/ui/screens/chat_screen.dart';
import 'src/ui/screens/model_manager_screen.dart';
import 'src/ui/theme/app_theme.dart';
import 'src/agent/alarm_service.dart';
import 'src/providers/chat_provider.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Android requirement: periodic task minimum is 15 minutes.
    // For daily maintenance, we run this task to do light cleanup or logging.
    // To save battery, we avoid starting heavy LLM inference in background.
    debugPrint("AURA Background periodic task executed: $task");
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait for better mobile AI assistant experience
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configure system UI overlay style for dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize ObjectBox persistent memory store
  await ObjectBoxStore.open();

  // Pre-warm the embedding service (loads TFLite interpreter)
  EmbeddingService.instance.init().ignore();

  // Initialize Workmanager
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: kDebugMode,
  );

  // Register daily periodic task
  await Workmanager().registerPeriodicTask(
    "aura-daily-maintenance",
    "dailyMaintenance",
    frequency: const Duration(hours: 24),
    constraints: Constraints(
      networkType: NetworkType.not_required,
      requiresBatteryNotLow: true,
      requiresDeviceIdle: true,
    ),
  );

  runApp(
    // ProviderScope is the Riverpod root — all providers are scoped here
    const ProviderScope(child: AuraApp()),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AuraApp extends ConsumerStatefulWidget {
  const AuraApp({super.key});

  @override
  ConsumerState<AuraApp> createState() => _AuraAppState();
}

class _AuraAppState extends ConsumerState<AuraApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize alarm listener for notification clicks
      AlarmService.instance.onNotificationTap = (sessionId) async {
        await ref.read(chatProvider.notifier).loadSession(sessionId);
        navigatorKey.currentState?.pushNamed('/chat');
      };

      // Check if launched by notification click
      final launchSessionId = await AlarmService.instance.getLaunchSessionId();
      if (launchSessionId != null) {
        await ref.read(chatProvider.notifier).loadSession(launchSessionId);
        navigatorKey.currentState?.pushNamed('/chat');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AURA',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: '/',
      routes: {
        '/': (context) => const ModelManagerScreen(),
        '/chat': (context) => const ChatScreen(),
      },
    );
  }
}
