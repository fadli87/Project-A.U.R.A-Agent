import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
      // Spawn llama-server subprocess on port 8080 with alias 'local-model'
      _llamaProcess = await Process.start(
        serverPath,
        [
          '-m', modelPath,
          '-c', '2048',
          '--port', '8080',
          '-t', '4',
          '--alias', 'local-model',
        ],
      );

      // Listen to stdout/stderr for diagnostics
      _llamaProcess!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('[llama-server STDOUT] $data');
      });
      _llamaProcess!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('[llama-server STDERR] $data');
      });

      // Poll connection to the newly spawned server (wait up to 120 seconds for slow CPU model load)
      bool isConnected = false;
      for (int i = 1; i <= 60; i++) {
        state = state.copyWith(
          statusMessage: 'Loading model... (${i * 2}s elapsed)',
        );
        await Future.delayed(const Duration(seconds: 2));

        final models = await LocalLlmService.fetchModels(
          baseUrl: 'http://localhost:8080/v1',
          apiType: 'OpenAI-Compatible',
        );
        if (models.isNotEmpty) {
          isConnected = true;
          break;
        }
      }

      if (isConnected) {
        state = state.copyWith(
          baseUrl: 'http://localhost:8080/v1',
          apiType: 'OpenAI-Compatible',
          activeModel: 'local-model',
          isInAppServerRunning: true,
          isLoading: false,
        );
        await checkConnection();
        return true;
      } else {
        _killLlamaProcess();
        state = state.copyWith(
          isInAppServerRunning: false,
          isLoading: false,
          statusMessage: 'In-App Server failed to load model within 2 minutes',
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

  Future<void> _storeMessageInMemory(ChatMessage message) async {
    if (!ObjectBoxStore.isOpen) return;
    if (message.content.trim().isEmpty) return;
    if (message.isTool || message.content.trim().length < 5) return;

    try {
      final embedding = await EmbeddingService.instance.embed(message.content);
      final entry = MemoryEntry(
        content: message.content,
        role: message.role.name,
        sessionId: message.sessionId,
        messageId: message.id,
        timestampMs: message.timestamp.millisecondsSinceEpoch,
        embedding: embedding,
      );
      ObjectBoxStore.instance.memoryBox.put(entry);
    } catch (e) {
      debugPrint('Failed to store memory: $e');
    }
  }

  Future<List<MemoryEntry>> _recallMemories(String query, {int topK = 3}) async {
    if (!ObjectBoxStore.isOpen) return [];
    if (query.trim().isEmpty) return [];

    try {
      final queryEmbedding = await EmbeddingService.instance.embed(query);
      final box = ObjectBoxStore.instance.memoryBox;
      final query_ = box
          .query(MemoryEntry_.embedding.nearestNeighborsF32(queryEmbedding, topK))
          .build();
      final results = query_.find();
      query_.close();
      return results;
    } catch (e) {
      debugPrint('Failed to recall memories: $e');
      return [];
    }
  }

  String _formatMemoriesForPrompt(List<MemoryEntry> memories) {
    if (memories.isEmpty) return '';
    final sb = StringBuffer('[RELEVANT MEMORIES]\n');
    for (final m in memories) {
      final roleLabel = m.role == 'user' ? 'User previously said' : 'Assistant previously said';
      sb.writeln('- $roleLabel: "${m.content.trim()}"');
    }
    sb.writeln('[END MEMORIES]');
    return sb.toString();
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

    // Store user message in vector memory (non-blocking)
    _storeMessageInMemory(userMsgWithId).ignore();

    // Recall relevant memories
    final memories = await _recallMemories(text);
    final memoryContext = _formatMemoriesForPrompt(memories);

    // Map messages for the LLM request API
    final apiMessages = <Map<String, String>>[];
    
    final systemPrompt = StringBuffer();
    systemPrompt.writeln('Anda adalah AURA, asisten AI personal offline yang ekspresif.');
    if (memoryContext.isNotEmpty) {
      systemPrompt.writeln(memoryContext);
    }
    
    apiMessages.add({
      'role': 'system',
      'content': systemPrompt.toString().trim(),
    });

    apiMessages.addAll(state.messages.map((m) {
      return {
        'role': m.role.name,
        'content': m.content,
      };
    }));

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

    // Store assistant message in vector memory (non-blocking)
    _storeMessageInMemory(assistantMsgWithId).ignore();

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
