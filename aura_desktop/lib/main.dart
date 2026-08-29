import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_lib;
import 'package:aura_core/aura_core.dart';
import 'package:file_picker/file_picker.dart';
import 'src/providers/desktop_chat_provider.dart';
import 'src/providers/desktop_knowledge_provider.dart';
import 'src/providers/desktop_trusted_folders_provider.dart';
import 'src/services/desktop_platform_service.dart';
import 'src/services/desktop_secure_storage.dart';
import 'src/ui/desktop_trading_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SecureStorageService.instance = DesktopSecureStorage();
  
  // Register Desktop Platform Service delegate for AlarmService
  AlarmService.instance.registerDelegate(DesktopPlatformService.instance);

  // Initialize SQLite database
  final docsDir = await getApplicationDocumentsDirectory();
  ChatDatabase.init(path_lib.join(docsDir.path, 'aura_chat_desktop.db'));

  // Initialize ObjectBox store
  await ObjectBoxStore.open(directoryPath: docsDir.path);

  // Initialize EmbeddingService (Minilm for vector memory)
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

  runApp(
    const ProviderScope(child: AuraDesktopApp()),
  );
}

class AuraDesktopApp extends StatelessWidget {
  const AuraDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AURA — Offline Personal AI (Desktop)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF13131A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C4DFF),
          secondary: Color(0xFF00BFA5),
          surface: Color(0xFF1C1B22),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1C1B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
      ),
      home: const DesktopChatScreen(),
    );
  }
}

class DesktopChatScreen extends ConsumerStatefulWidget {
  const DesktopChatScreen({super.key});

  @override
  ConsumerState<DesktopChatScreen> createState() => _DesktopChatScreenState();
}

