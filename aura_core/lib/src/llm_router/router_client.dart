import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../../storage/chat_models.dart';
import 'combo_strategy.dart';
import 'format_translator.dart';
import 'model_resolver.dart';
import 'retry_backoff.dart';
import 'stall_detection.dart';

/// Alasan pemicu fallback dari cloud ke model lokal (GGUF).
enum FallbackTrigger {
  none,
  offline,
  authFailure,
  quotaExhausted,
  comboExhausted,
  stallTimeout,
}

/// Keputusan apakah inferensi harus menyerah dari cloud dan beralih ke lokal GGUF.
///
/// Logika ini terpisah dari [ErrorClassification.shouldFallback] (yang hanya
/// mengatur rotasi antar-model di dalam cloud combo).
class LocalFallbackDecision {
  /// True jika harus segera menghentikan cloud dan beralih ke model lokal GGUF.
  final bool shouldFallback;

  /// Alasan teknis internal (untuk logging dan debugging).
  final String reason;

  /// Pesan yang ramah pengguna untuk ditampilkan di bubble chat / banner UI (Rule 17).
  final String userFacingMessage;

  /// Kategori pemicu fallback.
  final FallbackTrigger trigger;

  const LocalFallbackDecision({
    required this.shouldFallback,
    required this.reason,
    required this.userFacingMessage,
    required this.trigger,
  });

  @override
  String toString() =>
      'LocalFallbackDecision(shouldFallback: $shouldFallback, trigger: $trigger, message: "$userFacingMessage")';
}

/// Exception khusus yang dilempar saat evaluasi fallback ke lokal diputuskan.
class LocalFallbackException implements Exception {
  final LocalFallbackDecision decision;
  final Object? originalError;

  const LocalFallbackException(this.decision, {this.originalError});

  @override
  String toString() =>
      'LocalFallbackException(${decision.reason}): ${decision.userFacingMessage}';
}

/// Event yang di-yield dari [LlmRouterClient.streamGenerate] — bisa berupa
/// teks token, tool call yang perlu dieksekusi, atau sinyal selesai.
sealed class RouterStreamEvent {
  const RouterStreamEvent();
}

/// Token teks tambahan dari respon streaming LLM.
class RouterTextDelta extends RouterStreamEvent {
  final String text;
  const RouterTextDelta(this.text);

  @override
  String toString() => 'RouterTextDelta("$text")';
}

/// Pemanggilan tool/function yang diminta oleh model.
class RouterToolCall extends RouterStreamEvent {
  final String id;
  final String name;
  final String argumentsJson;

  const RouterToolCall({
    required this.id,
    required this.name,
    required this.argumentsJson,
  });

  @override
  String toString() =>
      'RouterToolCall(id: $id, name: $name, args: $argumentsJson)';
}

/// Sinyal bahwa streaming respon telah selesai.
class RouterStreamDone extends RouterStreamEvent {
  final String? finishReason;
  const RouterStreamDone({this.finishReason});

  @override
  String toString() => 'RouterStreamDone(finishReason: $finishReason)';
}

