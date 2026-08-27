import 'settings_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'model_provider.dart';
import 'memory_provider.dart';
import 'package:aura_core/aura_core.dart';

part 'inference_provider.g.dart';

/// Status of the text generation process
enum InferenceStatus {
  idle,
  generating,
  completed,
  cancelled,
  error,
}

/// Real-time performance metrics for local inference
class InferenceMetrics {
  const InferenceMetrics({
    this.tokensGenerated = 0,
    this.tokensPerSecond = 0.0,
    this.elapsedDuration = Duration.zero,
    this.timeToFirstToken,
  });

  final int tokensGenerated;
  final double tokensPerSecond;
  final Duration elapsedDuration;
  final Duration? timeToFirstToken;

  InferenceMetrics copyWith({
    int? tokensGenerated,
    double? tokensPerSecond,
    Duration? elapsedDuration,
    Duration? timeToFirstToken,
  }) {
    return InferenceMetrics(
      tokensGenerated: tokensGenerated ?? this.tokensGenerated,
      tokensPerSecond: tokensPerSecond ?? this.tokensPerSecond,
      elapsedDuration: elapsedDuration ?? this.elapsedDuration,
      timeToFirstToken: timeToFirstToken ?? this.timeToFirstToken,
    );
  }
}

/// State for the inference / generation provider
class InferenceState {
  const InferenceState({
    this.status = InferenceStatus.idle,
    this.prompt = '',
    this.text = '',
    this.metrics = const InferenceMetrics(),
    this.errorMessage,
    this.useCloudAssistant = false,
  });

  final InferenceStatus status;
  final String prompt;
  final String text;
  final InferenceMetrics metrics;
  final String? errorMessage;
  final bool useCloudAssistant;

  bool get isGenerating => status == InferenceStatus.generating;
  bool get isIdle => status == InferenceStatus.idle;
  bool get isCompleted => status == InferenceStatus.completed;
  bool get hasError => status == InferenceStatus.error;

  InferenceState copyWith({
    InferenceStatus? status,
    String? prompt,
    String? text,
    InferenceMetrics? metrics,
    String? errorMessage,
    bool? useCloudAssistant,
    bool clearError = false,
  }) {
    return InferenceState(
      status: status ?? this.status,
      prompt: prompt ?? this.prompt,
      text: text ?? this.text,
      metrics: metrics ?? this.metrics,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      useCloudAssistant: useCloudAssistant ?? this.useCloudAssistant,
    );
  }
}

/// Manages local LLM inference, streaming tokens, metrics, and cancellation.
@riverpod
class InferenceNotifier extends _$InferenceNotifier {
  StreamSubscription<String>? _streamSub;
  Stopwatch? _stopwatch;
  int _manualTokenCount = 0;
  http.Client? _desktopClient;

  @override
  InferenceState build() {
    ref.onDispose(() {
      _streamSub?.cancel();
      _stopwatch?.stop();
    });
    return const InferenceState();
  }

  void toggleCloudAssistant() {
    state = state.copyWith(useCloudAssistant: !state.useCloudAssistant);
  }

  void startManualMetrics() {
    _manualTokenCount = 0;
    _stopwatch = Stopwatch()..start();
    state = InferenceState(
      status: InferenceStatus.generating,
      metrics: const InferenceMetrics(),
    );
  }

  void onTokenReceived() {
    _manualTokenCount++;
    final elapsed = _stopwatch?.elapsed ?? Duration.zero;
    final elapsedSeconds = elapsed.inMilliseconds / 1000.0;
    final tps = elapsedSeconds > 0 ? (_manualTokenCount / elapsedSeconds) : 0.0;

    state = state.copyWith(
      status: InferenceStatus.generating,
      metrics: InferenceMetrics(
        tokensGenerated: _manualTokenCount,
        tokensPerSecond: tps,
        elapsedDuration: elapsed,
      ),
    );
  }

  void stopManualMetrics() {
    _stopwatch?.stop();
    final elapsed = _stopwatch?.elapsed ?? Duration.zero;
    final elapsedSeconds = elapsed.inMilliseconds / 1000.0;
    final finalTps = elapsedSeconds > 0 ? (_manualTokenCount / elapsedSeconds) : 0.0;

    state = state.copyWith(
      status: InferenceStatus.completed,
      metrics: InferenceMetrics(
        tokensGenerated: _manualTokenCount,
        tokensPerSecond: finalTps,
        elapsedDuration: elapsed,
      ),
    );
  }

