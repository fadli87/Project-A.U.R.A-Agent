import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_lib;
import 'package:aura_core/aura_core.dart';
import 'src/providers/desktop_chat_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SQLite database
  final docsDir = await getApplicationDocumentsDirectory();
  ChatDatabase.init(path_lib.join(docsDir.path, 'aura_chat_desktop.db'));

  // Initialize ObjectBox store
  await ObjectBoxStore.open(directoryPath: docsDir.path);

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
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
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
    String selectedApiType = state.apiType;
    String selectedModel = state.activeModel;
    bool isTesting = false;
    String testResult = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E26),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              title: Row(
                children: [
                  const Icon(Icons.settings, color: Color(0xFF7C4DFF)),
                  const SizedBox(width: 12),
                  const Text('Settings Local LLM Server', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 450,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pilih API Type & URL sesuai server LLM lokal Anda (Ollama / LM Studio).',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      
                      // API Type Dropdown
                      const Text('API Type', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF13131A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedApiType,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E1E26),
                            items: const [
                              DropdownMenuItem(value: 'Ollama', child: Text('Ollama')),
                              DropdownMenuItem(value: 'OpenAI-Compatible', child: Text('OpenAI-Compatible (LM Studio / llama-server)')),
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
                      
                      // Base URL
                      const Text('Base URL', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: urlController,
                        decoration: InputDecoration(
                          hintText: 'e.g. http://localhost:11434',
                          fillColor: const Color(0xFF13131A),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Model selection
                      const Text('Active Model', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      if (state.availableModels.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF13131A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: state.availableModels.contains(selectedModel) ? selectedModel : state.availableModels.first,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1E1E26),
                              items: state.availableModels.map((modelName) {
                                return DropdownMenuItem(value: modelName, child: Text(modelName));
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
                          decoration: InputDecoration(
                            hintText: 'e.g. gemma:2b',
                            fillColor: const Color(0xFF13131A),
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 20),
                      
                      // Test Connection Button & Result
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.08),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: isTesting 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                              : const Icon(Icons.bolt, size: 18),
                            label: const Text('Test & Discover Models'),
                            onPressed: isTesting ? null : () async {
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
                  ),
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
                    await notifier.updateSettings(
                      baseUrl: urlController.text.trim(),
                      apiType: selectedApiType,
                      activeModel: state.availableModels.isNotEmpty ? selectedModel : modelController.text.trim(),
                    );
                    navigator.pop();
                  },
                  child: const Text('Save & Apply'),
                ),
              ],
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
                
                // New Chat Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: InkWell(
                    onTap: chatNotifier.createNewSession,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.3)),
                        gradient: LinearGradient(
                          colors: [const Color(0xFF7C4DFF).withOpacity(0.15), Colors.transparent],
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
                          child: ListTile(
                            hoverColor: Colors.white.withOpacity(0.03),
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
                                  color: Colors.green.withOpacity(0.5),
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
          
          // Main Chat Area
          Expanded(
            child: Container(
              color: const Color(0xFF13131A),
              child: Column(
                children: [
                  // Top Header Bar
                  Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A24),
                      border: Border.all(color: Colors.white.withOpacity(0.03)),
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
                              ? const Color(0xFF00BFA5).withOpacity(0.1) 
                              : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: chatState.isServerConnected 
                                ? const Color(0xFF00BFA5).withOpacity(0.3) 
                                : Colors.white.withOpacity(0.1),
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
                                Icon(Icons.forum_outlined, size: 48, color: Colors.white.withOpacity(0.15)),
                                const SizedBox(height: 16),
                                Text(
                                  'Belum ada obrolan.',
                                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 15),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Hubungkan local LLM server di settings dan mulailah mengobrol!',
                                  style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12),
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
                                                color: Colors.black.withOpacity(0.05),
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
                                              style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10),
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
                      border: Border.all(color: Colors.white.withOpacity(0.03)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF13131A),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: _messageController,
                              maxLines: null,
                              decoration: const InputDecoration(
                                hintText: 'Tulis pesan obrolan di sini...',
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: Colors.grey, fontSize: 13.5),
                              ),
                              style: const TextStyle(fontSize: 14),
                              onSubmitted: (_) {
                                final text = _messageController.text;
                                if (text.trim().isNotEmpty && !chatState.isLoading) {
                                  chatNotifier.sendMessage(text);
                                  _messageController.clear();
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Send Button
                        InkWell(
                          onTap: chatState.isLoading ? null : () {
                            final text = _messageController.text;
                            if (text.trim().isNotEmpty) {
                              chatNotifier.sendMessage(text);
                              _messageController.clear();
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: chatState.isLoading ? Colors.white.withOpacity(0.05) : const Color(0xFF7C4DFF),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: chatState.isLoading ? null : [
                                BoxShadow(
                                  color: const Color(0xFF7C4DFF).withOpacity(0.4),
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