/// Evaluasi apakah error cloud harus memicu fallback otomatis ke model lokal GGUF.
///
/// [error]: Exception mentah yang ditangkap.
/// [attemptIndex]: Index percobaan saat ini (0-indexed).
/// [totalModelsInCombo]: Total kandidat model yang tersedia dalam combo saat ini.
/// [statusCode]: HTTP status code jika ada respon HTTP.
/// [errorText]: Body / pesan error mentah dari provider.
LocalFallbackDecision evaluateLocalFallback({
  required Object error,
  required int attemptIndex,
  required int totalModelsInCombo,
  int? statusCode,
  String? errorText,
  bool allProvidersInCooldown = false,
}) {
  // 0. Jika seluruh provider dalam combo sedang cooldown aktif
  if (allProvidersInCooldown) {
    return const LocalFallbackDecision(
      shouldFallback: true,
      reason: 'All cloud providers in combo are currently in cooldown',
      userFacingMessage:
          '☁️→📱 Seluruh layanan cloud sedang masa cooldown kuota, beralih ke model lokal',
      trigger: FallbackTrigger.quotaExhausted,
    );
  }

  // 1. Device Offline / Jaringan Terputus seketika
  if (error is SocketException ||
      error.toString().contains('SocketException') ||
      error.toString().contains('Failed host lookup') ||
      error.toString().contains('Network is unreachable') ||
      error.toString().contains('Connection refused')) {
    return const LocalFallbackDecision(
      shouldFallback: true,
      reason: 'Network unreachable / device offline',
      userFacingMessage: '☁️→📱 Koneksi internet terputus, beralih ke model lokal',
      trigger: FallbackTrigger.offline,
    );
  }

  final isLastModelInCombo = (attemptIndex + 1) >= totalModelsInCombo;
  final lowerError = errorText?.toLowerCase() ?? '';

  // 2. Auth Failure (HTTP 401 / 403)
  final isAuthFailure = statusCode == 401 || statusCode == 403;
  if (isAuthFailure && isLastModelInCombo) {
    return const LocalFallbackDecision(
      shouldFallback: true,
      reason: 'Invalid or rejected API key',
      userFacingMessage: '☁️→📱 API Key cloud ditolak atau tidak valid, beralih ke model lokal',
      trigger: FallbackTrigger.authFailure,
    );
  }

  // 3. Quota / Rate Limit (HTTP 429 atau pesan kuota)
  final isQuotaError = statusCode == 429 ||
      lowerError.contains('quota') ||
      lowerError.contains('rate limit') ||
      lowerError.contains('resource_exhausted');
  if (isQuotaError && isLastModelInCombo) {
    return const LocalFallbackDecision(
      shouldFallback: true,
      reason: 'Rate limit or quota exhausted across combo',
      userFacingMessage: '☁️→📱 Kuota cloud gratis habis untuk saat ini, beralih ke model lokal',
      trigger: FallbackTrigger.quotaExhausted,
    );
  }

  // 4. Stall Timeout pada model terakhir
  if (error is StallTimeoutException && isLastModelInCombo) {
    return const LocalFallbackDecision(
      shouldFallback: true,
      reason: 'Stall timeout reached on last combo model',
      userFacingMessage: '☁️→📱 Respon cloud terhenti terlalu lama, beralih ke model lokal',
      trigger: FallbackTrigger.stallTimeout,
    );
  }

  // 5. Seluruh model dalam combo sudah habis dicoba
  if (isLastModelInCombo) {
    return const LocalFallbackDecision(
      shouldFallback: true,
      reason: 'All models in combo failed',
      userFacingMessage: '☁️→📱 Seluruh layanan cloud sibuk/gagal, beralih ke model lokal',
      trigger: FallbackTrigger.comboExhausted,
    );
  }

  // Masih ada model berikutnya di dalam combo
  return const LocalFallbackDecision(
    shouldFallback: false,
    reason: 'Try next model in combo',
    userFacingMessage: '',
    trigger: FallbackTrigger.none,
  );
}

/// Konversi format chat internal A.U.R.A ([ChatMessage]) ke format OpenAI Chat Completions.
///
/// Catatan: Ini adalah implementasi baru untuk model internal A.U.R.A,
/// BUKAN port dari 9router-go.
List<Map<String, dynamic>> convertAuraToOpenAIMessages(
  List<ChatMessage> messages, {
  String? systemPrompt,
}) {
  final result = <Map<String, dynamic>>[];
  if (systemPrompt != null && systemPrompt.isNotEmpty) {
    result.add({'role': 'system', 'content': systemPrompt});
  }

  for (final msg in messages) {
    switch (msg.role) {
      case MessageRole.user:
        result.add({'role': 'user', 'content': msg.content});
        break;

      case MessageRole.assistant:
        final map = <String, dynamic>{'role': 'assistant', 'content': msg.content};
        if (msg.toolCallJson != null && msg.toolCallJson!.isNotEmpty) {
          try {
            final decoded = jsonDecode(msg.toolCallJson!);
            map['tool_calls'] = decoded is List ? decoded : [decoded];
          } catch (_) {}
        }
        result.add(map);
        break;

      case MessageRole.tool:
        result.add({
          'role': 'tool',
          'tool_call_id': msg.toolCallId ?? '',
          'content': msg.toolResult ?? msg.content,
        });
        break;

      case MessageRole.system:
        result.add({'role': 'system', 'content': msg.content});
        break;
    }
  }
  return result;
}

