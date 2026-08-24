import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../agent/agent_tools.dart';
import '../../providers/chat_provider.dart';
import '../../providers/model_provider.dart';
import '../../providers/inference_provider.dart';
import '../../providers/persona_provider.dart';
import '../../providers/settings_provider.dart';
import '../../storage/chat_models.dart';
import '../widgets/permission_approval_card.dart';
import '../theme/app_theme.dart';
import '../widgets/device_status_bar.dart';
import '../widgets/session_history_drawer.dart';
import 'settings_screen.dart';

/// Main chat interface with real-time token streaming
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _isComposing = false;

  // ── Agentic loop state ─────────────────────────────────────────────────────
  /// Counter iterasi loop per giliran percakapan (Rule 06-backup-safety-cap.md)
  int _agentIterationCount = 0;
  /// True selama loop tool-call sedang berjalan (untuk tampilkan indikator)
  bool _isAgentLooping = false;

  final AgentToolRegistry _toolRegistry = AgentToolRegistry();

  @override
  void initState() {
    super.initState();
    // Auto-start a new session if none is active
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chatState = ref.read(chatProvider);
      if (!chatState.hasSession) {
        final modelState = ref.read(modelProvider);
        await ref.read(chatProvider.notifier).startNewSession(
              modelName: modelState.activeModel?.name,
            );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final modelState = ref.watch(modelProvider);
    final isStreaming = chatState.messages.any((m) => m.isStreaming);

    // Auto-scroll when new messages arrive or tokens stream in
    ref.listen(chatProvider, (_, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(modelState),
      drawer: const SessionHistoryDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const DeviceStatusBar(),
            Expanded(
              child: chatState.messages.isEmpty
                  ? _buildEmptyState()
                  : _buildMessageList(chatState),
            ),
            if (_isAgentLooping)
              _buildAgentLoopIndicator(),
            if (isStreaming)
              _buildStopButton(),
            if (chatState.hasError)
              _buildErrorBanner(chatState.error!),
            _buildInputBar(chatState, modelState),
          ],
        ),
      ),
    );
  }

  Widget _buildStopButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: FilledButton.tonalIcon(
        onPressed: _stopGenerating,
        icon: const Icon(Icons.stop_circle_outlined, size: 16, color: AppTheme.error),
        label: const Text(
          'Hentikan Generasi',
          style: TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.cardElevated,
          side: BorderSide(color: AppTheme.error.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  Future<void> _stopGenerating() async {
    try {
      await ref.read(modelProvider.notifier).controller.stop();
      await ref.read(chatProvider.notifier).stopGeneration();
    } catch (_) {}
  }

  PreferredSizeWidget _buildAppBar(ModelState modelState) {
    return AppBar(
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.history_rounded, size: 20),
          tooltip: 'Riwayat Chat',
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AURA', style: TextStyle(fontSize: 16)),
          if (modelState.activeModel != null)
            Text(
              modelState.activeModel!.name,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
      actions: [
        // Live token count & speed metrics
        Consumer(
          builder: (context, ref, _) {
            final inferenceState = ref.watch(inferenceProvider);
            final metrics = inferenceState.metrics;
            if (inferenceState.isGenerating || metrics.tokensGenerated > 0) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.cardElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed, size: 13, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${metrics.tokensGenerated} token (${metrics.tokensPerSecond.toStringAsFixed(1)} t/s)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        IconButton(
          icon: const Icon(Icons.add_comment_outlined, size: 20),
          tooltip: 'Chat Baru',
          onPressed: () async {
            final modelState = ref.read(modelProvider);
            await ref.read(chatProvider.notifier).startNewSession(
                  modelName: modelState.activeModel?.name,
                );
            ref.invalidate(allSessionsProvider);
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, size: 20),
          onPressed: _showChatOptions,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 20),
          const Text(
            'Halo! Saya AURA',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'AI pribadi yang berjalan 100% offline\ndi perangkat Anda',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          _buildSuggestedPrompts(),
        ],
      ),
    );
  }

  Widget _buildSuggestedPrompts() {
    final suggestions = [
      'Bantu saya buat daftar tugas hari ini',
      'Apa itu machine learning?',
      'Cek status koneksi jaringan saya',
    ];

    return Column(
      children: suggestions.map((s) {
        return GestureDetector(
          onTap: () => _sendMessage(s),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 14, color: AppTheme.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textMuted),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMessageList(ChatState chatState) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        final message = chatState.messages[index];
        return _ChatBubble(
          message: message,
          key: ValueKey(message.id),
        );
      },
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: AppTheme.error, fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: () => ref
                .read(chatProvider.notifier)
                .setError(''),
            child: Icon(Icons.close, color: AppTheme.error, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ChatState chatState, ModelState modelState) {
    final canSend = modelState.isReady &&
        !chatState.messages.any((m) => m.isStreaming) &&
        _isComposing;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocusNode,
              maxLines: 5,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (v) => setState(() => _isComposing = v.trim().isNotEmpty),
              onSubmitted: canSend ? (_) => _sendCurrentMessage() : null,
              decoration: InputDecoration(
                hintText: modelState.isReady
                    ? 'Ketik pesan...'
                    : 'Muat model terlebih dahulu',
                hintStyle: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: IconButton.filled(
              onPressed: canSend ? _sendCurrentMessage : null,
              icon: const Icon(Icons.send_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor:
                    canSend ? AppTheme.primary : AppTheme.border,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendCurrentMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    setState(() => _isComposing = false);
    await _sendMessage(text);
  }

  Future<void> _sendMessage(String text) async {
    final chatNotifier = ref.read(chatProvider.notifier);
    final modelState = ref.read(modelProvider);

    // Ensure session exists
    if (!ref.read(chatProvider).hasSession) {
      await chatNotifier.startNewSession(
        modelName: modelState.activeModel?.name,
      );
    }

    await chatNotifier.addUserMessage(text);

    if (!modelState.isReady || modelState.activeModel == null) {
      chatNotifier.beginAssistantResponse();
      chatNotifier.appendToken(
        'Peringatan: Belum ada model GGUF yang dimuat. Silakan kembali ke layar utama dan pilih serta muat model terlebih dahulu.',
      );
      await chatNotifier.finalizeAssistantResponse();
      return;
    }

    await _executeAgentLoop(text);
  }

  // ─── Agentic Loop (Rule 06-backup-safety-cap.md) ────────────────────────────

  /// Menjalankan reasoning → tool-call → observasi → loop ulang.
  /// Berhenti jika: (a) tidak ada tool-call dalam output model (jawaban final),
  /// (b) counter mencapai maxAgentIterations (safety cap), atau
  /// (c) tool sensitif ditolak user.
  Future<void> _executeAgentLoop(String initialUserText) async {
    final chatNotifier = ref.read(chatProvider.notifier);
    final inferenceNotifier = ref.read(inferenceProvider.notifier);
    final personaNotifier = ref.read(personaProvider.notifier);
    final maxIterations =
        ref.read(settingsProvider).maxAgentIterations;
    final controller = ref.read(modelProvider.notifier).controller;

    // Reset counter untuk giliran baru
    _agentIterationCount = 0;
    if (mounted) setState(() => _isAgentLooping = false);

    // Context akumulasi untuk iterasi selanjutnya
    // Kita re-build prompt dari conversation history tiap iterasi
    String currentUserQuery = initialUserText;

    while (_agentIterationCount < maxIterations) {
      _agentIterationCount++;
      final isFirstIteration = _agentIterationCount == 1;

      // Tampilkan indikator hanya saat sudah masuk loop ke-2+
      if (!isFirstIteration && mounted) {
        setState(() => _isAgentLooping = true);
      }

      // Bangun system prompt dengan persona + tools + skills
      final systemPrompt = personaNotifier.assembleSystemPrompt(currentUserQuery);

      // Begin streaming assistant response bubble
      chatNotifier.beginAssistantResponse();
      inferenceNotifier.startManualMetrics();

      final buffer = StringBuffer();

      try {
        final formattedPrompt = inferenceNotifier.formatPrompt(
          currentUserQuery,
          systemPrompt: systemPrompt,
        );

        final stream = controller.generate(
          prompt: formattedPrompt,
          maxTokens: 512,
        );

        await for (final token in stream) {
          buffer.write(token);
          chatNotifier.appendToken(token);
          inferenceNotifier.onTokenReceived();
        }
      } catch (e) {
        chatNotifier.appendToken('\n[Error Inferensi: ${e.toString()}]');
        inferenceNotifier.stopManualMetrics();
        await chatNotifier.finalizeAssistantResponse();
        break;
      }

      inferenceNotifier.stopManualMetrics();
      await chatNotifier.finalizeAssistantResponse();

      // ── Cek apakah output mengandung tool-call ──────────────────────────────
      final fullResponse = buffer.toString();
      final toolCallReq = _toolRegistry.parseToolCall(fullResponse);

      if (toolCallReq == null) {
        // Tidak ada tool-call → ini jawaban final, loop selesai
        break;
      }

      // ── Ada tool-call: handle permission lalu execute ───────────────────────
      final tool = _toolRegistry.getTool(toolCallReq.name);
      if (tool == null) {
        // Tool tidak dikenal → hentikan loop dengan pesan
        await chatNotifier.addToolObservation(
          toolCallReq.name,
          'Error: tool "${toolCallReq.name}" tidak dikenal.',
        );
        break;
      }

      if (tool.isSensitive) {
        // Sensitive tool: tampilkan PermissionApprovalCard, tunggu user
        if (!mounted) break;
        final allowed = await PermissionApprovalCard.show(
          context,
          toolName: tool.name,
          toolDescription: tool.description,
          parameters: toolCallReq.arguments,
        );

        if (!allowed) {
          // User menolak → hentikan loop, tampilkan pesan
          await chatNotifier.addToolObservation(
            tool.name,
            'Aksi dibatalkan oleh pengguna.',
          );
          break;
        }
      }

      // Execute tool (aman atau sudah diizinkan)
      String toolResult;
      try {
        toolResult = await tool.execute(toolCallReq.arguments);
      } catch (e) {
        toolResult = 'Error eksekusi tool: ${e.toString()}';
      }

      // Tambahkan observasi ke chat dan jadikan konteks untuk iterasi berikutnya
      await chatNotifier.addToolObservation(tool.name, toolResult);
      currentUserQuery =
          'Hasil dari tool ${tool.name}: $toolResult\n\nLanjutkan berdasarkan hasil ini.';
    }

    // ── Safety cap tercapai ──────────────────────────────────────────────────
    if (_agentIterationCount >= maxIterations) {
      chatNotifier.beginAssistantResponse();
      chatNotifier.appendToken(
        '⚠️ Saya belum bisa menyelesaikan ini dalam batas $_agentIterationCount langkah '
        'yang wajar. Ini yang sudah saya temukan sejauh ini — silakan prompt ulang '
        'dengan konteks yang lebih spesifik jika ingin melanjutkan.',
      );
      await chatNotifier.finalizeAssistantResponse();
    }

    if (mounted) setState(() => _isAgentLooping = false);
  }

  // ─── Indikator progres agentic loop ─────────────────────────────────────────

  Widget _buildAgentLoopIndicator() {
    final maxIterations =
        ref.read(settingsProvider).maxAgentIterations;
    final isNearCap = _agentIterationCount >= (maxIterations - 2);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isNearCap
            ? AppTheme.warning.withValues(alpha: 0.12)
            : AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isNearCap
              ? AppTheme.warning.withValues(alpha: 0.5)
              : AppTheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: isNearCap ? AppTheme.warning : AppTheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Langkah $_agentIterationCount dari maks $maxIterations',
            style: TextStyle(
              color: isNearCap ? AppTheme.warning : AppTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _showChatOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined,
                  color: AppTheme.textSecondary),
              title: const Text('Pengaturan'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.error),
              title: const Text('Hapus percakapan ini'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: AppTheme.textSecondary),
              title: const Text('Info model aktif'),
              onTap: () {
                Navigator.pop(ctx);
                final model = ref.read(modelProvider).activeModel;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(model?.name ?? 'Tidak ada model aktif')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chat Bubble ─────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, super.key});

  final ChatMessage message;

  void _copyToClipboard(BuildContext context) {
    if (message.content.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pesan disalin ke clipboard'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message.isTool) return _buildToolObservation();
    if (message.isUser) return _buildUserBubble(context);
    return _buildAssistantBubble(context);
  }

  Widget _buildUserBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onLongPress: () => _copyToClipboard(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: AppTheme.bubbleUser,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: AppTheme.bubbleUserBorder),
          ),
          child: Text(
            message.content,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _copyToClipboard(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: AppTheme.bubbleAssistant,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: AppTheme.bubbleAssistantBorder),
          ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: message.content.isEmpty && message.isStreaming
                  ? '▊' // blinking cursor placeholder
                  : message.content,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  height: 1.6,
                ),
                code: const TextStyle(
                  color: AppTheme.secondary,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                codeblockDecoration: BoxDecoration(
                  color: AppTheme.cardElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                h1: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                h2: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                blockquotePadding: const EdgeInsets.all(8),
                blockquoteDecoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  border: Border(
                    left: BorderSide(color: AppTheme.primary, width: 3),
                  ),
                ),
              ),
            ),
            if (message.isStreaming)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Consumer(
                  builder: (context, ref, _) {
                    final metrics = ref.watch(inferenceProvider).metrics;
                    // Max tokens default is 512, calculate percentage progress
                    final maxTokens = 512;
                    final progressRatio = (metrics.tokensGenerated / maxTokens).clamp(0.0, 1.0);
                    final percentage = (progressRatio * 100).toInt();

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.cardElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Donut Progress Indicator
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              value: progressRatio > 0 ? progressRatio : null,
                              strokeWidth: 2.8,
                              backgroundColor: AppTheme.border,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$percentage% • ${metrics.tokensGenerated} token (${metrics.tokensPerSecond.toStringAsFixed(1)} t/s)',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildToolObservation() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.terminal, color: AppTheme.secondary, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.content,
              style: TextStyle(
                color: AppTheme.secondary,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Streaming dot animation ──────────────────────────────────────────────────

class _StreamingDot extends StatefulWidget {
  const _StreamingDot({required this.delay});
  final int delay;

  @override
  State<_StreamingDot> createState() => _StreamingDotState();
}

class _StreamingDotState extends State<_StreamingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(
          color: AppTheme.statusGenerating,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Generating chip ─────────────────────────────────────────────────────────

class _GeneratingChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.statusGenerating.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.statusGenerating.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.statusGenerating,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Generating...',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.statusGenerating,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
