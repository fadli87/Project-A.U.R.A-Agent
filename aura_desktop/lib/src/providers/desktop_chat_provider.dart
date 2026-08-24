import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_core/aura_core.dart';
import '../services/local_llm_service.dart';

class DesktopChatState {
  final List<ChatSession> sessions;
  final List<ChatMessage> messages;
  final ChatSession? activeSession;
  final bool isLoading;
  final String activeModel;
  final String apiType; // 'Ollama' or 'OpenAI-Compatible'
  final String baseUrl;
  final List<String> availableModels;
  final String statusMessage;
  final bool isServerConnected;
  final int lastPromptTokens;
  final int lastCompletionTokens;
  final int lastDurationMs;

  // New in-app server settings
  final bool useInAppServer;
  final String llamaServerPath;
  final String ggufModelPath;
  final bool isInAppServerRunning;

  DesktopChatState({
    required this.sessions,
    required this.messages,
    this.activeSession,
    required this.isLoading,
    required this.activeModel,
    required this.apiType,
    required this.baseUrl,
    required this.availableModels,
    required this.statusMessage,
    required this.isServerConnected,
    this.lastPromptTokens = 0,
    this.lastCompletionTokens = 0,
    this.lastDurationMs = 0,
    this.useInAppServer = false,
    this.llamaServerPath = '',
    this.ggufModelPath = '',
    this.isInAppServerRunning = false,
  });

  DesktopChatState copyWith({
    List<ChatSession>? sessions,
    List<ChatMessage>? messages,
    ChatSession? Function()? activeSession,
    bool? isLoading,
    String? activeModel,
    String? apiType,
    String? baseUrl,
    List<String>? availableModels,
    String? statusMessage,
    bool? isServerConnected,
    int? lastPromptTokens,
    int? lastCompletionTokens,
    int? lastDurationMs,
    bool? useInAppServer,
    String? llamaServerPath,
    String? ggufModelPath,
    bool? isInAppServerRunning,
  }) {
    return DesktopChatState(
      sessions: sessions ?? this.sessions,
      messages: messages ?? this.messages,
      activeSession: activeSession != null ? activeSession() : this.activeSession,
      isLoading: isLoading ?? this.isLoading,
      activeModel: activeModel ?? this.activeModel,
      apiType: apiType ?? this.apiType,
      baseUrl: baseUrl ?? this.baseUrl,
      availableModels: availableModels ?? this.availableModels,
      statusMessage: statusMessage ?? this.statusMessage,
      isServerConnected: isServerConnected ?? this.isServerConnected,
      lastPromptTokens: lastPromptTokens ?? this.lastPromptTokens,
      lastCompletionTokens: lastCompletionTokens ?? this.lastCompletionTokens,
      lastDurationMs: lastDurationMs ?? this.lastDurationMs,
      useInAppServer: useInAppServer ?? this.useInAppServer,
      llamaServerPath: llamaServerPath ?? this.llamaServerPath,
      ggufModelPath: ggufModelPath ?? this.ggufModelPath,
      isInAppServerRunning: isInAppServerRunning ?? this.isInAppServerRunning,
    );
  }
}

class DesktopChatNotifier extends StateNotifier<DesktopChatState> {
  DesktopChatNotifier()
      : super(DesktopChatState(
          sessions: [],
          messages: [],
          isLoading: false,
          activeModel: 'gemma:2b',
          apiType: 'Ollama',
          baseUrl: 'http://localhost:11434',
          availableModels: [],
          statusMessage: 'Disconnected',
          isServerConnected: false,
          useInAppServer: false,
          llamaServerPath: '',
          ggufModelPath: '',
          isInAppServerRunning: false,
        )) {
    _init();
  }

  final ChatDatabase _db = ChatDatabase.instance;
  Process? _llamaProcess;

  Future<void> _init() async {
    await loadSessions();
    await checkConnection();
  }

  @override
  void dispose() {
    _killLlamaProcess();
    super.dispose();
  }

  void _killLlamaProcess() {
    if (_llamaProcess != null) {
      _llamaProcess!.kill();
      _llamaProcess = null;
    }
  }

  Future<void> stopInAppServer() async {
    _killLlamaProcess();
    state = state.copyWith(
      isInAppServerRunning: false,
      isServerConnected: false,
      statusMessage: 'In-App Server Stopped',
    );
  }

  Future<bool> startInAppServer({
    required String serverPath,
    required String modelPath,
  }) async {
    state = state.copyWith(
      statusMessage: 'Starting In-App LLM Server...',
      isLoading: true,
      llamaServerPath: serverPath,
      ggufModelPath: modelPath,
    );

    _killLlamaProcess();

    try {
      // Spawn llama-server subprocess on port 8080
      _llamaProcess = await Process.start(
        serverPath,
        [
          '-m', modelPath,
          '-c', '2048',
          '--port', '8080',
          '-t', '4',
        ],
      );

      // Listen to stdout/stderr for diagnostics
      _llamaProcess!.stdout.listen((event) {});
      _llamaProcess!.stderr.listen((event) {});

      // Give it a brief delay to warm up
      await Future.delayed(const Duration(seconds: 3));

      // Re-configure API settings to connect to the localhost server
      state = state.copyWith(
        baseUrl: 'http://localhost:8080/v1',
        apiType: 'OpenAI-Compatible',
        activeModel: 'local-model',
        isInAppServerRunning: true,
        isLoading: false,
      );

      // Verify connection to the newly spawned server
      final isConnected = await checkConnection();
      if (isConnected) {
        state = state.copyWith(
          statusMessage: 'In-App Server Active (Port 8080)',
        );
        return true;
      } else {
        _killLlamaProcess();
        state = state.copyWith(
          isInAppServerRunning: false,
          statusMessage: 'In-App Server failed to respond',
        );
        return false;
      }
    } catch (e) {
      _killLlamaProcess();
      state = state.copyWith(
        isInAppServerRunning: false,
        isLoading: false,
        statusMessage: 'Error starting server: $e',
      );
      return false;
    }
  }

