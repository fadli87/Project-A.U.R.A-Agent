import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'package:aura_core/aura_core.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'src/services/mobile_platform_service.dart';
import 'src/services/mobile_secure_storage.dart';
import 'src/ui/screens/chat_screen.dart';
import 'src/ui/screens/model_manager_screen.dart';
import 'src/ui/theme/app_theme.dart';
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
  SecureStorageService.instance = MobileSecureStorage();

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

  // Register mobile platform service delegate
  AlarmService.instance.registerDelegate(MobilePlatformService.instance);

  // Initialize SQLite database
  final dbDir = await getDatabasesPath();
  ChatDatabase.init(path_lib.join(dbDir, 'aura_chat.db'));

  // Initialize ObjectBox persistent memory store
  final docsDir = await getApplicationDocumentsDirectory();
  await ObjectBoxStore.open(directoryPath: docsDir.path);

  // Pre-warm the embedding service (loads TFLite interpreter and tokenizer)
  Future<void> initEmbeddingService() async {
    try {
      final modelBytes = await rootBundle.load('assets/models/minilm_l6_v2.tflite');
      final tokenizerJson = await rootBundle.loadString('assets/models/minilm_tokenizer.json');
      await EmbeddingService.instance.init(
        modelBytes: modelBytes.buffer.asUint8List(),
        tokenizerJson: tokenizerJson,
      );
    } catch (e) {
      debugPrint('Failed to initialize embedding service: $e');
    }
  }
  initEmbeddingService().ignore();

  // Initialize Workmanager
  await Workmanager().initialize(
    callbackDispatcher,
  );

  // Register daily periodic task
  await Workmanager().registerPeriodicTask(
    "aura-daily-maintenance",
    "dailyMaintenance",
    frequency: const Duration(hours: 24),
    constraints: Constraints(
      networkType: NetworkType.notRequired,
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
      MobilePlatformService.instance.onNotificationTap = (sessionId) async {
        await ref.read(chatProvider.notifier).loadSession(sessionId);
        navigatorKey.currentState?.pushNamed('/chat');
      };

      // Check if launched by notification click
      final launchSessionId = await MobilePlatformService.instance.getLaunchSessionId();
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
