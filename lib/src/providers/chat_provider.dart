import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/chat_database.dart';
import '../storage/chat_models.dart';
import 'memory_provider.dart';

part 'chat_provider.g.dart';

/// State for the active chat session
class ChatState {
  const ChatState({
    this.sessionId,
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  final int? sessionId;
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  bool get hasSession => sessionId != null;
  bool get hasError => error != null;

  ChatMessage? get lastAssistantMessage {
    for (final m in messages.reversed) {
      if (m.isAssistant) return m;
    }
    return null;
  }

  ChatState copyWith({
    int? sessionId,
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Manages the active chat session and message list.
/// Bridges the UI with the database and inference worker.
@riverpod
class ChatNotifier extends _$ChatNotifier {
  @override
  ChatState build() => const ChatState();

  final ChatDatabase _db = ChatDatabase.instance;

  /// Start a new chat session (or load existing one)
  Future<void> startNewSession({String? modelName}) async {
    final sessionId = await _db.createSession(modelName: modelName);
    if (ref.mounted) {
      state = ChatState(sessionId: sessionId);
    }
  }

  /// Load an existing session from history
  Future<void> loadSession(int sessionId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final messages = await _db.getMessagesForSession(sessionId);
      state = ChatState(sessionId: sessionId, messages: messages);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Add a user message and persist it
  Future<ChatMessage?> addUserMessage(String text) async {
    final sessionId = state.sessionId;
    if (sessionId == null) return null;

    final message = ChatMessage(
      id: 0, // will be replaced by DB-generated ID
      sessionId: sessionId,
      role: MessageRole.user,
      content: text.trim(),
      timestamp: DateTime.now(),
    );

    final savedId = await _db.saveMessage(message);
    final saved = message.copyWith(id: savedId);

    // Update session title from first user message
    if (state.messages.isEmpty) {
      final title = text.length > 40 ? '${text.substring(0, 40)}…' : text;
      await _db.updateSessionTitle(sessionId, title);
    }

    state = state.copyWith(messages: [...state.messages, saved]);

    // Store in semantic memory (non-blocking)
    ref.read(memoryProvider.notifier).storeMessage(saved).ignore();

    return saved;
  }

  /// Begin streaming an assistant response (creates placeholder message)
  ChatMessage beginAssistantResponse() {
    final sessionId = state.sessionId!;
    final placeholder = ChatMessage(
      id: -1, // temporary ID until streaming completes
      sessionId: sessionId,
      role: MessageRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    state = state.copyWith(messages: [...state.messages, placeholder]);
    return placeholder;
  }

  /// Append a token to the last streaming assistant message
  void appendToken(String token) {
    final messages = List<ChatMessage>.from(state.messages);
    final lastIdx = messages.lastIndexWhere((m) => m.isAssistant && m.isStreaming);
    if (lastIdx < 0) return;

    messages[lastIdx] = messages[lastIdx].copyWith(
      content: messages[lastIdx].content + token,
    );
    state = state.copyWith(messages: messages);
  }

  /// Finalize the streaming message and persist it
  Future<void> finalizeAssistantResponse() async {
    final messages = List<ChatMessage>.from(state.messages);
    final lastIdx = messages.lastIndexWhere((m) => m.isAssistant && m.isStreaming);
    if (lastIdx < 0) return;

    final finalized = messages[lastIdx].copyWith(isStreaming: false);
    final savedId = await _db.saveMessage(finalized);
    messages[lastIdx] = finalized.copyWith(id: savedId);
    state = state.copyWith(messages: messages);

    // Store completed assistant response in semantic memory (non-blocking)
    ref.read(memoryProvider.notifier)
        .storeMessage(messages[lastIdx]).ignore();
  }

  /// Add a tool observation message (result fed back to model)
  Future<void> addToolObservation(String toolName, String result) async {
    final sessionId = state.sessionId!;
    final obs = ChatMessage(
      id: 0,
      sessionId: sessionId,
      role: MessageRole.tool,
      content: '[$toolName] $result',
      timestamp: DateTime.now(),
      toolResult: result,
    );
    final savedId = await _db.saveMessage(obs);
    state = state.copyWith(
      messages: [...state.messages, obs.copyWith(id: savedId)],
    );
  }

  void setError(String error) {
    state = state.copyWith(error: error, isLoading: false);
  }

  /// Stop the current generating assistant response and finalize it in the database
  Future<void> stopGeneration() async {
    await finalizeAssistantResponse();
  }

  /// Delete a session and all its messages
  Future<void> deleteSession(int sessionId) async {
    await _db.deleteSession(sessionId);
    // If we deleted the active session, clear state
    if (state.sessionId == sessionId) {
      state = const ChatState();
    }
  }
}

/// Provider for all chat sessions (sidebar / history list)
@riverpod
Future<List<ChatSession>> allSessions(Ref ref) async {
  return ChatDatabase.instance.getAllSessions();
}
