import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'model_provider.dart';
import 'memory_provider.dart';

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
  });

  final InferenceStatus status;
  final String prompt;
  final String text;
  final InferenceMetrics metrics;
  final String? errorMessage;

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
    bool clearError = false,
  }) {
    return InferenceState(
      status: status ?? this.status,
      prompt: prompt ?? this.prompt,
      text: text ?? this.text,
      metrics: metrics ?? this.metrics,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Manages local LLM inference, streaming tokens, metrics, and cancellation.
@riverpod
class InferenceNotifier extends _$InferenceNotifier {
  StreamSubscription<String>? _streamSub;
  Stopwatch? _stopwatch;
  int _manualTokenCount = 0;

  @override
  InferenceState build() {
    ref.onDispose(() {
      _streamSub?.cancel();
      _stopwatch?.stop();
    });
    return const InferenceState();
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
    final memoryContext = MemoryNotifier.formatMemoriesForPrompt(memories);

    // Inject memories into system prompt if available
    String effectiveSystemPrompt = systemPrompt ?? '';
    if (memoryContext.isNotEmpty) {
      effectiveSystemPrompt = memoryContext + (effectiveSystemPrompt.isNotEmpty ? '\n$effectiveSystemPrompt' : '');
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

          state = state.copyWith(
            text: buffer.toString(),
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
      _stopwatch?.stop();

      state = state.copyWith(status: InferenceStatus.cancelled);
    }
  }

  /// Reset the inference state to idle
  void reset() {
    _streamSub?.cancel();
    _streamSub = null;
    _stopwatch?.stop();
    state = const InferenceState();
  }
}
