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
        )) {
    _init();
  }

  final ChatDatabase _db = ChatDatabase.instance;

  Future<void> _init() async {
    await loadSessions();
    await checkConnection();
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
  }) async {
    state = state.copyWith(
      baseUrl: baseUrl,
      apiType: apiType,
      activeModel: activeModel,
    );
    await checkConnection();
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
        statusMessage: 'Connected to ${state.apiType}',
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