  /// Format prompt according to model architecture (Gemma, Qwen, ChatML)
  String formatPrompt(String rawPrompt, {String? systemPrompt}) {
    final model = ref.read(modelProvider).activeModel;
    final modelName = model?.name.toLowerCase() ?? '';

    // Gemma 3 Prompt Format
    if (modelName.contains('gemma')) {
      final buffer = StringBuffer();
      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        buffer.writeln('<start_of_turn>user');
        buffer.writeln(systemPrompt);
        buffer.writeln('<end_of_turn>');
      }
      buffer.writeln('<start_of_turn>user');
      buffer.writeln(rawPrompt);
      buffer.writeln('<end_of_turn>');
      buffer.write('<start_of_turn>model\n');
      return buffer.toString();
    }

    // Qwen / ChatML Format (Default standard)
    final buffer = StringBuffer();
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      buffer.writeln('<|im_start|>system');
      buffer.writeln(systemPrompt);
      buffer.writeln('<|im_end|>');
    }
    buffer.writeln('<|im_start|>user');
    buffer.writeln(rawPrompt);
    buffer.writeln('<|im_end|>');
    buffer.write('<|im_start|>assistant\n');
    return buffer.toString();
  }

  /// Start streaming inference for a given prompt.
  /// Automatically recalls relevant memories and injects them into context.
  Future<void> generate({
    required String prompt,
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.7,
    double topP = 0.9,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async {
    final modelState = ref.read(modelProvider);
    final settings = ref.read(settingsProvider);
    if (!modelState.isReady || modelState.activeModel == null) {
      state = state.copyWith(
        status: InferenceStatus.error,
        errorMessage: 'Tidak ada model GGUF yang aktif. Silakan muat model terlebih dahulu.',
      );
      return;
    }

    // Cancel any previous stream
    await stop();

    // Recall relevant semantic memories for this prompt
    final memories = await ref.read(memoryProvider.notifier).recall(prompt, topK: 3);
    final memoryContext = await MemoryNotifier.formatMemoriesForPrompt(memories);

    // Inject memories into system prompt if available
    String effectiveSystemPrompt = systemPrompt ?? '';
    if (memoryContext.isNotEmpty) {
      effectiveSystemPrompt = memoryContext + (effectiveSystemPrompt.isNotEmpty ? '\n$effectiveSystemPrompt' : '');
    }

    // Cloud Routing Check (Fase 14)
    if (state.useCloudAssistant) {
      final apiKey = await SecureStorageService.instance.read(
        settings.activeCloudProvider == 'openai' ? 'openai_api_key' : 'gemini_api_key',
      ) ?? '';
      if (apiKey.isEmpty) {
        state = state.copyWith(
          status: InferenceStatus.error,
          errorMessage: 'API Key untuk ${settings.activeCloudProvider} kosong. Silakan isi di Pengaturan.',
        );
        return;
      }
      await _generateCloud(
        provider: settings.activeCloudProvider,
        apiKey: apiKey,
        prompt: prompt,
        systemPrompt: effectiveSystemPrompt,
        maxTokens: maxTokens,
        temperature: temperature,
        openaiModel: settings.openaiModel,
      );
      return;
    }

    // Hybrid Routing Check (Fase 12)
    bool isDesktopUsed = false;
    String desktopUrl = '';
    
    if (settings.useDesktopAssistant && settings.desktopIp.isNotEmpty) {
      desktopUrl = 'http://${settings.desktopIp}:${settings.desktopPort}';
      try {
        final pingRes = await http.get(
          Uri.parse('$desktopUrl/v1/models'),
          headers: {
            if (settings.desktopPin.isNotEmpty) 'Authorization': 'Bearer ${settings.desktopPin}',
          },
        ).timeout(const Duration(seconds: 2));
        if (pingRes.statusCode == 200) {
          isDesktopUsed = true;
        }
      } catch (_) {
        // Fail silent -> fallback to local
      }
    }

    if (isDesktopUsed) {
      await _generateDesktop(
        desktopUrl: desktopUrl,
        pin: settings.desktopPin,
        prompt: prompt,
        systemPrompt: effectiveSystemPrompt,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: topP,
      );
      return;
    }

    final formattedPrompt = formatPrompt(
      prompt,
      systemPrompt: effectiveSystemPrompt.isNotEmpty ? effectiveSystemPrompt : null,
    );

    state = InferenceState(
      status: InferenceStatus.generating,
      prompt: prompt,
      text: '',
      metrics: const InferenceMetrics(),
      useCloudAssistant: state.useCloudAssistant,
    );

    _stopwatch = Stopwatch()..start();
    int tokenCount = 0;
    Duration? timeToFirstToken;

    final controller = ref.read(modelProvider.notifier).controller;

    try {
      final tokenStream = controller.generate(
        prompt: formattedPrompt,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: topP,
        topK: topK,
        repeatPenalty: repeatPenalty,
      );

      final buffer = StringBuffer();

      _streamSub = tokenStream.listen(
        (token) {
          tokenCount++;
          if (tokenCount == 1 && _stopwatch != null) {
            timeToFirstToken = _stopwatch!.elapsed;
          }

          buffer.write(token);
          final elapsed = _stopwatch?.elapsed ?? Duration.zero;
          final elapsedSeconds = elapsed.inMilliseconds / 1000.0;
          final tps = elapsedSeconds > 0 ? (tokenCount / elapsedSeconds) : 0.0;

          final processedText = EmojiParser.replaceShortcodes(buffer.toString());

          state = state.copyWith(
            text: processedText,
            metrics: InferenceMetrics(
              tokensGenerated: tokenCount,
              tokensPerSecond: tps,
              elapsedDuration: elapsed,
              timeToFirstToken: timeToFirstToken,
            ),
          );
        },
        onDone: () {
          _stopwatch?.stop();
          final elapsed = _stopwatch?.elapsed ?? Duration.zero;
          final elapsedSeconds = elapsed.inMilliseconds / 1000.0;
          final finalTps = elapsedSeconds > 0 ? (tokenCount / elapsedSeconds) : 0.0;

          state = state.copyWith(
            status: InferenceStatus.completed,
            text: EmojiParser.replaceShortcodes(buffer.toString()),
            metrics: state.metrics.copyWith(
              tokensGenerated: tokenCount,
              tokensPerSecond: finalTps,
              elapsedDuration: elapsed,
            ),
          );
        },
        onError: (error) {
          _stopwatch?.stop();
          state = state.copyWith(
            status: InferenceStatus.error,
            errorMessage: 'Inference Error: ${error.toString()}',
          );
        },
        cancelOnError: true,
      );
    } catch (e) {
      _stopwatch?.stop();
      state = state.copyWith(
        status: InferenceStatus.error,
        errorMessage: 'Gagal memulai inferensi: ${e.toString()}',
      );
    }
  }

  /// Stop the ongoing inference immediately
  Future<void> stop() async {
    if (state.isGenerating) {
      try {
        final controller = ref.read(modelProvider.notifier).controller;
        await controller.stop();
      } catch (e) {
        debugPrint('Error stopping controller: $e');
      }

      await _streamSub?.cancel();
      _streamSub = null;
      _desktopClient?.close();
      _desktopClient = null;
      _stopwatch?.stop();

      state = state.copyWith(status: InferenceStatus.cancelled);
    }
  }

  /// Reset the inference state to idle
  void reset() {
    _streamSub?.cancel();
    _streamSub = null;
    _stopwatch?.stop();
    state = InferenceState(useCloudAssistant: state.useCloudAssistant);
  }

  Future<void> _generateCloud({
    required String provider,
    required String apiKey,
    required String prompt,
    required String systemPrompt,
    required int maxTokens,
    required double temperature,
    required String openaiModel,
  }) async {
    state = InferenceState(
      status: InferenceStatus.generating,
      prompt: prompt,
      text: '',
      metrics: const InferenceMetrics(),
      useCloudAssistant: state.useCloudAssistant,
    );

    _stopwatch = Stopwatch()..start();
    int tokenCount = 0;
    Duration? timeToFirstToken;
    final buffer = StringBuffer();

    // Cancel any previous stream/client
    _desktopClient?.close();
    _streamSub?.cancel();

    try {
      final messages = [
        if (systemPrompt.isNotEmpty)
          {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': prompt},
      ];

      final CloudInferenceEngine engine;
      if (provider == 'openai') {
        engine = OpenAIInferenceEngine(modelName: openaiModel);
      } else {
        engine = GeminiInferenceEngine();
      }

      final tokenStream = engine.generate(
        messages: messages,
        temperature: temperature,
        maxTokens: maxTokens,
        apiKey: apiKey,
      );

      _streamSub = tokenStream.listen(
        (token) {
          tokenCount++;
          if (tokenCount == 1 && _stopwatch != null) {
            timeToFirstToken = _stopwatch!.elapsed;
          }

          buffer.write(token);
          final elapsed = _stopwatch?.elapsed ?? Duration.zero;
          final elapsedSeconds = elapsed.inMilliseconds / 1000.0;
          final tps = elapsedSeconds > 0 ? (tokenCount / elapsedSeconds) : 0.0;

          final processedText = EmojiParser.replaceShortcodes(buffer.toString());

          state = state.copyWith(
            text: processedText,
            metrics: InferenceMetrics(
              tokensGenerated: tokenCount,
              tokensPerSecond: tps,
              elapsedDuration: elapsed,
              timeToFirstToken: timeToFirstToken,
            ),
          );
        },
        onDone: () {
          _stopwatch?.stop();
          final elapsed = _stopwatch?.elapsed ?? Duration.zero;
          final elapsedSeconds = elapsed.inMilliseconds / 1000.0;
          final finalTps = elapsedSeconds > 0 ? (tokenCount / elapsedSeconds) : 0.0;

          buffer.write(provider == 'openai' ? ' <!-- openai -->' : ' <!-- gemini -->');

          state = state.copyWith(
            status: InferenceStatus.completed,
            text: EmojiParser.replaceShortcodes(buffer.toString()),
            metrics: state.metrics.copyWith(
              tokensGenerated: tokenCount,
              tokensPerSecond: finalTps,
              elapsedDuration: elapsed,
            ),
          );
        },
        onError: (error) {
          _stopwatch?.stop();
          state = state.copyWith(
            status: InferenceStatus.error,
            errorMessage: 'Cloud Inference Error: ${error.toString()}',
          );
        },
        cancelOnError: true,
      );
    } catch (e) {
      _stopwatch?.stop();
      state = state.copyWith(
        status: InferenceStatus.error,
        errorMessage: 'Gagal memulai inferensi cloud: ${e.toString()}',
      );
    }
  }

  Future<void> _generateDesktop({
    required String desktopUrl,
    required String pin,
    required String prompt,
    required String systemPrompt,
    required int maxTokens,
    required double temperature,
    required double topP,
  }) async {
    state = InferenceState(
      status: InferenceStatus.generating,
      prompt: prompt,
      text: '',
      metrics: const InferenceMetrics(),
      useCloudAssistant: state.useCloudAssistant,
    );

    _stopwatch = Stopwatch()..start();
    int tokenCount = 0;
    Duration? timeToFirstToken;
    final buffer = StringBuffer();

    // Cancel any previous stream/client
    _desktopClient?.close();
    final client = http.Client();
    _desktopClient = client;

    try {
      final messages = [
        if (systemPrompt.isNotEmpty)
          {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': prompt},
      ];

      final request = http.Request('POST', Uri.parse('$desktopUrl/v1/chat/completions'));
      request.headers['Content-Type'] = 'application/json';
      if (pin.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $pin';
      }
      request.body = jsonEncode({
        'model': 'local-model',
        'messages': messages,
        'stream': true,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'top_p': topP,
      });

      final response = await client.send(request).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Server returned status code ${response.statusCode}');
      }

      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (_desktopClient == null || state.status == InferenceStatus.cancelled) {
          break;
        }
        if (line.startsWith('data: ')) {
          final dataStr = line.substring(6).trim();
          if (dataStr == '[DONE]') break;
          try {
            final Map<String, dynamic> data = jsonDecode(dataStr);
            final delta = data['choices']?[0]?['delta']?['content'] as String?;
            if (delta != null && delta.isNotEmpty) {
              tokenCount++;
              if (tokenCount == 1 && _stopwatch != null) {
                timeToFirstToken = _stopwatch!.elapsed;
              }

              buffer.write(delta);
              final elapsed = _stopwatch?.elapsed ?? Duration.zero;
              final elapsedSeconds = elapsed.inMilliseconds / 1000.0;
              final tps = elapsedSeconds > 0 ? (tokenCount / elapsedSeconds) : 0.0;

              final processedText = EmojiParser.replaceShortcodes(buffer.toString());

              state = state.copyWith(
                text: processedText,
                metrics: InferenceMetrics(
                  tokensGenerated: tokenCount,
                  tokensPerSecond: tps,
                  elapsedDuration: elapsed,
                  timeToFirstToken: timeToFirstToken,
                ),
              );
            }
          } catch (_) {}
        }
      }

      _stopwatch?.stop();
      final elapsed = _stopwatch?.elapsed ?? Duration.zero;
      final elapsedSeconds = elapsed.inMilliseconds / 1000.0;
      final finalTps = elapsedSeconds > 0 ? (tokenCount / elapsedSeconds) : 0.0;

      // Append hidden desktop annotation comment
      buffer.write(' <!-- desktop -->');

      state = state.copyWith(
        status: InferenceStatus.completed,
        text: EmojiParser.replaceShortcodes(buffer.toString()),
        metrics: state.metrics.copyWith(
          tokensGenerated: tokenCount,
          tokensPerSecond: finalTps,
          elapsedDuration: elapsed,
        ),
      );
    } catch (e) {
      _stopwatch?.stop();
      if (state.status != InferenceStatus.cancelled) {
        state = state.copyWith(
          status: InferenceStatus.error,
          errorMessage: 'Desktop Inference Error: ${e.toString()}',
        );
      }
    } finally {
      client.close();
      if (_desktopClient == client) {
        _desktopClient = null;
      }
    }
  }
}