class _DesktopChatScreenState extends ConsumerState<DesktopChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool useCloudAssistant = false;
  int _activeNavIndex = 0; // 0: AI Assistant Chat, 1: Trading Lab


  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSettingsDialog(BuildContext context, DesktopChatState state, DesktopChatNotifier notifier) {
    final urlController = TextEditingController(text: state.baseUrl);
    final modelController = TextEditingController(text: state.activeModel);
    final serverPathController = TextEditingController(text: state.llamaServerPath);
    final modelPathController = TextEditingController(text: state.ggufModelPath);
    String selectedApiType = state.apiType;
    String selectedModel = state.activeModel;
    bool dialogUseInAppServer = state.useInAppServer;
    bool dialogIsInAppServerRunning = state.isInAppServerRunning;
    bool isTesting = false;
    String testResult = '';

    // Cloud settings variables
    final geminiKeyController = TextEditingController();
    final openaiKeyController = TextEditingController();
    bool obscureGeminiKey = true;
    bool obscureOpenaiKey = true;
    String? geminiValidationResult;
    String? openaiValidationResult;
    bool isValidatingGemini = false;
    bool isValidatingOpenai = false;
    String activeCloudProvider = 'gemini';
    String openaiModel = 'gpt-4o-mini';
    bool keysLoaded = false;

    void loadCloudSettings(void Function(void Function()) setDialogState) async {
      final geminiKey = await SecureStorageService.instance.read('gemini_api_key') ?? '';
      final openaiKey = await SecureStorageService.instance.read('openai_api_key') ?? '';
      final provider = await SecureStorageService.instance.read('active_cloud_provider') ?? 'gemini';
      final model = await SecureStorageService.instance.read('openai_model') ?? 'gpt-4o-mini';
      setDialogState(() {
        geminiKeyController.text = geminiKey;
        openaiKeyController.text = openaiKey;
        activeCloudProvider = provider;
        openaiModel = model;
        keysLoaded = true;
      });
    }

    void validateGeminiKey(void Function(void Function()) setDialogState) async {
      final key = geminiKeyController.text.trim();
      if (key.isEmpty) {
        setDialogState(() => geminiValidationResult = 'Kunci API kosong');
        return;
      }
      setDialogState(() {
        isValidatingGemini = true;
        geminiValidationResult = null;
      });
      final engine = GeminiInferenceEngine();
      final isValid = await engine.validateKey(key);
      // Write to secure storage regardless of validation success so it is saved
      await SecureStorageService.instance.write('gemini_api_key', key);
      setDialogState(() {
        isValidatingGemini = false;
        if (isValid) {
          geminiValidationResult = 'Valid';
        } else {
          geminiValidationResult = 'Tidak Valid';
        }
      });
    }

    void validateOpenaiKey(void Function(void Function()) setDialogState) async {
      final key = openaiKeyController.text.trim();
      if (key.isEmpty) {
        setDialogState(() => openaiValidationResult = 'Kunci API kosong');
        return;
      }
      setDialogState(() {
        isValidatingOpenai = true;
        openaiValidationResult = null;
      });
      final engine = OpenAIInferenceEngine();
      final isValid = await engine.validateKey(key);
      // Write to secure storage regardless of validation success so it is saved
      await SecureStorageService.instance.write('openai_api_key', key);
      setDialogState(() {
        isValidatingOpenai = false;
        if (isValid) {
          openaiValidationResult = 'Valid';
        } else {
          openaiValidationResult = 'Tidak Valid';
        }
      });
    }

    void deleteGeminiKey(void Function(void Function()) setDialogState) async {
      await SecureStorageService.instance.delete('gemini_api_key');
      setDialogState(() {
        geminiKeyController.clear();
        geminiValidationResult = null;
      });
    }

    void deleteOpenaiKey(void Function(void Function()) setDialogState) async {
      await SecureStorageService.instance.delete('openai_api_key');
      setDialogState(() {
        openaiKeyController.clear();
        openaiValidationResult = null;
      });
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (!keysLoaded) {
              loadCloudSettings(setDialogState);
            }
            return DefaultTabController(
              length: 4,
              child: AlertDialog(
                backgroundColor: const Color(0xFF1E1E26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                title: Row(
                  children: const [
                    Icon(Icons.settings, color: Color(0xFF7C4DFF)),
                    SizedBox(width: 12),
                    Text('AURA Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                content: SizedBox(
                  width: 550,
                  height: 520,
                  child: Column(
                    children: [
                      const TabBar(
                        isScrollable: true,
                        labelColor: Color(0xFF7C4DFF),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Color(0xFF7C4DFF),
                        tabs: [
                          Tab(text: 'Server & Cloud'),
                          Tab(text: 'RAG Documents'),
                          Tab(text: 'Trusted Folders'),
                          Tab(text: 'Backup & Restore'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, child) {
                            final knowledgeState = ref.watch(desktopKnowledgeProvider);
                            final knowledgeNotifier = ref.read(desktopKnowledgeProvider.notifier);
                            final foldersState = ref.watch(desktopTrustedFoldersProvider);
                            final foldersNotifier = ref.read(desktopTrustedFoldersProvider.notifier);

                            return TabBarView(
                              children: [
                                // Tab 1: Server & Cloud
                                SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SwitchListTile(
                                        activeThumbColor: const Color(0xFF7C4DFF),
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text('Run In-App Server (Direct GGUF)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                                        subtitle: const Text('Jalankan model .gguf langsung tanpa Ollama / LM Studio', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        value: dialogUseInAppServer,
                                        onChanged: (val) {
                                          setDialogState(() {
                                            dialogUseInAppServer = val;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      if (dialogUseInAppServer) ...[
                                        const Text('llama-server Executable Path', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: serverPathController,
                                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                                decoration: InputDecoration(
                                                  hintText: 'e.g. C:\\path\\to\\llama-server.exe',
                                                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                                                  fillColor: const Color(0xFF13131A),
                                                  filled: true,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                                                foregroundColor: Colors.white,
                                              ),
                                              onPressed: () async {
                                                final result = await FilePickerPlatform.instance.pickFiles(
                                                  dialogTitle: 'Select llama-server executable',
                                                  type: FileType.any,
                                                );
                                                if (result.isNotEmpty && result.first.path != null) {
                                                  setDialogState(() {
                                                    serverPathController.text = result.first.path!;
                                                  });
                                                }
                                              },
                                              child: const Text('Browse'),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        const Text('GGUF Model File Path', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: modelPathController,
                                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                                decoration: InputDecoration(
                                                  hintText: 'e.g. C:\\path\\to\\model.gguf',
                                                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                                                  fillColor: const Color(0xFF13131A),
                                                  filled: true,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                                                foregroundColor: Colors.white,
                                              ),
                                              onPressed: () async {
                                                final result = await FilePickerPlatform.instance.pickFiles(
                                                  dialogTitle: 'Select GGUF model file',
                                                  type: FileType.custom,
                                                  allowedExtensions: ['gguf'],
                                                );
                                                if (result.isNotEmpty && result.first.path != null) {
                                                  setDialogState(() {
                                                    modelPathController.text = result.first.path!;
                                                  });
                                                }
                                              },
                                              child: const Text('Browse'),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: dialogIsInAppServerRunning
                                                    ? Colors.redAccent.withValues(alpha: 0.2)
                                                    : const Color(0xFF00BFA5).withValues(alpha: 0.2),
                                                foregroundColor: dialogIsInAppServerRunning ? Colors.redAccent : const Color(0xFF00BFA5),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                              icon: isTesting
                                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                                  : Icon(dialogIsInAppServerRunning ? Icons.stop : Icons.play_arrow, size: 18),
                                              label: Text(dialogIsInAppServerRunning ? 'Stop Server' : 'Start Server'),
                                              onPressed: isTesting
                                                  ? null
                                                  : () async {
                                                      if (dialogIsInAppServerRunning) {
                                                        setDialogState(() {
                                                          isTesting = true;
                                                          testResult = 'Stopping server...';
                                                        });
                                                        await notifier.stopInAppServer();
                                                        setDialogState(() {
                                                          isTesting = false;
                                                          dialogIsInAppServerRunning = false;
                                                          testResult = 'Server stopped.';
                                                        });
                                                      } else {
                                                        if (serverPathController.text.trim().isEmpty || modelPathController.text.trim().isEmpty) {
                                                          setDialogState(() {
                                                            testResult = 'Error: Paths cannot be empty!';
                                                          });
                                                          return;
                                                        }
                                                        setDialogState(() {
                                                          isTesting = true;
                                                          testResult = 'Starting llama-server...';
                                                        });
                                                        final success = await notifier.startInAppServer(
                                                          serverPath: serverPathController.text.trim(),
                                                          modelPath: modelPathController.text.trim(),
                                                        );
                                                        setDialogState(() {
                                                          isTesting = false;
                                                          dialogIsInAppServerRunning = success;
                                                          testResult = success ? 'Server connected successfully!' : 'Failed to connect. Check paths.';
                                                        });
                                                      }
                                                    },
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                testResult.isEmpty
                                                    ? (dialogIsInAppServerRunning ? 'Running on http://localhost:8080/v1' : 'Ready to start')
                                                    : testResult,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: dialogIsInAppServerRunning ? Colors.greenAccent : Colors.grey,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        SwitchListTile(
                                          activeThumbColor: const Color(0xFF00BFA5),
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text('Expose Server to LAN (0.0.0.0)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                          subtitle: const Text('Izinkan HP/device lain di jaringan WiFi Anda untuk mengakses server ini', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          value: state.exposeToLan,
                                          onChanged: (val) async {
                                            await notifier.updateLanSettings(exposeToLan: val);
                                            setDialogState(() {});
                                          },
                                        ),
                                        if (state.exposeToLan) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF13131A),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0xFF00BFA5).withValues(alpha: 0.3)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: const [
                                                    Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 16),
                                                    SizedBox(width: 8),
                                                    Text('Peringatan Keamanan', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                const Text(
                                                  'Pastikan Anda berada di jaringan WiFi tepercaya (misal: rumah sendiri, bukan WiFi publik) sebelum mengaktifkan fitur ini.',
                                                  style: TextStyle(color: Colors.grey, fontSize: 10, height: 1.4),
                                                ),
                                                const Divider(color: Colors.white12, height: 16),
                                                Text('IP Address: ${state.localIp}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                                                const SizedBox(height: 4),
                                                const Text('Port: 8080', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                                                const SizedBox(height: 4),
                                                Text('Pairing PIN: ${state.pairingPin}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.greenAccent)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ] else ...[
                                        const Text('Pilih API Type & URL sesuai server LLM lokal Anda (Ollama / LM Studio).', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                        const SizedBox(height: 16),
                                        const Text('API Type', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF13131A),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: selectedApiType,
                                              isExpanded: true,
                                              dropdownColor: const Color(0xFF1E1E26),
                                              items: const [
                                                DropdownMenuItem(value: 'Ollama', child: Text('Ollama', style: TextStyle(color: Colors.white))),
                                                DropdownMenuItem(value: 'OpenAI-Compatible', child: Text('OpenAI-Compatible (LM Studio / llama-server)', style: TextStyle(color: Colors.white))),
                                              ],
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setDialogState(() {
                                                    selectedApiType = val;
                                                    if (val == 'Ollama' && urlController.text.contains('1234')) {
                                                      urlController.text = 'http://localhost:11434';
                                                    } else if (val == 'OpenAI-Compatible' && urlController.text.contains('11434')) {
                                                      urlController.text = 'http://localhost:1234/v1';
                                                    }
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text('Base URL', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: urlController,
                                          style: const TextStyle(color: Colors.white, fontSize: 13),
                                          decoration: InputDecoration(
                                            hintText: 'e.g. http://localhost:11434',
                                            hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                                            fillColor: const Color(0xFF13131A),
                                            filled: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text('Active Model', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                                        const SizedBox(height: 6),
                                        if (state.availableModels.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF13131A),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: state.availableModels.contains(selectedModel) ? selectedModel : state.availableModels.first,
                                                isExpanded: true,
                                                dropdownColor: const Color(0xFF1E1E26),
                                                items: state.availableModels.map((modelName) {
                                                  return DropdownMenuItem(value: modelName, child: Text(modelName, style: const TextStyle(color: Colors.white)));
                                                }).toList(),
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setDialogState(() {
                                                      selectedModel = val;
                                                    });
                                                  }
                                                },
                                              ),
                                            ),
                                          )
                                        else
                                          TextField(
                                            controller: modelController,
                                            style: const TextStyle(color: Colors.white, fontSize: 13),
                                            decoration: InputDecoration(
                                              hintText: 'e.g. gemma:2b',
                                              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                                              fillColor: const Color(0xFF13131A),
                                              filled: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(10),
                                                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 20),
                                        Row(
                                          children: [
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.white.withValues(alpha: 0.08),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                              icon: isTesting
                                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                                  : const Icon(Icons.bolt, size: 18),
                                              label: const Text('Test & Discover Models'),
                                              onPressed: isTesting
                                                  ? null
                                                  : () async {
                                                      setDialogState(() {
                                                        isTesting = true;
                                                        testResult = 'Connecting...';
                                                      });
                                                      await notifier.updateSettings(
                                                        baseUrl: urlController.text.trim(),
                                                        apiType: selectedApiType,
                                                        activeModel: state.availableModels.isNotEmpty ? selectedModel : modelController.text.trim(),
                                                      );
                                                      final currentChatState = ref.read(desktopChatProvider);
                                                      setDialogState(() {
                                                        isTesting = false;
                                                        if (currentChatState.isServerConnected) {
                                                          testResult = 'Success! Found ${currentChatState.availableModels.length} models.';
                                                          if (currentChatState.availableModels.isNotEmpty) {
                                                            selectedModel = currentChatState.activeModel;
                                                          }
                                                        } else {
                                                          testResult = 'Connection Failed. Check URL & server.';
                                                        }
                                                      });
                                                    },
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                testResult,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: testResult.contains('Success') ? Colors.greenAccent : (testResult.contains('Failed') ? Colors.redAccent : Colors.grey),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const Divider(color: Colors.white12, height: 32),
                                      const Text('Cloud Provider (Opsional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF7C4DFF))),
                                      const SizedBox(height: 6),
                                      const Text('Gunakan Google Gemini atau OpenAI sebagai asisten cadangan berdaya tinggi secara manual.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      const SizedBox(height: 12),
                                      const Text('Aktifkan Provider:', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: RadioListTile<String>(
                                              contentPadding: EdgeInsets.zero,
                                              title: const Text('Gemini', style: TextStyle(fontSize: 12, color: Colors.white)),
                                              value: 'gemini',
                                              groupValue: activeCloudProvider,
                                              activeColor: const Color(0xFF7C4DFF),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setDialogState(() => activeCloudProvider = val);
                                                  SecureStorageService.instance.write('active_cloud_provider', val);
                                                }
                                              },
                                            ),
                                          ),
                                          Expanded(
                                            child: RadioListTile<String>(
                                              contentPadding: EdgeInsets.zero,
                                              title: const Text('OpenAI', style: TextStyle(fontSize: 12, color: Colors.white)),
                                              value: 'openai',
                                              groupValue: activeCloudProvider,
                                              activeColor: const Color(0xFF7C4DFF),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setDialogState(() => activeCloudProvider = val);
                                                  SecureStorageService.instance.write('active_cloud_provider', val);
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      const Text('Gemini API Key', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: geminiKeyController,
                                              obscureText: obscureGeminiKey,
                                              style: const TextStyle(color: Colors.white, fontSize: 13),
                                              decoration: InputDecoration(
                                                hintText: 'API Key Gemini...',
                                                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                                                fillColor: const Color(0xFF13131A),
                                                filled: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                suffixIcon: IconButton(
                                                  icon: Icon(obscureGeminiKey ? Icons.visibility_off : Icons.visibility, size: 18),
                                                  onPressed: () => setDialogState(() => obscureGeminiKey = !obscureGeminiKey),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                            onPressed: () => deleteGeminiKey(setDialogState),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                                              foregroundColor: const Color(0xFF7C4DFF),
                                            ),
                                            onPressed: isValidatingGemini ? null : () => validateGeminiKey(setDialogState),
                                            child: isValidatingGemini
                                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                                : const Text('Validasi & Simpan', style: TextStyle(fontSize: 11)),
                                          ),
                                          if (geminiValidationResult != null)
                                            Text(
                                              geminiValidationResult!,
                                              style: TextStyle(
                                                color: geminiValidationResult == 'Valid' ? const Color(0xFF00BFA5) : Colors.redAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      const Text('OpenAI API Key', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: openaiKeyController,
                                              obscureText: obscureOpenaiKey,
                                              style: const TextStyle(color: Colors.white, fontSize: 13),
                                              decoration: InputDecoration(
                                                hintText: 'API Key OpenAI...',
                                                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                                                fillColor: const Color(0xFF13131A),
                                                filled: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                suffixIcon: IconButton(
                                                  icon: Icon(obscureOpenaiKey ? Icons.visibility_off : Icons.visibility, size: 18),
                                                  onPressed: () => setDialogState(() => obscureOpenaiKey = !obscureOpenaiKey),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                            onPressed: () => deleteOpenaiKey(setDialogState),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                                              foregroundColor: const Color(0xFF7C4DFF),
                                            ),
                                            onPressed: isValidatingOpenai ? null : () => validateOpenaiKey(setDialogState),
                                            child: isValidatingOpenai
                                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                                : const Text('Validasi & Simpan', style: TextStyle(fontSize: 11)),
                                          ),
                                          if (openaiValidationResult != null)
                                            Text(
                                              openaiValidationResult!,
                                              style: TextStyle(
                                                color: openaiValidationResult == 'Valid' ? const Color(0xFF00BFA5) : Colors.redAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (activeCloudProvider == 'openai') ...[
                                        const SizedBox(height: 12),
                                        const Text('OpenAI Model', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF13131A),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: openaiModel,
                                              dropdownColor: const Color(0xFF1E1E26),
                                              isExpanded: true,
                                              items: const [
                                                DropdownMenuItem(value: 'gpt-4o-mini', child: Text('gpt-4o-mini', style: TextStyle(color: Colors.white, fontSize: 12))),
                                                DropdownMenuItem(value: 'gpt-4o', child: Text('gpt-4o', style: TextStyle(color: Colors.white, fontSize: 12))),
                                                DropdownMenuItem(value: 'o1-mini', child: Text('o1-mini', style: TextStyle(color: Colors.white, fontSize: 12))),
                                              ],
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setDialogState(() => openaiModel = val);
                                                  SecureStorageService.instance.write('openai_model', val);
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Tab 2: RAG Documents
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Sumber Pengetahuan (RAG)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF7C4DFF))),
                                    const SizedBox(height: 6),
                                    const Text('Latih asisten AURA dengan mengunggah dokumen pribadi Anda (.txt, .md, .pdf) ke dalam memori vektor lokal.', style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.4)),
                                    const SizedBox(height: 12),
                                    if (knowledgeState.isImporting && knowledgeState.importingProgressText != null)
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C4DFF))),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(knowledgeState.importingProgressText!, style: const TextStyle(color: Color(0xFF7C4DFF), fontSize: 11, fontWeight: FontWeight.w500)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    Expanded(
                                      child: knowledgeState.sources.isEmpty
                                          ? Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.library_books_outlined, size: 40, color: Colors.grey.withValues(alpha: 0.5)),
                                                  const SizedBox(height: 8),
                                                  const Text('Belum ada dokumen', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 4),
                                                  const Text('Impor file untuk melatih memori vektor AURA.', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                                ],
                                              ),
                                            )
                                          : ListView.builder(
                                              itemCount: knowledgeState.sources.length,
                                              itemBuilder: (context, index) {
                                                final doc = knowledgeState.sources[index];
                                                final isPdf = doc.name.toLowerCase().endsWith('.pdf');
                                                return Card(
                                                  color: const Color(0xFF13131A),
                                                  elevation: 0,
                                                  margin: const EdgeInsets.only(bottom: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                                                  ),
                                                  child: ListTile(
                                                    dense: true,
                                                    leading: Icon(isPdf ? Icons.picture_as_pdf : Icons.description, color: isPdf ? Colors.redAccent : const Color(0xFF00BFA5)),
                                                    title: Text(doc.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                                    subtitle: Text('${doc.chunkCount} chunks • ${doc.path}', style: const TextStyle(color: Colors.grey, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                    trailing: IconButton(
                                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                                      onPressed: () async {
                                                        final deleteConfirmed = await showDialog<bool>(
                                                          context: context,
                                                          builder: (ctx) => AlertDialog(
                                                            backgroundColor: const Color(0xFF1E1E26),
                                                            title: const Text('Hapus Dokumen?', style: TextStyle(color: Colors.white)),
                                                            content: Text('Apakah Anda yakin ingin menghapus "${doc.name}" dari basis pengetahuan? Seluruh potongan memori vektornya juga akan dibersihkan.'),
                                                            actions: [
                                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                                                              ElevatedButton(
                                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                                                onPressed: () => Navigator.pop(ctx, true),
                                                                child: const Text('Hapus'),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                        if (deleteConfirmed == true) {
                                                          setDialogState(() {});
                                                          await knowledgeNotifier.deleteDocument(doc.id);
                                                          setDialogState(() {});
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF7C4DFF),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.upload_file, size: 16),
                                        label: const Text('Tambah Dokumen (.txt, .md, .pdf)'),
                                        onPressed: knowledgeState.isImporting
                                            ? null
                                            : () async {
                                                final result = await FilePickerPlatform.instance.pickFiles(
                                                  type: FileType.custom,
                                                  allowedExtensions: ['txt', 'md', 'pdf'],
                                                );
                                                if (result.isNotEmpty && result.first.path != null) {
                                                  setDialogState(() {});
                                                  await knowledgeNotifier.importDocument(result.first.path!);
                                                  setDialogState(() {});
                                                }
                                              },
                                      ),
                                    ),
                                  ],
                                ),

                                // Tab 3: Trusted Folders
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Folder Terpercaya (Read-Only)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
                                    const SizedBox(height: 6),
                                    const Text('Daftar folder lokal yang diizinkan untuk diakses asisten AURA secara langsung saat diminta (read-only, tanpa write/execute).', style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.4)),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: foldersState.folders.isEmpty
                                          ? Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.folder_shared_outlined, size: 40, color: Colors.grey.withValues(alpha: 0.5)),
                                                  const SizedBox(height: 8),
                                                  const Text('Belum ada folder', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 4),
                                                  const Text('Tambahkan folder untuk memberi akses asisten AURA.', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                                ],
                                              ),
                                            )
                                          : ListView.builder(
                                              itemCount: foldersState.folders.length,
                                              itemBuilder: (context, index) {
                                                final folder = foldersState.folders[index];
                                                final folderId = folder['id'] as int;
                                                final folderPath = folder['path'] as String;
                                                return Card(
                                                  color: const Color(0xFF13131A),
                                                  elevation: 0,
                                                  margin: const EdgeInsets.only(bottom: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                                                  ),
                                                  child: ListTile(
                                                    dense: true,
                                                    leading: const Icon(Icons.folder_open, color: Color(0xFF00BFA5)),
                                                    title: Text(path_lib.basename(folderPath), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                                    subtitle: Text(folderPath, style: const TextStyle(color: Colors.grey, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                    trailing: IconButton(
                                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                                      onPressed: () async {
                                                        final deleteConfirmed = await showDialog<bool>(
                                                          context: context,
                                                          builder: (ctx) => AlertDialog(
                                                            backgroundColor: const Color(0xFF1E1E26),
                                                            title: const Text('Hapus Folder Terpercaya?', style: TextStyle(color: Colors.white)),
                                                            content: Text('Apakah Anda yakin ingin menghapus "$folderPath" dari whitelist? AURA tidak akan bisa membaca berkas dari direktori ini.'),
                                                            actions: [
                                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                                                              ElevatedButton(
                                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                                                onPressed: () => Navigator.pop(ctx, true),
                                                                child: const Text('Hapus'),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                        if (deleteConfirmed == true) {
                                                          setDialogState(() {});
                                                          await foldersNotifier.removeFolder(folderId);
                                                          setDialogState(() {});
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF00BFA5),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.create_new_folder, size: 16),
                                        label: const Text('Tambah Folder Whitelist'),
                                        onPressed: () async {
                                          final path = await FilePickerPlatform.instance.getDirectoryPath();
                                          if (path != null && path.isNotEmpty) {
                                            setDialogState(() {});
                                            await foldersNotifier.addFolder(path);
                                            setDialogState(() {});
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),

                                // Tab 4: Backup & Restore
                                SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Backup & Restore', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
                                      const SizedBox(height: 6),
                                      const Text('Ekspor atau impor riwayat sesi obrolan, persona, dan memori AURA (.aurabackup).', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            icon: const Icon(Icons.download, size: 16),
                                            label: const Text('Export Backup'),
                                            onPressed: () async {
                                              try {
                                                final jsonData = await BackupService.instance.exportBackupData();
                                                final bytes = utf8.encode(jsonData);
                                                final result = await FilePickerPlatform.instance.saveFile(
                                                  dialogTitle: 'Save AURA Backup',
                                                  fileName: 'aura_backup_${DateTime.now().toIso8601String().substring(0, 10)}.aurabackup',
                                                  bytes: bytes,
                                                  mimeType: 'application/octet-stream',
                                                );
                                                if (result != null) {
                                                  setDialogState(() {
                                                    testResult = '✅ Backup exported successfully!';
                                                  });
                                                }
                                              } catch (e) {
                                                setDialogState(() {
                                                  testResult = '❌ Export failed: $e';
                                                });
                                              }
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            icon: const Icon(Icons.upload, size: 16),
                                            label: const Text('Import Backup'),
                                            onPressed: () async {
                                              try {
                                                final result = await FilePickerPlatform.instance.pickFiles(
                                                  dialogTitle: 'Select AURA Backup File',
                                                  type: FileType.any,
                                                );
                                                if (result.isNotEmpty && result.first.path != null) {
                                                  final fileContent = await File(result.first.path!).readAsString();
                                                  final validation = BackupService.instance.validateBackup(fileContent);
                                                  if (!validation.isValid) {
                                                    setDialogState(() {
                                                      testResult = '❌ Invalid backup: ${validation.errorMessage}';
                                                    });
                                                    return;
                                                  }
                                                  if (!context.mounted) return;
                                                  final restoreConfirmed = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      backgroundColor: const Color(0xFF1E1E26),
                                                      title: const Text('Confirm Restore'),
                                                      content: Text(
                                                        'Apakah Anda yakin ingin me-restore backup ini?\n\n'
                                                        'Peringatan: Seluruh data saat ini (sesi chat, pesan, dll) akan dihapus dan digantikan oleh data backup.\n\n'
                                                        'Detail Backup:\n'
                                                        '- Sesi Chat: ${validation.sessionCount}\n'
                                                        '- Total Pesan: ${validation.messageCount}\n'
                                                        '- Tanggal Ekspor: ${validation.exportedAt?.toLocal() ?? 'Tidak diketahui'}',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(ctx, false),
                                                          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                                        ),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                                          onPressed: () => Navigator.pop(ctx, true),
                                                          child: const Text('Restore Data'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (restoreConfirmed == true) {
                                                    final success = await BackupService.instance.restoreBackupData(fileContent);
                                                    if (success) {
                                                      setDialogState(() {
                                                        testResult = '✅ Restore successful!';
                                                      });
                                                      await notifier.loadSessions();
                                                    } else {
                                                      setDialogState(() {
                                                        testResult = '❌ Restore failed.';
                                                      });
                                                    }
                                                  }
                                                }
                                              } catch (e) {
                                                setDialogState(() {
                                                  testResult = '❌ Import failed: $e';
                                                });
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    
                    // Save API Keys directly on Save & Apply
                    final geminiKey = geminiKeyController.text.trim();
                    final openaiKey = openaiKeyController.text.trim();
                    if (geminiKey.isNotEmpty) {
                      await SecureStorageService.instance.write('gemini_api_key', geminiKey);
                    } else {
                      await SecureStorageService.instance.delete('gemini_api_key');
                    }
                    if (openaiKey.isNotEmpty) {
                      await SecureStorageService.instance.write('openai_api_key', openaiKey);
                    } else {
                      await SecureStorageService.instance.delete('openai_api_key');
                    }

                    if (dialogUseInAppServer) {
                      await notifier.updateSettings(
                        baseUrl: 'http://localhost:8080/v1',
                        apiType: 'OpenAI-Compatible',
                        activeModel: 'local-model',
                        useInAppServer: true,
                        llamaServerPath: serverPathController.text.trim(),
                        ggufModelPath: modelPathController.text.trim(),
                      );
                    } else {
                      await notifier.updateSettings(
                        baseUrl: urlController.text.trim(),
                        apiType: selectedApiType,
                        activeModel: state.availableModels.isNotEmpty ? selectedModel : modelController.text.trim(),
                        useInAppServer: false,
                      );
                    }
                    navigator.pop();
                  },
                    child: const Text('Save & Apply'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(desktopChatProvider);
    final chatNotifier = ref.read(desktopChatProvider.notifier);

    // Auto-scroll when messages update
    ref.listen(desktopChatProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length || next.isLoading) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      body: Row(
        children: [
          // Sidebar - Width: 300
          Container(
            width: 300,
            color: const Color(0xFF0F0F14),
            child: Column(
              children: [
                // Glowing Header Logo
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C4DFF), Color(0xFF00BFA5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'A.U.R.A',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Desktop Personal AI',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Navigation Section Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _activeNavIndex = 0),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _activeNavIndex == 0
                                  ? const Color(0xFF7C4DFF).withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _activeNavIndex == 0
                                    ? const Color(0xFF7C4DFF)
                                    : Colors.white10,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  color: _activeNavIndex == 0
                                      ? const Color(0xFF7C4DFF)
                                      : Colors.grey,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'AI Chat',
                                  style: TextStyle(
                                    color: _activeNavIndex == 0
                                        ? Colors.white
                                        : Colors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _activeNavIndex = 1),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _activeNavIndex == 1
                                  ? const Color(0xFF6C63FF).withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _activeNavIndex == 1
                                    ? const Color(0xFF6C63FF)
                                    : Colors.white10,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.candlestick_chart,
                                  color: _activeNavIndex == 1
                                      ? const Color(0xFF6C63FF)
                                      : Colors.grey,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Trading Lab',
                                  style: TextStyle(
                                    color: _activeNavIndex == 1
                                        ? Colors.white
                                        : Colors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                
                // New Chat Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: InkWell(
                    onTap: chatNotifier.createNewSession,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.3)),
                        gradient: LinearGradient(
                          colors: [const Color(0xFF7C4DFF).withValues(alpha: 0.15), Colors.transparent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Color(0xFF7C4DFF), size: 18),
                          SizedBox(width: 10),
                          Text(
                            'New Chat',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Session List Header
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'CHAT HISTORY',
                      style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ),
                ),
                
                // Sessions list
                Expanded(
                  child: ListView.builder(
                    itemCount: chatState.sessions.length,
                    itemBuilder: (context, index) {
                      final session = chatState.sessions[index];
                      final isSelected = chatState.activeSession?.id == session.id;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1E1E28) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              hoverColor: Colors.white.withValues(alpha: 0.03),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              leading: Icon(
                                Icons.chat_bubble_outline,
                                color: isSelected ? const Color(0xFF7C4DFF) : Colors.grey,
                                size: 18,
                              ),
                              title: Text(
                                'Obrolan #${session.id}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : const Color(0xFFE0E0E0),
                                ),
                              ),
                              subtitle: Text(
                                session.modelName ?? 'gemma:2b',
                                style: TextStyle(fontSize: 10, color: isSelected ? const Color(0xFF00BFA5) : Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: isSelected 
                                ? IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                                    onPressed: () => chatNotifier.deleteSession(session.id),
                                    tooltip: 'Hapus Obrolan',
                                  )
                                : null,
                              onTap: () => chatNotifier.selectSession(session),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Bottom Settings Bar & Connection Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  color: const Color(0xFF0A0A0E),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: chatState.isServerConnected ? Colors.green : Colors.grey,
                              boxShadow: chatState.isServerConnected ? [
                                BoxShadow(
                                  color: Colors.green.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                )
                              ] : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              chatState.statusMessage,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(0xFF1E1E26),
                            child: Icon(Icons.person, color: Colors.grey, size: 18),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Guest User',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings, color: Colors.grey, size: 20),
                            onPressed: () => _showSettingsDialog(context, chatState, chatNotifier),
                            tooltip: 'Server Settings',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Main View Area (Chat or Trading Lab)
          Expanded(
            child: _activeNavIndex == 1
                ? const DesktopTradingScreen()
                : Container(
                    color: const Color(0xFF13131A),
                    child: Column(
                      children: [

                  // Top Header Bar
                  Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chatState.activeSession != null
                                  ? 'Active Session #${chatState.activeSession!.id}'
                                  : 'No Session',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Inference: ${chatState.activeModel} (${chatState.apiType})',
                              style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 11),
                            ),
                          ],
                        ),
                        
                        // Local Server status pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: chatState.isServerConnected 
                              ? const Color(0xFF00BFA5).withValues(alpha: 0.1) 
                              : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: chatState.isServerConnected 
                                ? const Color(0xFF00BFA5).withValues(alpha: 0.3) 
                                : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                chatState.isServerConnected ? Icons.cloud_done : Icons.cloud_off, 
                                color: chatState.isServerConnected ? const Color(0xFF00BFA5) : Colors.grey, 
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                chatState.isServerConnected ? 'Server Online' : 'Server Offline',
                                style: TextStyle(
                                  color: chatState.isServerConnected ? const Color(0xFF00BFA5) : Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Message list
                  Expanded(
                    child: chatState.messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.forum_outlined, size: 48, color: Colors.white.withValues(alpha: 0.15)),
                                const SizedBox(height: 16),
                                Text(
                                  'Belum ada obrolan.',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Hubungkan local LLM server di settings dan mulailah mengobrol!',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                            itemCount: chatState.messages.length,
                            itemBuilder: (context, index) {
                              final msg = chatState.messages[index];
                              final isUser = msg.isUser;
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isUser) ...[
                                      const CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Color(0xFF7C4DFF),
                                        child: Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Column(
                                      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context).size.width * 0.55,
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            gradient: isUser
                                                ? const LinearGradient(
                                                    colors: [Color(0xFF7C4DFF), Color(0xFF6200EA)],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  )
                                                : null,
                                            color: isUser ? null : const Color(0xFF1C1B22),
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(16),
                                              topRight: const Radius.circular(16),
                                              bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(0),
                                              bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.05),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              )
                                            ],
                                          ),
                                          child: Text(
                                            msg.content,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              color: Colors.white,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                        
                                        // Metrics display under assistant replies
                                        if (!isUser && index == chatState.messages.length - 1 && (chatState.lastPromptTokens > 0 || chatState.lastDurationMs > 0)) ...[
                                          const SizedBox(height: 6),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4),
                                            child: Text(
                                              'Speed: ${(chatState.lastCompletionTokens / (chatState.lastDurationMs / 1000.0)).toStringAsFixed(1)} t/s  |  Prompt: ${chatState.lastPromptTokens} t  |  Eval: ${chatState.lastCompletionTokens} t  |  Time: ${(chatState.lastDurationMs / 1000.0).toStringAsFixed(2)}s',
                                              style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 10),
                                            ),
                                          ),
                                        ]
                                      ],
                                    ),
                                    if (isUser) ...[
                                      const SizedBox(width: 12),
                                      const CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Color(0xFF1E1E26),
                                        child: Icon(Icons.person, color: Colors.grey, size: 16),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  
                  // Linear progress bar when loading
                  if (chatState.isLoading)
                    const LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BFA5)),
                      minHeight: 2,
                    ),
                  
                  // Message input field
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF13131A),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Focus(
  onKeyEvent: (node, event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
        if (isShiftPressed) {
          // Shift+Enter: allow new line insertion
          return KeyEventResult.ignored;
        } else {
          // Enter only: send chat
          final text = _messageController.text;
          if (text.trim().isNotEmpty && !chatState.isLoading) {
            chatNotifier.sendMessage(text, useCloud: useCloudAssistant);
            _messageController.clear();
          }
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  },
  child: TextField(
    controller: _messageController,
    maxLines: null,
    keyboardType: TextInputType.multiline,
    decoration: const InputDecoration(
      hintText: 'Tulis pesan obrolan di sini...',
      border: InputBorder.none,
      hintStyle: TextStyle(color: Colors.grey, fontSize: 13.5),
    ),
    style: const TextStyle(fontSize: 14),
  ),
),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Cloud Toggle Button
                        IconButton(
                          icon: Icon(
                            useCloudAssistant ? Icons.cloud_done_rounded : Icons.cloud_outlined,
                            color: useCloudAssistant ? const Color(0xFF7C4DFF) : Colors.grey,
                            size: 20,
                          ),
                          tooltip: 'Gunakan Asisten Cloud',
                          onPressed: () async {
                            final geminiKey = await SecureStorageService.instance.read('gemini_api_key') ?? '';
                            final openaiKey = await SecureStorageService.instance.read('openai_api_key') ?? '';
                            if (geminiKey.isEmpty && openaiKey.isEmpty) {
                              if (!context.mounted) return;
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1E26),
                                  title: const Text('API Key Kosong', style: TextStyle(color: Colors.white)),
                                  content: const Text('Kunci API Cloud kosong. Silakan isi API Key di Settings terlebih dahulu.', style: TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('OK', style: TextStyle(color: Color(0xFF7C4DFF))),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }
                            setState(() {
                              useCloudAssistant = !useCloudAssistant;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        
                        // Send Button
                        InkWell(
                          onTap: chatState.isLoading ? null : () {
                            final text = _messageController.text;
                            if (text.trim().isNotEmpty) {
                              chatNotifier.sendMessage(text, useCloud: useCloudAssistant);
                              _messageController.clear();
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: chatState.isLoading ? Colors.white.withValues(alpha: 0.05) : const Color(0xFF7C4DFF),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: chatState.isLoading ? null : [
                                BoxShadow(
                                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: const Icon(Icons.send, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