/// Konversi format chat internal A.U.R.A ([ChatMessage]) ke format Gemini v1beta payload.
///
/// Catatan: Ini adalah implementasi baru untuk model internal A.U.R.A,
/// BUKAN port dari 9router-go.
Map<String, dynamic> convertAuraToGeminiPayload(
  List<ChatMessage> messages, {
  String? systemPrompt,
  double temperature = 0.7,
  int maxTokens = 1024,
}) {
  final contents = <Map<String, dynamic>>[];

  for (final msg in messages) {
    switch (msg.role) {
      case MessageRole.system:
        continue; // Disajikan terpisah via systemInstruction

      case MessageRole.tool:
        contents.add({
          'role': 'user',
          'parts': [
            {
              'functionResponse': {
                'name': msg.toolName ?? msg.toolCallId ?? 'tool',
                'response': {'result': msg.toolResult ?? msg.content},
              }
            }
          ],
        });
        break;

      case MessageRole.assistant:
        if (msg.toolCallJson != null && msg.toolCallJson!.isNotEmpty) {
          try {
            final decoded = jsonDecode(msg.toolCallJson!);
            final parts = <Map<String, dynamic>>[];
            if (msg.content.isNotEmpty) {
              parts.add({'text': msg.content});
            }
            if (decoded is List) {
              for (final tc in decoded) {
                if (tc is Map && tc['function'] is Map) {
                  final fn = tc['function'] as Map;
                  final args = fn['arguments'] is String
                      ? jsonDecode(fn['arguments'] as String)
                      : fn['arguments'];
                  parts.add({
                    'functionCall': {'name': fn['name'], 'args': args}
                  });
                }
              }
            } else if (decoded is Map) {
              final fn = decoded['function'] is Map ? decoded['function'] as Map : decoded;
              final args = fn['arguments'] is String
                  ? jsonDecode(fn['arguments'] as String)
                  : fn['arguments'];
              parts.add({
                'functionCall': {'name': fn['name'] ?? 'tool', 'args': args ?? {}}
              });
            }
            if (parts.isNotEmpty) {
              contents.add({'role': 'model', 'parts': parts});
              break;
            }
          } catch (_) {
            // Fallback ke plain text jika JSON parse gagal
          }
        }
        contents.add({
          'role': 'model',
          'parts': [{'text': msg.content}],
        });
        break;

      case MessageRole.user:
        contents.add({
          'role': 'user',
          'parts': [{'text': msg.content}],
        });
        break;
    }
  }

  return {
    'contents': contents,
    if (systemPrompt != null && systemPrompt.isNotEmpty)
      'systemInstruction': {
        'parts': [{'text': systemPrompt}]
      },
    'generationConfig': {
      'temperature': temperature,
      'maxOutputTokens': maxTokens,
    },
  };
}

/// Client orkestrasi routing LLM multi-provider dengan dukungan stall-detection,
/// retry/backoff, per-provider cooldown tracking, dan fallback otomatis ke lokal GGUF.
class LlmRouterClient {
  final http.Client httpClient;
  final Duration defaultStallTimeout;
  final Duration reasoningStallTimeout;
  final ComboStrategyManager comboManager;
  final ModelResolver modelResolver;

  /// Cooldown aktif per-provider (mis. 'gemini', 'openai', 'groq')
  final Map<String, DateTime> _cooldownUntilByProvider = {};

  /// Backoff level saat ini per-provider untuk exponential backoff
  final Map<String, int> _backoffLevelsByProvider = {};

  LlmRouterClient({
    http.Client? httpClient,
    this.defaultStallTimeout = const Duration(seconds: 30),
    this.reasoningStallTimeout = const Duration(seconds: 60),
    ComboStrategyManager? comboManager,
    ModelResolver? modelResolver,
  })  : httpClient = httpClient ?? http.Client(),
        comboManager = comboManager ?? ComboStrategyManager(),
        modelResolver = modelResolver ?? const ModelResolver();

