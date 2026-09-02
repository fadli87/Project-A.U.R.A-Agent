import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
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
  final List<Map<String, dynamic>> trustedFolders;
  final bool exposeToLan;
  final String pairingPin;
  final String localIp;

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
    this.trustedFolders = const [],
    this.exposeToLan = false,
    this.pairingPin = '',
    this.localIp = '127.0.0.1',
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
    List<Map<String, dynamic>>? trustedFolders,
    bool? exposeToLan,
    String? pairingPin,
    String? localIp,
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
      trustedFolders: trustedFolders ?? this.trustedFolders,
      exposeToLan: exposeToLan ?? this.exposeToLan,
      pairingPin: pairingPin ?? this.pairingPin,
      localIp: localIp ?? this.localIp,
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
          trustedFolders: const [],
          exposeToLan: false,
          pairingPin: '',
          localIp: '127.0.0.1',
        )) {
    _init();
  }

  final ChatDatabase _db = ChatDatabase.instance;
  Process? _llamaProcess;

  Future<void> _init() async {
    await loadSessions();
    await checkConnection();
    await loadTrustedFolders();
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
      final host = state.exposeToLan ? '0.0.0.0' : '127.0.0.1';
      final List<String> argsList = [
        '-m', modelPath,
        '--ctx-size', '8192',
        '--port', '8080',
        '-t', '4',
        '--alias', 'local-model',
        '--host', host,
      ];
      if (state.exposeToLan && state.pairingPin.isNotEmpty) {
        argsList.addAll(['--api-key', state.pairingPin]);
      }

      // Spawn llama-server subprocess
      _llamaProcess = await Process.start(serverPath, argsList);

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

  Future<String> _formatMemoriesForPrompt(List<MemoryEntry> memories) async {
    if (memories.isEmpty) return '';
    final sb = StringBuffer();
    
    // Separate chat memories and document memories
    final chatMemories = memories
        .where((m) =>
            m.sourceType != 'document' &&
            !m.content.contains('[Error Inferensi') &&
            !m.content.startsWith('[Error'))
        .toList();
    final docMemories = memories.where((m) => m.sourceType == 'document').toList();
    
    if (chatMemories.isNotEmpty) {
      sb.writeln('[RELEVANT CHAT MEMORIES]');
      for (final m in chatMemories.take(3)) {
        String cleanContent = m.content
            .replaceAll(RegExp(r'<think>[\s\S]*?<\/think>'), '')
            .trim();
        if (cleanContent.isEmpty) continue;
        if (cleanContent.length > 160) {
          cleanContent = '${cleanContent.substring(0, 160)}...';
        }
        final roleLabel = m.role == 'user' ? 'User previously said' : 'Assistant previously said';
        sb.writeln('- $roleLabel: "$cleanContent"');
      }
      sb.writeln('[END CHAT MEMORIES]\n');
    }
    
    if (docMemories.isNotEmpty) {
      sb.writeln('[RELEVANT DOCUMENT CHUNKS]');
      for (final m in docMemories.take(2)) {
        final docName = await _db.getDocumentName(m.sourceId) ?? 'Dokumen Tidak Dikenal';
        String docContent = m.content.trim();
        if (docContent.length > 250) {
          docContent = '${docContent.substring(0, 250)}...';
        }
        sb.writeln('Dari dokumen "$docName":');
        sb.writeln('"""');
        sb.writeln(docContent);
        sb.writeln('"""');
        sb.writeln();
      }
      sb.writeln('[END DOCUMENT CHUNKS]');
    }
    
    return sb.toString();
  }

  Future<void> updateLanSettings({required bool exposeToLan}) async {
    String pin = state.pairingPin;
    if (pin.isEmpty) {
      final r = Random();
      pin = (100000 + r.nextInt(900000)).toString();
    }

    String ip = '127.0.0.1';
    if (exposeToLan) {
      try {
        final interfaces = await NetworkInterface.list(
          includeLoopback: false,
          type: InternetAddressType.IPv4,
        );
        for (final interface in interfaces) {
          for (final addr in interface.addresses) {
            if (!addr.isLoopback) {
              ip = addr.address;
              break;
            }
          }
          if (ip != '127.0.0.1') break;
        }
      } catch (e) {
        debugPrint('Failed to get local IP: $e');
      }
    }

    state = state.copyWith(
      exposeToLan: exposeToLan,
      pairingPin: pin,
      localIp: ip,
    );
  }

  Future<void> loadTrustedFolders() async {
    try {
      final list = await _db.getAllTrustedFolders();
      state = state.copyWith(trustedFolders: list);
    } catch (e) {
      debugPrint('Failed to load trusted folders: $e');
    }
  }

  Future<void> addTrustedFolder(String path) async {
    try {
      await _db.insertTrustedFolder(path);
      await loadTrustedFolders();
    } catch (e) {
      debugPrint('Failed to add trusted folder: $e');
    }
  }

  Future<void> removeTrustedFolder(int id) async {
    try {
      await _db.deleteTrustedFolder(id);
      await loadTrustedFolders();
    } catch (e) {
      debugPrint('Failed to remove trusted folder: $e');
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Senin';
      case 2: return 'Selasa';
      case 3: return 'Rabu';
      case 4: return 'Kamis';
      case 5: return 'Jumat';
      case 6: return 'Sabtu';
      case 7: return 'Minggu';
      default: return '';
    }
  }

  Future<void> sendMessage(String text, {bool useCloud = false}) async {
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

    int iteration = 0;
    final maxIterations = 5;
    final toolRegistry = AgentToolRegistry();

    try {
      // Query active persona and skills from database
      final db = await _db.database;
      final personaMaps = await db.query('Persona', where: 'is_active = 1');
      final activePersonaContent = personaMaps.isNotEmpty ? personaMaps.first['content'] as String? : null;

      final skillMaps = await db.query('Skills', where: 'enabled = 1');

      while (iteration < maxIterations) {
        iteration++;

        // Recall relevant semantic memories for this prompt (using original text)
        final memories = await _recallMemories(text);
        final memoryContext = await _formatMemoriesForPrompt(memories);

        // Assemble system prompt with persona, memories, tools, and skills
        final systemPrompt = StringBuffer();
        
        // 1. Time context
        final nowTime = DateTime.now();
        systemPrompt.writeln('=== INFORMASI WAKTU SISTEM ===');
        systemPrompt.writeln('Tanggal & Waktu Sekarang: ${nowTime.toLocal().toIso8601String()}');
        systemPrompt.writeln('Hari: ${_getDayName(nowTime.weekday)}\n');

        // 2. Style instruction
        systemPrompt.writeln('=== GAYA BAWAAN & FORMAT RESEP ===');
        systemPrompt.writeln('Jawablah dengan gaya yang natural, hangat, santai, dan ekspresif. Hindari format kaku seperti bot/AI formal.');
        systemPrompt.writeln('Dalam menyisipkan emoji, selalu gunakan format teks tag di bawah ini (jangan gunakan emoji unicode langsung):');
        systemPrompt.writeln(':rocket: (roket), :sparkles: (kilatan bintang), :zap: (petir), :bulb: (ide/lampu), :target: (target), :chart: (grafik), :shield: (shield), :pushpin: (pin), :check: (centang), :warning: (peringatan), :info: (info), :smile: (senyum).\n');

        // 3. Active persona
        if (activePersonaContent != null && activePersonaContent.isNotEmpty) {
          systemPrompt.writeln('=== PERSONA & INSTRUKSI UTAMA ===');
          systemPrompt.writeln(activePersonaContent);
          systemPrompt.writeln();
        }

        // 4. Memory context
        if (memoryContext.isNotEmpty) {
          systemPrompt.writeln(memoryContext);
          systemPrompt.writeln();
        }

        // 5. Tool-calling schema
        systemPrompt.writeln(toolRegistry.buildToolsPrompt());

        // 6. Skills index
        if (skillMaps.isNotEmpty) {
          systemPrompt.writeln('=== SKILLS INDEX ===');
          for (final skill in skillMaps) {
            systemPrompt.writeln('- ${skill['name']}: ${skill['description']}');
          }
          systemPrompt.writeln();

          // Inject up to 2 matching skills
          final queryLower = text.toLowerCase();
          int injectedCount = 0;
          for (final skill in skillMaps) {
            if (injectedCount >= 2) break;
            final kw = (skill['keywords'] as String?)?.toLowerCase() ?? '';
            final nameLower = (skill['name'] as String).toLowerCase();
            if ((kw.isNotEmpty && queryLower.contains(kw)) || queryLower.contains(nameLower)) {
              if (injectedCount == 0) systemPrompt.writeln('=== SKILL DEEP-GUIDE ===');
              systemPrompt.writeln('[Skill: ${skill['name']}]');
              systemPrompt.writeln(skill['body']);
              systemPrompt.writeln();
              injectedCount++;
            }
          }
        }

        // Format message history
        final apiMessages = <Map<String, String>>[];
        apiMessages.add({
          'role': 'system',
          'content': systemPrompt.toString().trim(),
        });

        // Limit history to the last 8 messages to fit in the context size (2048 tokens limit)
        final historyMessages = state.messages.length > 8
            ? state.messages.sublist(state.messages.length - 8)
            : state.messages;

        apiMessages.addAll(historyMessages.map((m) {
          return {
            'role': m.role.name,
            'content': m.content,
          };
        }));

        // Call Cloud or Local LLM Service
        final Map<String, dynamic> result;
        if (useCloud) {
          final provider = await SecureStorageService.instance.read('active_cloud_provider') ?? 'gemini';
          final apiKey = await SecureStorageService.instance.read(
            provider == 'openai' ? 'openai_api_key' : 'gemini_api_key',
          ) ?? '';
          if (apiKey.isEmpty) {
            throw Exception('API Key untuk ' + provider + ' kosong. Silakan isi di Settings.');
          }
          final modelName = await SecureStorageService.instance.read('openai_model') ?? 'gpt-4o-mini';

          final CloudInferenceEngine engine;
          if (provider == 'openai') {
            engine = OpenAIInferenceEngine(modelName: modelName);
          } else {
            engine = GeminiInferenceEngine();
          }

          // Format messages for cloud inference format
          final cloudMessages = apiMessages.map((m) {
            return {
              'role': m['role'],
              'content': m['content'],
            };
          }).toList();

          final responseText = await engine.generate(
            messages: cloudMessages,
            temperature: 0.7,
            maxTokens: 512,
            apiKey: apiKey,
          ).join('');

          result = {
            'content': responseText + (provider == 'openai' ? ' <!-- openai -->' : ' <!-- gemini -->'),
          };
        } else {
          result = await LocalLlmService.generateChatReply(
            baseUrl: state.baseUrl,
            apiType: state.apiType,
            model: state.activeModel,
            messages: apiMessages,
          );
        }

        final responseText = result['content'] as String;

        // Parse tool call
        final toolCallReq = toolRegistry.parseToolCall(responseText);

        if (toolCallReq == null) {
          // No tool-call -> final assistant response
          final assistantMsg = ChatMessage(
            id: 0,
            sessionId: state.activeSession!.id,
            role: MessageRole.assistant,
            content: EmojiParser.replaceShortcodes(responseText),
            timestamp: DateTime.now(),
          );

          final replySavedId = await _db.saveMessage(assistantMsg);
          final assistantMsgWithId = assistantMsg.copyWith(id: replySavedId);

          _storeMessageInMemory(assistantMsgWithId).ignore();

          state = state.copyWith(
            messages: [...state.messages, assistantMsgWithId],
            isLoading: false,
            lastPromptTokens: result['promptTokens'],
            lastCompletionTokens: result['completionTokens'],
            lastDurationMs: result['durationMs'],
          );
          break; // Done!
        }

        // We have a tool call!
        final tool = toolRegistry.getTool(toolCallReq.name);
        if (tool == null) {
          final errText = 'Error: tool "${toolCallReq.name}" tidak dikenal.';
          final obs = ChatMessage(
            id: 0,
            sessionId: state.activeSession!.id,
            role: MessageRole.tool,
            content: '[${toolCallReq.name}] $errText',
            timestamp: DateTime.now(),
            toolResult: errText,
          );
          final savedObsId = await _db.saveMessage(obs);
          state = state.copyWith(
            messages: [...state.messages, obs.copyWith(id: savedObsId)],
            isLoading: false,
          );
          break;
        }

        // Save tool-call call from assistant to history
        final assistantToolCallMsg = ChatMessage(
          id: 0,
          sessionId: state.activeSession!.id,
          role: MessageRole.assistant,
          content: responseText,
          timestamp: DateTime.now(),
        );
        final replySavedId = await _db.saveMessage(assistantToolCallMsg);
        state = state.copyWith(
          messages: [...state.messages, assistantToolCallMsg.copyWith(id: replySavedId)],
        );

        // Execute tool
        final enrichedArgs = Map<String, dynamic>.from(toolCallReq.arguments);
        enrichedArgs['sessionId'] = state.activeSession!.id;

        String toolResult;
        if (tool.name == 'clarify' && ClarifyTool.handler == null) {
          toolResult = 'Permintaan klarifikasi: ${toolCallReq.arguments['question']}. Silakan tanyakan langsung ke pengguna tanpa memanggil tool.';
        } else {
          try {
            toolResult = await tool.execute(enrichedArgs);
          } catch (e) {
            toolResult = 'Error eksekusi tool: ${e.toString()}';
          }
        }

        // Save tool result observation to history
        final obs = ChatMessage(
          id: 0,
          sessionId: state.activeSession!.id,
          role: MessageRole.tool,
          content: '[${tool.name}] $toolResult',
          timestamp: DateTime.now(),
          toolResult: toolResult,
        );
        final savedObsId = await _db.saveMessage(obs);
        state = state.copyWith(
          messages: [...state.messages, obs.copyWith(id: savedObsId)],
        );
      }
    } catch (e) {
      debugPrint('Error in desktop agent loop: $e');
      final errorMsg = ChatMessage(
        id: 0,
        sessionId: state.activeSession!.id,
        role: MessageRole.assistant,
        content: '⚠️ Error: ${e.toString()}',
        timestamp: DateTime.now(),
      );
      final savedErrorId = await _db.saveMessage(errorMsg);
      state = state.copyWith(
        messages: [...state.messages, errorMsg.copyWith(id: savedErrorId)],
        isLoading: false,
      );
    }
  }
}


final desktopChatProvider = StateNotifierProvider<DesktopChatNotifier, DesktopChatState>((ref) {
  return DesktopChatNotifier();
});