  Future<void> loadSessions() async {
    final sessions = await _db.getAllSessions();
    if (sessions.isEmpty) {
      await createNewSession();
    } else {
      final active = sessions.first;
      final messages = await _db.getMessagesForSession(active.id);
      state = state.copyWith(
        sessions: sessions,
        activeSession: () => active,
        messages: messages,
      );
    }
  }

  Future<void> selectSession(ChatSession session) async {
    final messages = await _db.getMessagesForSession(session.id);
    state = state.copyWith(
      activeSession: () => session,
      messages: messages,
    );
  }

  Future<void> createNewSession() async {
    final sessionId = await _db.createSession(modelName: state.activeModel);
    final sessions = await _db.getAllSessions();
    final active = sessions.firstWhere((s) => s.id == sessionId);
    state = state.copyWith(
      sessions: sessions,
      activeSession: () => active,
      messages: [],
    );
  }

  Future<void> deleteSession(int sessionId) async {
    await _db.deleteSession(sessionId);
    await loadSessions();
  }

  Future<void> updateSettings({
    required String baseUrl,
    required String apiType,
    required String activeModel,
    bool? useInAppServer,
    String? llamaServerPath,
    String? ggufModelPath,
  }) async {
    state = state.copyWith(
      baseUrl: baseUrl,
      apiType: apiType,
      activeModel: activeModel,
      useInAppServer: useInAppServer ?? state.useInAppServer,
      llamaServerPath: llamaServerPath ?? state.llamaServerPath,
      ggufModelPath: ggufModelPath ?? state.ggufModelPath,
    );
    
    if (state.useInAppServer) {
      if (state.llamaServerPath.isNotEmpty && state.ggufModelPath.isNotEmpty && !state.isInAppServerRunning) {
        await startInAppServer(
          serverPath: state.llamaServerPath,
          modelPath: state.ggufModelPath,
        );
      }
    } else {
      if (state.isInAppServerRunning) {
        await stopInAppServer();
      }
      await checkConnection();
    }
  }

  Future<bool> checkConnection() async {
    state = state.copyWith(statusMessage: 'Connecting...');
    final models = await LocalLlmService.fetchModels(
      baseUrl: state.baseUrl,
      apiType: state.apiType,
    );

    if (models.isNotEmpty) {
      final active = models.contains(state.activeModel)
          ? state.activeModel
          : models.first;
      state = state.copyWith(
        availableModels: models,
        activeModel: active,
        isServerConnected: true,
        statusMessage: state.isInAppServerRunning 
            ? 'In-App Server Active (Port 8080)' 
            : 'Connected to ${state.apiType}',
      );
      return true;
    } else if (state.isInAppServerRunning) {
      state = state.copyWith(
        availableModels: ['local-model'],
        activeModel: 'local-model',
        isServerConnected: true,
        statusMessage: 'In-App Server Active (Port 8080)',
      );
      return true;
    } else {
      state = state.copyWith(
        availableModels: [],
        isServerConnected: false,
        statusMessage: 'Connection failed',
      );
      return false;
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.activeSession == null) return;
    
    final userMsg = ChatMessage(
      id: 0,
      sessionId: state.activeSession!.id,
      role: MessageRole.user,
      content: text,
      timestamp: DateTime.now(),
    );

    final savedId = await _db.saveMessage(userMsg);
    final userMsgWithId = userMsg.copyWith(id: savedId);

    state = state.copyWith(
      messages: [...state.messages, userMsgWithId],
      isLoading: true,
    );

    // Map messages for the LLM request API
    final apiMessages = state.messages.map((m) {
      return {
        'role': m.role.name,
        'content': m.content,
      };
    }).toList();

    final result = await LocalLlmService.generateChatReply(
      baseUrl: state.baseUrl,
      apiType: state.apiType,
      model: state.activeModel,
      messages: apiMessages,
    );

    final assistantMsg = ChatMessage(
      id: 0,
      sessionId: state.activeSession!.id,
      role: MessageRole.assistant,
      content: EmojiParser.replaceShortcodes(result['content']),
      timestamp: DateTime.now(),
    );

    final replySavedId = await _db.saveMessage(assistantMsg);
    final assistantMsgWithId = assistantMsg.copyWith(id: replySavedId);

    state = state.copyWith(
      messages: [...state.messages, assistantMsgWithId],
      isLoading: false,
      lastPromptTokens: result['promptTokens'],
      lastCompletionTokens: result['completionTokens'],
      lastDurationMs: result['durationMs'],
    );
  }
}

final desktopChatProvider = StateNotifierProvider<DesktopChatNotifier, DesktopChatState>((ref) {
  return DesktopChatNotifier();
});