  /// Apakah provider sedang dalam masa cooldown (misal karena HTTP 429 atau kuota habis).
  bool isProviderInCooldown(String provider) {
    final expiry = _cooldownUntilByProvider[provider];
    if (expiry == null) return false;
    if (DateTime.now().isAfter(expiry)) {
      _cooldownUntilByProvider.remove(provider);
      return false;
    }
    return true;
  }

  /// Waktu berakhirnya cooldown untuk provider tertentu, jika sedang aktif.
  DateTime? getCooldownExpiry(String provider) {
    if (isProviderInCooldown(provider)) {
      return _cooldownUntilByProvider[provider];
    }
    return null;
  }

  /// Reset status cooldown untuk provider tertentu.
  void clearCooldown(String provider) {
    _cooldownUntilByProvider.remove(provider);
    _backoffLevelsByProvider.remove(provider);
  }

  /// Reset semua cooldown.
  void clearAllCooldowns() {
    _cooldownUntilByProvider.clear();
    _backoffLevelsByProvider.clear();
  }

  /// Mendapatkan endpoint URL default untuk provider tertentu.
  Uri getProviderEndpoint(String provider, {String? model}) {
    switch (provider.toLowerCase()) {
      case 'gemini':
      case 'gc':
      case 'google':
        final m = model ?? 'gemini-2.5-flash';
        return Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$m:streamGenerateContent?alt=sse',
        );
      case 'openai':
      case 'oa':
        return Uri.parse('https://api.openai.com/v1/chat/completions');
      case 'groq':
      case 'gq':
        return Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      case 'deepseek':
      case 'ds':
        return Uri.parse('https://api.deepseek.com/chat/completions');
      case 'openrouter':
      case 'or':
        return Uri.parse('https://openrouter.ai/api/v1/chat/completions');
      case 'anthropic':
      case 'ant':
      case 'claude':
        return Uri.parse('https://api.anthropic.com/v1/messages');
      default:
        // Default ke OpenAI-compatible format
        return Uri.parse('https://api.openai.com/v1/chat/completions');
    }
  }

  /// Melakukan validasi API key ringan untuk provider tertentu.
  Future<bool> validateKey(String provider, String apiKey) async {
    final key = apiKey.trim();
    if (key.isEmpty) return false;

    try {
      final p = modelResolver.resolveProviderAlias(provider);
      if (p == 'gemini') {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models',
        );
        final res = await httpClient
            .get(url, headers: {'x-goog-api-key': key})
            .timeout(const Duration(seconds: 10));
        return res.statusCode == 200;
      } else if (p == 'anthropic' || p == 'claude') {
        final url = Uri.parse('https://api.anthropic.com/v1/models');
        final res = await httpClient.get(url, headers: {
          'x-api-key': key,
          'anthropic-version': '2023-06-01',
        }).timeout(const Duration(seconds: 10));
        return res.statusCode == 200;
      } else if (p == 'groq') {
        final url = Uri.parse('https://api.groq.com/openai/v1/models');
        final res = await httpClient
            .get(url, headers: {'Authorization': 'Bearer $key'})
            .timeout(const Duration(seconds: 10));
        return res.statusCode == 200;
      } else {
        // OpenAI, OpenRouter, DeepSeek
        final url = Uri.parse('https://api.openai.com/v1/models');
        final res = await httpClient
            .get(url, headers: {'Authorization': 'Bearer $key'})
            .timeout(const Duration(seconds: 10));
        return res.statusCode == 200;
      }
    } catch (_) {
      return false;
    }
  }

  /// Memulai streaming respon dari cloud dengan fallback antar-combo, stall detection,
  /// dan evaluasi fallback lokal otomatis.
  ///
  /// Mengembalikan [Stream] bertipe [RouterStreamEvent] yang dapat berupa:
  /// - [RouterTextDelta]: potongan teks respon
  /// - [RouterToolCall]: pemanggilan fungsi/tool oleh model
  /// - [RouterStreamDone]: sinyal selesai
  Stream<RouterStreamEvent> streamGenerate({
    required List<ChatMessage> messages,
    required String modelOrCombo,
    required Map<String, String> apiKeys,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1024,
    ComboStrategy comboStrategy = ComboStrategy.fallback,
    bool newTurn = true,
  }) async* {
    // 1. Dapatkan kandidat model: jika berupa string koma mentah, split langsung
    // untuk mencegah string dengan '/' (mis. 'gemini-2.5-flash,openai/gpt-4o-mini')
    // salah di-parse sebagai single provider/model.
    List<String> candidateModels;
    if (modelOrCombo.contains(',')) {
      candidateModels = modelOrCombo
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      candidateModels = [modelOrCombo.trim()];
    }

    // 2. Buat resolver per-call yang mewarisi konfigurasi yang di-inject,
    // tetapi melengkapi callback isProviderActive sesuai apiKeys yang diberikan.
    final resolver = ModelResolver(
      aliasMap: modelResolver.aliasMap,
      knownProviders: modelResolver.knownProviders,
      comboLookup: modelResolver.comboLookup,
      aliasLookup: modelResolver.aliasLookup,
      isProviderActive: (p) => apiKeys[p]?.isNotEmpty ?? false,
    );

    // 3. Rotasi urutan kandidat berdasarkan strategi combo
    candidateModels = comboManager.apply(
      strategy: comboStrategy,
      models: candidateModels,
      comboName: modelOrCombo,
      newTurn: newTurn,
    );

    // 4. Saring model yang provider-nya saat ini TIDAK dalam masa cooldown
    final availableModels = candidateModels.where((m) {
      try {
        final info = resolver.resolveModel(m);
        return !isProviderInCooldown(info.provider);
      } catch (_) {
        return true;
      }
    }).toList();

    // Jika SEMUA provider dalam combo sedang cooldown, langsung fallback ke lokal seketika
    if (availableModels.isEmpty && candidateModels.isNotEmpty) {
      final decision = evaluateLocalFallback(
        error: StateError('All providers in combo are currently cooling down'),
        attemptIndex: 0,
        totalModelsInCombo: candidateModels.length,
        allProvidersInCooldown: true,
      );
      throw LocalFallbackException(decision);
    }

    final effectiveCandidates =
        availableModels.isNotEmpty ? availableModels : candidateModels;

    Object? lastError;
    int? lastStatusCode;
    String? lastErrorText;

    for (var i = 0; i < effectiveCandidates.length; i++) {
      final targetModel = effectiveCandidates[i];
      final info = resolver.resolveModel(targetModel);
      final provider = info.provider;
      final rawModelName = info.model.isNotEmpty ? info.model : targetModel;
      final apiKey = apiKeys[provider] ?? '';

      if (apiKey.isEmpty) {
        // Lewati provider jika API key tidak tersedia
        final decision = evaluateLocalFallback(
          error: StateError('Missing API key for $provider'),
          attemptIndex: i,
          totalModelsInCombo: effectiveCandidates.length,
          statusCode: 401,
        );
        if (decision.shouldFallback) {
          throw LocalFallbackException(decision);
        }
        continue;
      }

      // Tentukan stall timeout (60 detik untuk model reasoning, 30 detik untuk standar)
      final isReasoning = targetModel.toLowerCase().contains('o1') ||
          targetModel.toLowerCase().contains('o3') ||
          targetModel.toLowerCase().contains('r1') ||
          targetModel.toLowerCase().contains('thinking');
      final effectiveStallTimeout =
          isReasoning ? reasoningStallTimeout : defaultStallTimeout;

      final sessionKey =
          '${messages.isNotEmpty ? messages.first.sessionId : 0}_${DateTime.now().millisecondsSinceEpoch}';

      try {
        final eventStream = _dispatchProviderStream(
          provider: provider,
          modelName: rawModelName,
          apiKey: apiKey,
          messages: messages,
          systemPrompt: systemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
          sessionKey: sessionKey,
          stallTimeout: effectiveStallTimeout,
        );

        await for (final event in eventStream) {
          yield event;
        }

        // Berhasil menerima respon penuh: reset backoff level untuk provider ini
        _backoffLevelsByProvider.remove(provider);
        return; // Sukses, selesai
      } catch (err) {
        lastError = err;
        ensureStreamClosed(sessionKey);

        if (err is http.ClientException) {
          lastErrorText = err.message;
        } else {
          lastErrorText = err.toString();
        }

        // Parse status code jika ada
        final statusMatch = RegExp(r'(\d{3})').firstMatch(lastErrorText);
        if (statusMatch != null) {
          lastStatusCode = int.tryParse(statusMatch.group(1)!);
        }

        // Hitung cooldown dan catat jika rate limit / kuota
        final currentBackoff = _backoffLevelsByProvider[provider] ?? 0;
        final classification = classifyError(
          lastStatusCode ?? 0,
          lastErrorText,
          currentBackoff,
        );

        if (classification.cooldownMs > 0) {
          _cooldownUntilByProvider[provider] = DateTime.now().add(
            Duration(milliseconds: classification.cooldownMs),
          );
          _backoffLevelsByProvider[provider] = classification.newBackoffLevel;
        }

        // Evaluasi apakah harus langsung fallback ke model lokal
        final decision = evaluateLocalFallback(
          error: err,
          attemptIndex: i,
          totalModelsInCombo: effectiveCandidates.length,
          statusCode: lastStatusCode,
          errorText: lastErrorText,
        );

        if (decision.shouldFallback) {
          throw LocalFallbackException(decision, originalError: err);
        }
      } finally {
        clearStreamState(sessionKey);
      }
    }

    // Jika seluruh loop selesai tanpa return dan belum melempar exception
    final finalDecision = evaluateLocalFallback(
      error: lastError ?? StateError('Unknown cloud failure'),
      attemptIndex: effectiveCandidates.length - 1,
      totalModelsInCombo: effectiveCandidates.length,
      statusCode: lastStatusCode,
      errorText: lastErrorText,
    );
    throw LocalFallbackException(finalDecision, originalError: lastError);
  }

  Stream<RouterStreamEvent> _dispatchProviderStream({
    required String provider,
    required String modelName,
    required String apiKey,
    required List<ChatMessage> messages,
    required String? systemPrompt,
    required double temperature,
    required int maxTokens,
    required String sessionKey,
    required Duration stallTimeout,
  }) async* {
    final p = modelResolver.resolveProviderAlias(provider);
    if (p == 'gemini') {
      yield* _streamGemini(
        modelName: modelName,
        apiKey: apiKey,
        messages: messages,
        systemPrompt: systemPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
        stallTimeout: stallTimeout,
      );
    } else if (p == 'anthropic' || p == 'claude') {
      yield* _streamAnthropic(
        modelName: modelName,
        apiKey: apiKey,
        messages: messages,
        systemPrompt: systemPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
        stallTimeout: stallTimeout,
      );
    } else {
      // OpenAI, Groq, DeepSeek, OpenRouter
      yield* _streamOpenAICompatible(
        provider: provider,
        modelName: modelName,
        apiKey: apiKey,
        messages: messages,
        systemPrompt: systemPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
        sessionKey: sessionKey,
        stallTimeout: stallTimeout,
      );
    }
  }

  /// Parser bersama untuk membaca Claude SSE format dan memancarkan [RouterStreamEvent].
  Iterable<RouterStreamEvent> _parseClaudeSseEvents(
    String claudeSseChunk,
    Map<int, Map<String, String>> activeToolBlocks,
  ) sync* {
    if (claudeSseChunk.isEmpty) return;
    final lines = const LineSplitter().convert(claudeSseChunk);
    for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final jsonStr = trimmed.substring(5).trim();
      if (jsonStr.isEmpty) continue;
      if (jsonStr == '[DONE]') {
        yield const RouterStreamDone();
        continue;
      }

      try {
        final data = jsonDecode(jsonStr);
        if (data is! Map<String, dynamic>) continue;
        final type = data['type'] as String?;

        switch (type) {
          case 'content_block_start':
            final block = data['content_block'] as Map<String, dynamic>?;
            final blockType = block?['type'] as String?;
            final blockIndex = data['index'] as int? ?? 0;
            if (blockType == 'tool_use') {
              activeToolBlocks[blockIndex] = {
                'id': block?['id'] as String? ?? '',
                'name': block?['name'] as String? ?? '',
                'args': '',
              };
            }
            break;

          case 'content_block_delta':
            final delta = data['delta'] as Map<String, dynamic>?;
            final deltaType = delta?['type'] as String?;
            final blockIndex = data['index'] as int? ?? 0;

            if (deltaType == 'text_delta') {
              final text = delta?['text'] as String?;
              if (text != null && text.isNotEmpty) {
                yield RouterTextDelta(text);
              }
            } else if (deltaType == 'input_json_delta') {
              final partial = delta?['partial_json'] as String?;
              if (partial != null && activeToolBlocks.containsKey(blockIndex)) {
                activeToolBlocks[blockIndex]!['args'] =
                    (activeToolBlocks[blockIndex]!['args'] ?? '') + partial;
              }
            }
            break;

          case 'content_block_stop':
            final blockIndex = data['index'] as int? ?? 0;
            if (activeToolBlocks.containsKey(blockIndex)) {
              final tool = activeToolBlocks.remove(blockIndex)!;
              yield RouterToolCall(
                id: tool['id'] ?? '',
                name: tool['name'] ?? '',
                argumentsJson: tool['args'] ?? '{}',
              );
            }
            break;

          case 'message_delta':
            final delta = data['delta'] as Map<String, dynamic>?;
            final stopReason = delta?['stop_reason'] as String?;
            if (stopReason != null && stopReason.isNotEmpty) {
              yield RouterStreamDone(finishReason: stopReason);
            }
            break;

          case 'message_stop':
            yield const RouterStreamDone();
            break;
        }
      } catch (_) {}
    }
  }

  Stream<RouterStreamEvent> _streamGemini({
    required String modelName,
    required String apiKey,
    required List<ChatMessage> messages,
    required String? systemPrompt,
    required double temperature,
    required int maxTokens,
    required Duration stallTimeout,
  }) async* {
    final payload = convertAuraToGeminiPayload(
      messages,
      systemPrompt: systemPrompt,
      temperature: temperature,
      maxTokens: maxTokens,
    );

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:streamGenerateContent?alt=sse',
    );

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..headers['x-goog-api-key'] = apiKey.trim()
      ..body = jsonEncode(payload);

    final response = await httpClient.send(request);
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw HttpException('Gemini HTTP ${response.statusCode}: $body');
    }

    final rawStream = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    // Terapkan stall detection eksplisit
    final stallStream = rawStream.withStallDetection(timeout: stallTimeout);

    await for (final line in stallStream) {
      if (line.startsWith('data: ')) {
        final dataStr = line.substring(6).trim();
        if (dataStr.isEmpty) continue;
        try {
          final data = jsonDecode(dataStr);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final candidate = candidates[0];
            final content = candidate['content'];
            final parts = content?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              for (final part in parts) {
                if (part is! Map) continue;
                // 1. Teks token
                final text = part['text'] as String?;
                if (text != null && text.isNotEmpty) {
                  yield RouterTextDelta(text);
                }
                // 2. Tool call (functionCall)
                final fn = part['functionCall'] as Map?;
                if (fn != null) {
                  final name = fn['name'] as String? ?? 'tool';
                  final args = fn['args'];
                  final argsJson =
                      args is String ? args : jsonEncode(args ?? {});
                  final id =
                      'call_${name}_${DateTime.now().millisecondsSinceEpoch}';
                  yield RouterToolCall(
                    id: id,
                    name: name,
                    argumentsJson: argsJson,
                  );
                }
              }
            }

            final finishReason = candidate['finishReason'] as String?;
            if (finishReason != null &&
                finishReason.isNotEmpty &&
                finishReason != 'STOP') {
              yield RouterStreamDone(finishReason: finishReason);
            }
          }
        } catch (_) {}
      }
    }
    yield const RouterStreamDone();
  }

  Stream<RouterStreamEvent> _streamAnthropic({
    required String modelName,
    required String apiKey,
    required List<ChatMessage> messages,
    required String? systemPrompt,
    required double temperature,
    required int maxTokens,
    required Duration stallTimeout,
  }) async* {
    final anthropicMessages = <Map<String, dynamic>>[];
    for (final msg in messages) {
      switch (msg.role) {
        case MessageRole.system:
          continue; // Ditangani via parameter root 'system'
        case MessageRole.user:
          anthropicMessages.add({
            'role': 'user',
            'content': msg.content,
          });
          break;
        case MessageRole.assistant:
          if (msg.toolCallJson != null && msg.toolCallJson!.isNotEmpty) {
            try {
              final decoded = jsonDecode(msg.toolCallJson!);
              final contentList = <Map<String, dynamic>>[];
              if (msg.content.isNotEmpty) {
                contentList.add({'type': 'text', 'text': msg.content});
              }
              final tcs = decoded is List ? decoded : [decoded];
              for (final tc in tcs) {
                if (tc is Map) {
                  final fn = tc['function'] as Map? ?? tc;
                  final args = fn['arguments'] is String
                      ? jsonDecode(fn['arguments'] as String)
                      : (fn['arguments'] ?? <String, dynamic>{});
                  contentList.add({
                    'type': 'tool_use',
                    'id': tc['id'] ??
                        'call_${DateTime.now().millisecondsSinceEpoch}',
                    'name': fn['name'] ?? 'tool',
                    'input': args,
                  });
                }
              }
              anthropicMessages.add({
                'role': 'assistant',
                'content': contentList,
              });
              break;
            } catch (_) {}
          }
          anthropicMessages.add({
            'role': 'assistant',
            'content': msg.content,
          });
          break;
        case MessageRole.tool:
          anthropicMessages.add({
            'role': 'user',
            'content': [
              {
                'type': 'tool_result',
                'tool_use_id': msg.toolCallId ?? '',
                'content': msg.toolResult ?? msg.content,
              }
            ],
          });
          break;
      }
    }

    final payload = {
      'model': modelName,
      'messages': anthropicMessages,
      'stream': true,
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        'system': systemPrompt,
      'max_tokens': maxTokens,
      'temperature': temperature,
    };

    final endpoint = getProviderEndpoint('anthropic', model: modelName);
    final request = http.Request('POST', endpoint)
      ..headers['content-type'] = 'application/json'
      ..headers['x-api-key'] = apiKey.trim()
      ..headers['anthropic-version'] = '2023-06-01'
      ..body = jsonEncode(payload);

    final response = await httpClient.send(request);
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw HttpException('Anthropic HTTP ${response.statusCode}: $body');
    }

    final rawStream = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    final stallStream = rawStream.withStallDetection(timeout: stallTimeout);
    final activeToolBlocks = <int, Map<String, String>>{};

    await for (final line in stallStream) {
      if (line.trim().isEmpty) continue;
      for (final event in _parseClaudeSseEvents(line, activeToolBlocks)) {
        yield event;
      }
    }
  }

  Stream<RouterStreamEvent> _streamOpenAICompatible({
    required String provider,
    required String modelName,
    required String apiKey,
    required List<ChatMessage> messages,
    required String? systemPrompt,
    required double temperature,
    required int maxTokens,
    required String sessionKey,
    required Duration stallTimeout,
  }) async* {
    final openAiMessages = convertAuraToOpenAIMessages(
      messages,
      systemPrompt: systemPrompt,
    );

    final endpoint = getProviderEndpoint(provider, model: modelName);

    final payload = {
      'model': modelName,
      'messages': openAiMessages,
      'stream': true,
      'temperature': temperature,
      if (requiresMaxCompletionTokens(modelName))
        'max_completion_tokens': maxTokens
      else
        'max_tokens': maxTokens,
    };

    final request = http.Request('POST', endpoint)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..body = jsonEncode(payload);

    final response = await httpClient.send(request);
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw HttpException('$provider HTTP ${response.statusCode}: $body');
    }

    final rawStream = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    final stallStream = rawStream.withStallDetection(timeout: stallTimeout);
    final activeToolBlocks = <int, Map<String, String>>{};

    await for (final line in stallStream) {
      if (line.trim().isEmpty) continue;
      final claudeChunk =
          translateOpenAIToClaudeStreamSession(sessionKey, line);
      if (claudeChunk.isNotEmpty) {
        for (final event
            in _parseClaudeSseEvents(claudeChunk, activeToolBlocks)) {
          yield event;
        }
      }
    }
  }
}
