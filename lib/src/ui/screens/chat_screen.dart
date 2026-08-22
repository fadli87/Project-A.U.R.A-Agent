import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../providers/chat_provider.dart';
import '../../providers/model_provider.dart';
import '../../providers/inference_provider.dart';
import '../../storage/chat_models.dart';
// ignore: unused_import — akan digunakan di Fase 5 untuk tool permission dialog
import '../widgets/permission_approval_card.dart';
import '../theme/app_theme.dart';
import '../widgets/device_status_bar.dart';

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

    // Auto-scroll when new messages arrive or tokens stream in
    ref.listen(chatProvider, (_, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(modelState),
      body: SafeArea(
        child: Column(
          children: [
            const DeviceStatusBar(),
            Expanded(
              child: chatState.messages.isEmpty
                  ? _buildEmptyState()
                  : _buildMessageList(chatState),
            ),
            if (chatState.hasError)
              _buildErrorBanner(chatState.error!),
            _buildInputBar(chatState, modelState),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ModelState modelState) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => Navigator.of(context).pop(),
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
        // Generating indicator
        if (ref.watch(chatProvider).messages.any((m) => m.isStreaming))
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _GeneratingChip(),
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
    chatNotifier.beginAssistantResponse();

    if (!modelState.isReady || modelState.activeModel == null) {
      chatNotifier.appendToken(
        'Peringatan: Belum ada model GGUF yang dimuat. Silakan kembali ke layar utama dan pilih serta muat model terlebih dahulu.',
      );
      await chatNotifier.finalizeAssistantResponse();
      return;
    }

    final inferenceNotifier = ref.read(inferenceProvider.notifier);
    final formattedPrompt = inferenceNotifier.formatPrompt(text);
    final controller = ref.read(modelProvider.notifier).controller;

    try {
      final stream = controller.generate(
        prompt: formattedPrompt,
        maxTokens: 512,
      );

      await for (final token in stream) {
        chatNotifier.appendToken(token);
      }
    } catch (e) {
      chatNotifier.appendToken('\n[Error Inferensi: ${e.toString()}]');
    } finally {
      await chatNotifier.finalizeAssistantResponse();
    }
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

  @override
  Widget build(BuildContext context) {
    if (message.isTool) return _buildToolObservation();
    if (message.isUser) return _buildUserBubble();
    return _buildAssistantBubble();
  }

  Widget _buildUserBubble() {
    return Align(
      alignment: Alignment.centerRight,
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
    );
  }

  Widget _buildAssistantBubble() {
    return Align(
      alignment: Alignment.centerLeft,
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
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StreamingDot(delay: 0),
                    const SizedBox(width: 3),
                    _StreamingDot(delay: 150),
                    const SizedBox(width: 3),
                    _StreamingDot(delay: 300),
                    const SizedBox(width: 8),
                    const Text(
                      'Generating...',
                      style: TextStyle(
                        color: AppTheme.statusGenerating,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
          ],
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
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppTheme.statusGenerating,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Generating',
            style: TextStyle(
              color: AppTheme.statusGenerating,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
