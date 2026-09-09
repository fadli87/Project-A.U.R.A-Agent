/// Format translation and schema sanitization logic — port dari
/// `internal/translator/` (9router-go):
/// - `request.go` (Claude -> OpenAI request translation, tool choices, system prompts)
/// - `response.go` (OpenAI -> Claude response translation & usage parsing)
/// - `schema.go` (Gemini schema cleaning & parameter sanitization)
/// - `sanitize.go` (Tool calling argument normalization)
/// - `tool_schema.go` (Provider-specific regex normalization)
///
/// Disusun sebagai pure Dart tanpa dependency HTTP/DB.
library format_translator;

import 'dart:convert';
import 'models/llm_router_models.dart';

// ============================================================================
// 1. Request Translation (Claude -> OpenAI)
// ============================================================================

final _billingHeaderRegex = RegExp(
  r'^x-anthropic-billing-header:[^\n]*(?:\r?\n)?',
  caseSensitive: false,
);

/// Mengecek apakah sebuah model membutuhkan `max_completion_tokens` alih-alih `max_tokens`.
/// Port dari `requiresMaxCompletionTokens` di `request.go`.
bool requiresMaxCompletionTokens(String model) {
  final lower = model.toLowerCase();
  if (lower.contains('gpt-5')) return true;
  if (lower.contains('o1-') || lower.contains('o3-') || lower.contains('o4-')) {
    return true;
  }
  return false;
}

/// Menghapus header billing internal Anthropic dari string prompt.
/// Port dari `stripAnthropicBillingHeader` di `request.go`.
String stripAnthropicBillingHeader(String text) {
  return text.replaceAll(_billingHeaderRegex, '');
}

/// Mem-parse system prompt Claude yang bisa berbentuk string murni atau list of blocks.
/// Port dari `parseSystemPrompt` di `request.go`.
String parseSystemPrompt(dynamic systemRaw) {
  if (systemRaw == null) return '';

  if (systemRaw is String) {
    return stripAnthropicBillingHeader(systemRaw);
  }

  if (systemRaw is List) {
    final parts = <String>[];
    for (final block in systemRaw) {
      if (block is Map && block['text'] is String) {
        final text = stripAnthropicBillingHeader(block['text'] as String);
        if (text.isNotEmpty) {
          parts.add(text);
        }
      } else if (block is ClaudeSystemBlock) {
        final text = stripAnthropicBillingHeader(block.text);
        if (text.isNotEmpty) {
          parts.add(text);
        }
      }
    }
    return parts.join('\n');
  }

  return '';
}

/// Membungkus pesan reminder instruksi ke format `<instructions>...</instructions>`.
/// Port dari `systemReminderText` di `request.go`.
String systemReminderText(String content) {
  final text = content.trim();
  if (text.isEmpty) return '';
  return '<instructions>\n$text\n</instructions>';
}

/// Menggabungkan text blocks menjadi String jika hanya ada 1 blok teks murni.
/// Port dari `collapseTextParts` di `request.go`.
dynamic collapseTextParts(List<OpenAIContentBlock> parts) {
  if (parts.length == 1 && parts[0].type == 'text' && parts[0].text != null) {
    return parts[0].text;
  }
  return parts.map((p) => p.toJson()).toList();
}

/// Mengonversi satu pesan Claude menjadi satu atau beberapa pesan OpenAI.
/// Port dari `convertClaudeMessage` di `request.go`.
List<OpenAIMessage> convertClaudeMessage(ClaudeMessage msg) {
  if (msg.role == 'system') {
    if (msg.content is String) {
      final rem = systemReminderText(msg.content as String);
      if (rem.isNotEmpty) {
        return [OpenAIMessage(role: 'user', content: rem)];
      }
      return const [];
    }
    if (msg.content is List) {
      final textParts = <String>[];
      for (final block in msg.content as List) {
        if (block is Map && block['type'] == 'text' && block['text'] is String) {
          textParts.add(block['text'] as String);
        } else if (block is ClaudeContentBlock && block.type == 'text' && block.text != null) {
          textParts.add(block.text!);
        }
      }
      final rem = systemReminderText(textParts.join('\n'));
      if (rem.isNotEmpty) {
        return [OpenAIMessage(role: 'user', content: rem)];
      }
    }
    return const [];
  }

  final role = msg.role == 'assistant' ? 'assistant' : 'user';

  if (msg.content is String) {
    return [OpenAIMessage(role: role, content: msg.content as String)];
  }

  if (msg.content is! List) {
    return [OpenAIMessage(role: role, content: '')];
  }

  final blocks = msg.content as List;
  final textParts = <OpenAIContentBlock>[];
  final toolCalls = <OpenAIToolCall>[];
  final toolResults = <OpenAIMessage>[];
  final reasoningBuffer = StringBuffer();

  for (final rawBlock in blocks) {
    final block = rawBlock is ClaudeContentBlock
        ? rawBlock
        : (rawBlock is Map<String, dynamic> ? ClaudeContentBlock.fromJson(rawBlock) : null);
    if (block == null) continue;

    switch (block.type) {
      case 'text':
        if (block.text != null) {
          textParts.add(OpenAIContentBlock(type: 'text', text: block.text));
        }
        break;
      case 'thinking':
        if (block.thinking != null && block.thinking!.isNotEmpty) {
          reasoningBuffer.write(block.thinking);
        }
        break;
      case 'image':
        if (block.source != null && block.source!.type == 'base64') {
          final url = 'data:${block.source!.mediaType};base64,${block.source!.data}';
          textParts.add(OpenAIContentBlock(
            type: 'image_url',
            imageUrl: OpenAIImageUrl(url: url),
          ));
        }
        break;
      case 'tool_use':
        final inputStr = block.input is String
            ? block.input as String
            : jsonEncode(block.input ?? <String, dynamic>{});
        toolCalls.add(OpenAIToolCall(
          id: block.id ?? '',
          type: 'function',
          function: OpenAIFunctionCall(
            name: block.name ?? '',
            arguments: inputStr,
          ),
        ));
        break;
      case 'tool_result':
        String resultContent = '';
        if (block.content is String) {
          resultContent = block.content as String;
        } else if (block.content is List) {
          final parts = <String>[];
          for (final c in block.content as List) {
            if (c is Map && c['type'] == 'text' && c['text'] is String) {
              parts.add(c['text'] as String);
            }
          }
          resultContent = parts.join('\n');
        } else if (block.content != null) {
          resultContent = jsonEncode(block.content);
        }
        toolResults.add(OpenAIMessage(
          role: 'tool',
          toolCallId: block.toolUseId ?? '',
          content: resultContent,
        ));
        break;
    }
  }

  if (toolResults.isNotEmpty) {
    final results = <OpenAIMessage>[...toolResults];
    if (textParts.isNotEmpty) {
      results.add(OpenAIMessage(
        role: 'user',
        content: collapseTextParts(textParts),
      ));
    }
    return results;
  }

  if (toolCalls.isNotEmpty) {
    return [
      OpenAIMessage(
        role: 'assistant',
        reasoningContent: reasoningBuffer.isNotEmpty ? reasoningBuffer.toString() : null,
        toolCalls: toolCalls,
        content: textParts.isNotEmpty ? collapseTextParts(textParts) : null,
      )
    ];
  }

  if (textParts.isNotEmpty) {
    return [
      OpenAIMessage(
        role: role,
        content: collapseTextParts(textParts),
      )
    ];
  }

  if (blocks.isEmpty) {
    return [OpenAIMessage(role: role, content: '')];
  }

  return const [];
}

/// Memperbaiki tool calls yang belum memiliki respon balasan bertipe role "tool".
/// OpenAI API menuntut setiap `tool_calls` di-resolve oleh respon ber-role `tool`.
/// Port dari `fixMissingToolResponsesOpenAI` di `request.go`.
List<OpenAIMessage> fixMissingToolResponsesOpenAI(List<OpenAIMessage> messages) {
  final result = List<OpenAIMessage>.from(messages);

  for (var i = 0; i < result.length; i++) {
    final msg = result[i];
    if (msg.role == 'assistant' && msg.toolCalls != null && msg.toolCalls!.isNotEmpty) {
      final toolCallIds = msg.toolCalls!.map((tc) => tc.id).toList();
      final respondedIds = <String>{};
      var insertPosition = i + 1;

      for (var j = i + 1; j < result.length; j++) {
        final nextMsg = result[j];
        if (nextMsg.role == 'tool' && nextMsg.toolCallId != null && nextMsg.toolCallId!.isNotEmpty) {
          respondedIds.add(nextMsg.toolCallId!);
          insertPosition = j + 1;
        } else {
          break;
        }
      }

      final missingIds = toolCallIds.where((id) => !respondedIds.contains(id)).toList();
      if (missingIds.isNotEmpty) {
        final missingResponses = missingIds.map((id) => OpenAIMessage(
              role: 'tool',
              toolCallId: id,
              content: '[No response received]',
            )).toList();

        result.insertAll(insertPosition, missingResponses);
        i = insertPosition + missingResponses.length - 1;
      }
    }
  }

  return result;
}

/// Mengonversi nilai token budget menjadi level effort OpenAI reasoning.
/// Port dari `budgetToEffort` di `request.go`.
String budgetToEffort(int budget) {
  if (budget >= 20000) return 'high';
  if (budget >= 5000) return 'medium';
  return 'low';
}

/// Mengonversi tool choice Claude ke OpenAI format.
/// Port dari `convertToolChoice` di `request.go`.
dynamic convertToolChoice(dynamic choiceRaw) {
  if (choiceRaw == null) return 'auto';
  if (choiceRaw is String) return choiceRaw;

  if (choiceRaw is Map) {
    final type = choiceRaw['type'];
    if (type == 'auto') return 'auto';
    if (type == 'any') return 'required';
    if (type == 'tool') {
      return {
        'type': 'function',
        'function': {'name': choiceRaw['name']},
      };
    }
  }

  if (choiceRaw is ClaudeToolChoice) {
    if (choiceRaw.type == 'auto') return 'auto';
    if (choiceRaw.type == 'any') return 'required';
    if (choiceRaw.type == 'tool' && choiceRaw.name != null) {
      return {
        'type': 'function',
        'function': {'name': choiceRaw.name},
      };
    }
  }

  return 'auto';
}

/// Mentranslasikan body request Claude ke format request OpenAI secara utuh.
/// Port dari `TranslateClaudeToOpenAI` di `request.go`.
Map<String, dynamic> translateClaudeToOpenAI(Map<String, dynamic> claudeBody) {
  final creq = ClaudeRequest.fromJson(claudeBody);

  final oreqMessages = <OpenAIMessage>[];

  final sysContent = parseSystemPrompt(creq.system);
  if (sysContent.isNotEmpty) {
    oreqMessages.add(OpenAIMessage(
      role: 'system',
      content: sysContent,
    ));
  }

  for (final msg in creq.messages) {
    oreqMessages.addAll(convertClaudeMessage(msg));
  }

  final fixedMessages = fixMissingToolResponsesOpenAI(oreqMessages);

  List<OpenAITool>? otools;
  if (creq.tools != null && creq.tools!.isNotEmpty) {
    otools = creq.tools!.map((t) {
      return OpenAITool(
        type: 'function',
        function: OpenAIFunction(
          name: t.name,
          description: t.description,
          parameters: t.inputSchema,
        ),
      );
    }).toList();
  }

  dynamic toolChoice;
  if (creq.toolChoice != null) {
    toolChoice = convertToolChoice(creq.toolChoice);
  }

  String? reasoningEffort;
  if (creq.thinking != null) {
    if (creq.thinking!.type == 'enabled') {
      reasoningEffort = budgetToEffort(creq.thinking!.budget);
    } else if (creq.thinking!.type == 'adaptive') {
      var effort = 'high';
      if (creq.outputConfig != null && creq.outputConfig!.effort != null) {
        final eff = creq.outputConfig!.effort!.toLowerCase();
        effort = (eff == 'xhigh' || eff == 'auto') ? 'high' : eff;
      }
      reasoningEffort = effort;
    }
  } else if (creq.outputConfig != null && creq.outputConfig!.effort != null) {
    final eff = creq.outputConfig!.effort!.toLowerCase();
    reasoningEffort = (eff == 'xhigh' || eff == 'auto') ? 'high' : eff;
  }

  final isMaxCompletion = requiresMaxCompletionTokens(creq.model);

  final oreq = OpenAIRequest(
    model: creq.model,
    messages: fixedMessages,
    temperature: creq.temperature,
    maxTokens: isMaxCompletion ? null : creq.maxTokens,
    maxCompletionTokens: isMaxCompletion ? creq.maxTokens : null,
    stream: creq.stream,
    tools: otools,
    toolChoice: toolChoice,
    reasoningEffort: reasoningEffort,
  );

  return oreq.toJson();
}

// ============================================================================
// 2. Claude Compatibility Functions (Addendum Section 2 & Pipeline)
// ============================================================================

final _serverToolUseIdRegex = RegExp(r'^srvtoolu_[a-zA-Z0-9_]+$');

/// Membersihkan foreign `server_tool_use` blocks yang membawa ID tidak valid,
/// `tool_result` yatim yang mereferensikannya, text block kosong, dan pesan kosong.
/// Port dari `SanitizeClaudePassthrough` di `request.go`.
Map<String, dynamic> sanitizeClaudePassthrough(Map<String, dynamic> body) {
  final copy = Map<String, dynamic>.from(body);
  final messagesRaw = copy['messages'];
  if (messagesRaw is! List || messagesRaw.isEmpty) {
    return copy;
  }

  final droppedIds = <String>{};
  final cleanedMessages = <dynamic>[];

  // Pass 1: Drop foreign server_tool_use and collect dropped IDs
  for (final mRaw in messagesRaw) {
    if (mRaw is! Map) {
      cleanedMessages.add(mRaw);
      continue;
    }
    final msgMap = Map<String, dynamic>.from(mRaw as Map<String, dynamic>);
    final contentRaw = msgMap['content'];
    if (contentRaw is! List) {
      cleanedMessages.add(msgMap);
      continue;
    }

    final kept = <dynamic>[];
    for (final bRaw in contentRaw) {
      if (bRaw is! Map) {
        kept.add(bRaw);
        continue;
      }
      final block = Map<String, dynamic>.from(bRaw as Map<String, dynamic>);
      final bType = block['type'] as String?;

      if (bType == 'server_tool_use') {
        final id = block['id'] as String? ?? '';
        if (!_serverToolUseIdRegex.hasMatch(id)) {
          droppedIds.add(id);
          continue;
        }
      }

      // Strip empty text blocks (Anthropic API 400s on empty text)
      if (bType == 'text') {
        final txt = block['text'] as String?;
        if (txt == null || txt.trim().isEmpty) {
          continue;
        }
      }

      kept.add(block);
    }

    msgMap['content'] = kept;
    cleanedMessages.add(msgMap);
  }

  // Pass 2: Drop tool_result referencing dropped server_tool_use IDs and empty messages
  final finalMessages = <dynamic>[];
  for (final mRaw in cleanedMessages) {
    if (mRaw is! Map) {
      finalMessages.add(mRaw);
      continue;
    }
    final msgMap = Map<String, dynamic>.from(mRaw as Map<String, dynamic>);
    final contentRaw = msgMap['content'];

    if (contentRaw is List) {
      final kept = <dynamic>[];
      for (final bRaw in contentRaw) {
        if (bRaw is Map) {
          final block = bRaw as Map<String, dynamic>;
          final bType = block['type'] as String?;
          final toolUseId = block['tool_use_id'] as String?;
          if ((bType == 'tool_result' || bType == 'web_search_tool_result') &&
              toolUseId != null &&
              droppedIds.contains(toolUseId)) {
            continue;
          }
        }
        kept.add(bRaw);
      }
      msgMap['content'] = kept;

      // Drop messages that end up completely empty
      if (kept.isEmpty) {
        continue;
      }
    } else if (contentRaw is String && contentRaw.trim().isEmpty) {
      continue;
    }

    finalMessages.add(msgMap);
  }

  copy['messages'] = finalMessages;
  return copy;
}

/// Memberikan default `"type": "custom"` untuk tool yang tidak memiliki atribut type.
/// Port dari `DefaultClaudeToolType` di `request.go`.
Map<String, dynamic> defaultClaudeToolType(Map<String, dynamic> body) {
  final copy = Map<String, dynamic>.from(body);
  final toolsRaw = copy['tools'];
  if (toolsRaw is! List || toolsRaw.isEmpty) {
    return copy;
  }

  final updatedTools = <dynamic>[];
  for (final t in toolsRaw) {
    if (t is Map) {
      final toolMap = Map<String, dynamic>.from(t as Map<String, dynamic>);
      final typeVal = toolMap['type'];
      if (typeVal == null || (typeVal is String && typeVal.isEmpty)) {
        toolMap['type'] = 'custom';
      }
      updatedTools.add(toolMap);
    } else {
      updatedTools.add(t);
    }
  }

  copy['tools'] = updatedTools;
  return copy;
}

/// Menghitung indeks tool terakhir yang valid membawa `cache_control`.
/// Tool dengan `defer_loading: true` tidak boleh dipasangi breakpoint cache.
/// Port dari `LastCacheableToolIndex` di `request.go`.
int lastCacheableToolIndex(List<dynamic>? tools) {
  if (tools == null || tools.isEmpty) return -1;
  for (var i = tools.length - 1; i >= 0; i--) {
    final t = tools[i];
    if (t is Map) {
      final deferLoading = t['defer_loading'];
      if (deferLoading is bool && deferLoading) {
        continue;
      }
    }
    return i;
  }
  return -1;
}

/// Menempatkan prompt-caching breakpoint (`cache_control: {type: ephemeral, ttl: 1h}`)
/// pada tool terakhir yang bukan deferred tool.
/// Port dari `AnchorClaudeCache` di `request.go`.
Map<String, dynamic> anchorClaudeCache(Map<String, dynamic> body) {
  final copy = Map<String, dynamic>.from(body);
  final toolsRaw = copy['tools'];
  if (toolsRaw is! List || toolsRaw.isEmpty) {
    return copy;
  }

  final lastIndex = lastCacheableToolIndex(toolsRaw);
  final updatedTools = <dynamic>[];

  for (var i = 0; i < toolsRaw.length; i++) {
    final t = toolsRaw[i];
    if (t is! Map) {
      updatedTools.add(t);
      continue;
    }
    final m = Map<String, dynamic>.from(t as Map<String, dynamic>);
    final hasCache = m.containsKey('cache_control');

    if (i == lastIndex) {
      final want = {'type': 'ephemeral', 'ttl': '1h'};
      if (!hasCache) {
        m['cache_control'] = want;
      } else {
        final cur = m['cache_control'];
        if (cur is! Map || cur['type'] != 'ephemeral' || cur['ttl'] != '1h') {
          m['cache_control'] = want;
        }
      }
    } else {
      if (hasCache) {
        m.remove('cache_control');
      }
    }

    updatedTools.add(m);
  }

  copy['tools'] = updatedTools;
  return copy;
}

/// Menjalankan pipeline Claude-compatibility secara lengkap (3 langkah terurut):
/// 1. `sanitizeClaudePassthrough` (membersihkan tool call foreign / blok teks kosong)
/// 2. `defaultClaudeToolType` (normalisasi atribut type ke "custom")
/// 3. `anchorClaudeCache` (menyematkan breakpoint cache pada tool terakhir yang non-deferred)
Map<String, dynamic> applyClaudeCompatPipeline(Map<String, dynamic> body) {
  var current = sanitizeClaudePassthrough(body);
  current = defaultClaudeToolType(current);
  current = anchorClaudeCache(current);
  return current;
}

// ============================================================================
// 3. Response & Usage Translation (OpenAI -> Claude)
// ============================================================================

/// Mengekstrak usage dari Claude-format response body.
/// Port dari `ParseClaudeUsage` di `response.go`.
OpenAIUsage? parseClaudeUsage(Map<String, dynamic> body) {
  final rawUsage = body['usage'];
  if (rawUsage is! Map<String, dynamic>) return null;

  // Hanya anggap valid jika memiliki key 'input_tokens' khas Claude
  if (!rawUsage.containsKey('input_tokens')) return null;

  final inputTokens = rawUsage['input_tokens'] as int? ?? 0;
  final outputTokens = rawUsage['output_tokens'] as int? ?? 0;
  final cacheCreation = rawUsage['cache_creation_input_tokens'] as int? ?? 0;

  var cached = 0;
  if (rawUsage['cached_tokens'] is int) {
    cached = rawUsage['cached_tokens'] as int;
  } else if (rawUsage['input_tokens_details'] is Map &&
      (rawUsage['input_tokens_details'] as Map)['cached_tokens'] is int) {
    cached = (rawUsage['input_tokens_details'] as Map)['cached_tokens'] as int;
  } else if (rawUsage['cache_read_input_tokens'] is int) {
    cached = rawUsage['cache_read_input_tokens'] as int;
  }

  return OpenAIUsage(
    promptTokens: inputTokens,
    completionTokens: outputTokens,
    cachedTokens: cached,
    cacheCreationInputTokens: cacheCreation,
  );
}

/// Mengekstrak usage dari response body baik berformat OpenAI maupun Claude.
/// Port dari `ParseResponseUsage` di `response.go`.
OpenAIUsage? parseResponseUsage(Map<String, dynamic> body) {
  final claudeUsage = parseClaudeUsage(body);
  if (claudeUsage != null) return claudeUsage;

  final rawUsage = body['usage'];
  if (rawUsage is Map<String, dynamic>) {
    return OpenAIUsage.fromJson(rawUsage);
  }
  return null;
}

/// Mentranslasikan response non-streaming OpenAI menjadi response non-streaming Claude.
/// Port dari `TranslateOpenAIToClaude` di `response.go`.
Map<String, dynamic> translateOpenAIToClaude(Map<String, dynamic> openaiResp) {
  final resp = OpenAIResponse.fromJson(openaiResp);
  if (resp.choices.isEmpty) {
    throw const FormatException('No choices in OpenAI response');
  }

  final choice = resp.choices[0];
  final msg = choice.message;

  var msgId = resp.id;
  if (msgId.isEmpty) {
    msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
  } else {
    msgId = msgId.replaceFirst('chatcmpl-', '');
    if (msgId.isEmpty || msgId == 'chat') {
      msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  var modelName = resp.model;
  if (modelName.isEmpty) {
    modelName = 'claude-3-5-sonnet';
  }

  final contentBlocks = <Map<String, dynamic>>[];

  if (msg != null) {
    // 1. Thinking / reasoning block
    if (msg.reasoningContent != null && msg.reasoningContent!.isNotEmpty) {
      contentBlocks.add({
        'type': 'thinking',
        'thinking': msg.reasoningContent,
      });
    }

    // 2. Text block
    if (msg.content != null) {
      final text = msg.content is String ? msg.content as String : jsonEncode(msg.content);
      if (text.isNotEmpty) {
        contentBlocks.add({
          'type': 'text',
          'text': text,
        });
      }
    }

    // 3. Tool calls — don't fallback to ID when function name is empty (decolua/9router#2077, #3685)
    if (msg.toolCalls != null) {
      for (final tc in msg.toolCalls!) {
        if (tc.function.name.isEmpty) continue;

        final sanitizedArgs = sanitizeToolArgs(tc.function.name, tc.function.arguments);
        dynamic parsedInput;
        try {
          parsedInput = jsonDecode(sanitizedArgs);
        } catch (_) {
          parsedInput = sanitizedArgs;
        }

        contentBlocks.add({
          'type': 'tool_use',
          'id': tc.id,
          'name': tc.function.name,
          'input': parsedInput,
        });
      }
    }
  }

  var stopReason = 'end_turn';
  if (choice.finishReason == 'length') {
    stopReason = 'max_tokens';
  } else if (choice.finishReason == 'tool_calls') {
    stopReason = 'tool_use';
  }

  final usage = resp.usage ?? const OpenAIUsage();

  return {
    'id': msgId,
    'type': 'message',
    'role': 'assistant',
    'content': contentBlocks,
    'model': modelName,
    'stop_reason': stopReason,
    'stop_sequence': null,
    'usage': {
      'input_tokens': usage.promptTokens,
      'output_tokens': usage.completionTokens,
      'cache_read_input_tokens': usage.cachedTokens,
      'cache_creation_input_tokens': usage.cacheCreationInputTokens,
    },
  };
}

// ============================================================================
// 4. Streaming Response Translation (OpenAI SSE -> Claude SSE)
// ============================================================================

/// State store in-memory untuk streaming session.
/// Port dari `states` & `pendingJSON` di `internal/translator/usage.go`.
final Map<String, ClaudeStreamSessionState> _streamStates = {};
final Map<String, String> _pendingStreamFragments = {};

/// Menghapus state lama yang telah berumur lebih dari 10 menit jika ukuran map > 50.
/// Port dari `pruneStaleStatesLocked` di `internal/translator/usage.go`.
void pruneStaleStreamStates() {
  if (_streamStates.length < 50) return;
  final now = DateTime.now();
  final expiredKeys = <String>[];
  _streamStates.forEach((k, v) {
    if (now.difference(v.createdAt).inMinutes > 10) {
      expiredKeys.add(k);
    }
  });
  for (final k in expiredKeys) {
    _streamStates.remove(k);
    _pendingStreamFragments.remove(k);
  }
}

/// Menghapus state stream session tertentu dan buffer fragmen JSON-nya.
/// Port dari `ClearStreamState` di `internal/translator/usage.go`.
void clearStreamState(String sessionKey) {
  pruneStaleStreamStates();
  _streamStates.remove(sessionKey);
  _pendingStreamFragments.remove(sessionKey);
}

/// Mengambil akumulasi token usage untuk suatu session dan membersihkannya dari state.
/// Port dari `GetStreamUsage` di `internal/translator/usage.go`.
OpenAIUsage? getStreamUsage(String sessionKey) {
  pruneStaleStreamStates();
  _pendingStreamFragments.remove(sessionKey);
  final state = _streamStates.remove(sessionKey);
  return state?.usage;
}

/// Melakukan pre-seed session streaming dengan requested model name.
/// Port dari `SeedStreamState` di `internal/translator/usage.go`.
void seedStreamState(String sessionKey, String model) {
  if (sessionKey.isEmpty || model.isEmpty) return;
  pruneStaleStreamStates();
  final existing = _streamStates[sessionKey];
  if (existing != null) {
    if (existing.model.isEmpty) {
      existing.model = model;
    }
    return;
  }
  _streamStates[sessionKey] = ClaudeStreamSessionState(model: model);
}

/// Memformat Map event menjadi string SSE Claude (`event: <type>\ndata: <json>\n\n`).
/// Port dari `formatSSE` di `internal/translator/response.go`.
String formatSSE(Map<String, dynamic> event) {
  final eventType = event['type'] as String? ?? 'message';
  final payload = jsonEncode(event);
  return 'event: $eventType\ndata: $payload\n\n';
}

void _stopThinkingBlock(ClaudeStreamSessionState state, List<Map<String, dynamic>> results) {
  if (!state.thinkingBlockStarted) return;
  results.add({
    'type': 'content_block_stop',
    'index': state.thinkingBlockIndex,
  });
  state.thinkingBlockStarted = false;
}

void _stopTextBlock(ClaudeStreamSessionState state, List<Map<String, dynamic>> results) {
  if (!state.textBlockStarted || state.textBlockClosed) return;
  state.textBlockClosed = true;
  results.add({
    'type': 'content_block_stop',
    'index': state.textBlockIndex,
  });
  state.textBlockStarted = false;
}

/// Mentranslasikan OpenAI SSE chunk JSON menjadi Claude SSE event blocks (scoped per session).
/// Mengembalikan string kumpulan event SSE (`event: ...\ndata: ...\n\n`) atau string kosong jika ditahan/tidak ada event.
/// Port dari `TranslateOpenAIToClaudeStreamSession` di `internal/translator/response.go`.
String translateOpenAIToClaudeStreamSession(String sessionKey, String openaiChunkRaw) {
  var trimmed = openaiChunkRaw.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed == '[DONE]' || trimmed == 'data: [DONE]') {
    return 'data: [DONE]\n\n';
  }

  var dataPart = trimmed;
  if (trimmed.startsWith('data:')) {
    final sub = trimmed.substring(5).trim();
    if (sub == '[DONE]') {
      return 'data: [DONE]\n\n';
    }
    dataPart = sub;
  }

  // Rejoin fragment terpotong dari chunk sebelumnya jika ada
  if (sessionKey.isNotEmpty && _pendingStreamFragments.containsKey(sessionKey)) {
    dataPart = _pendingStreamFragments.remove(sessionKey)! + dataPart;
  }

  Map<String, dynamic> chunkMap;
  try {
    final decoded = jsonDecode(dataPart);
    if (decoded is! Map<String, dynamic>) {
      return '';
    }
    chunkMap = decoded;
  } catch (err) {
    // Cek jika kemungkinan JSON terpotong di tengah jalan (fragment)
    if (sessionKey.isNotEmpty && dataPart.length < (1024 * 1024)) {
      final errStr = err.toString();
      if (errStr.contains('Unexpected end of input') ||
          errStr.contains('FormatException: Unexpected end')) {
        _pendingStreamFragments[sessionKey] = dataPart;
        return '';
      }
    }
    throw FormatException('Failed to unmarshal stream chunk: $err');
  }

  final chunk = OpenAIChunk.fromJson(chunkMap);

  var stateKey = sessionKey;
  if (stateKey.isEmpty) {
    stateKey = chunk.id;
  }
  if (stateKey.isEmpty) {
    stateKey = 'default-session';
  }

  pruneStaleStreamStates();
  var state = _streamStates[stateKey];
  if (state == null) {
    if (chunk.choices.isEmpty) {
      return '';
    }
    var cleanId = chunk.id.replaceFirst('chatcmpl-', '');
    if (cleanId.isEmpty || cleanId == 'chat') {
      cleanId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    }
    var modelName = chunk.model;
    if (modelName.isEmpty) {
      modelName = 'claude-3-5-sonnet';
    }
    state = ClaudeStreamSessionState(
      messageId: cleanId,
      model: modelName,
    );
    _streamStates[stateKey] = state;
  }

  // Akumulasi Usage jika disertakan di chunk
  if (chunk.usage != null) {
    state.usage = OpenAIUsage(
      promptTokens: chunk.usage!.promptTokens > 0
          ? chunk.usage!.promptTokens
          : (state.usage?.promptTokens ?? 0),
      completionTokens: chunk.usage!.completionTokens > 0
          ? chunk.usage!.completionTokens
          : (state.usage?.completionTokens ?? 0),
      cachedTokens: chunk.usage!.cachedTokens > 0
          ? chunk.usage!.cachedTokens
          : (state.usage?.cachedTokens ?? 0),
      cacheCreationInputTokens: chunk.usage!.cacheCreationInputTokens > 0
          ? chunk.usage!.cacheCreationInputTokens
          : (state.usage?.cacheCreationInputTokens ?? 0),
    );
  }

  final results = <Map<String, dynamic>>[];

  // 1. Message Start
  if (!state.messageStartSent) {
    state.messageStartSent = true;
    results.add({
      'type': 'message_start',
      'message': {
        'id': state.messageId,
        'type': 'message',
        'role': 'assistant',
        'model': state.model,
        'content': <dynamic>[],
        'stop_reason': null,
        'stop_sequence': null,
        'usage': {
          'input_tokens': 0,
          'output_tokens': 0,
        },
      },
    });
  }

  if (chunk.choices.isEmpty) {
    if (results.isNotEmpty) {
      final buffer = StringBuffer();
      for (final res in results) {
        buffer.write(formatSSE(res));
      }
      return buffer.toString();
    }
    return '';
  }

  final choice = chunk.choices[0];
  final delta = choice.delta;

  // 2. Reasoning / Thinking
  final reasoningContent = delta?.reasoningContent ?? delta?.reasoning ?? '';
  if (reasoningContent.isNotEmpty) {
    _stopTextBlock(state, results);
    if (!state.thinkingBlockStarted) {
      state.thinkingBlockIndex = state.nextBlockIndex++;
      state.thinkingBlockStarted = true;
      results.add({
        'type': 'content_block_start',
        'index': state.thinkingBlockIndex,
        'content_block': {
          'type': 'thinking',
          'thinking': '',
        },
      });
    }
    results.add({
      'type': 'content_block_delta',
      'index': state.thinkingBlockIndex,
      'delta': {
        'type': 'thinking_delta',
        'thinking': reasoningContent,
      },
    });
  }

  // 3. Text Content
  final textContent = delta?.content ?? '';
  if (textContent.isNotEmpty) {
    _stopThinkingBlock(state, results);
    if (!state.textBlockStarted) {
      state.textBlockIndex = state.nextBlockIndex++;
      state.textBlockStarted = true;
      state.textBlockClosed = false;
      results.add({
        'type': 'content_block_start',
        'index': state.textBlockIndex,
        'content_block': {
          'type': 'text',
          'text': '',
        },
      });
    }
    results.add({
      'type': 'content_block_delta',
      'index': state.textBlockIndex,
      'delta': {
        'type': 'text_delta',
        'text': textContent,
      },
    });
  }

  // 4. Tool Calls
  if (delta?.toolCalls != null) {
    for (final tc in delta!.toolCalls!) {
      final idx = tc.index ?? 0;
      if (tc.id.isNotEmpty) {
        if (state.toolCalls.containsKey(idx)) {
          // Delta argument untuk tool yang sama
        } else {
          final toolName = tc.function.name;
          if (toolName.isEmpty) continue;

          _stopThinkingBlock(state, results);
          _stopTextBlock(state, results);

          final toolBlockIndex = state.nextBlockIndex++;
          state.toolCalls[idx] = ToolCallState(
            id: tc.id,
            name: toolName,
            blockIndex: toolBlockIndex,
          );
          results.add({
            'type': 'content_block_start',
            'index': toolBlockIndex,
            'content_block': {
              'type': 'tool_use',
              'id': tc.id,
              'name': toolName,
              'input': <String, dynamic>{},
            },
          });
        }
      }

      if (tc.function.arguments.isNotEmpty) {
        state.toolArgBuffers[idx] =
            (state.toolArgBuffers[idx] ?? '') + tc.function.arguments;
      }
    }
  }

  // 5. Finish Reason
  if (choice.finishReason != null && choice.finishReason!.isNotEmpty) {
    _stopThinkingBlock(state, results);
    _stopTextBlock(state, results);

    // Flush tool argument deltas & stops
    for (final entry in state.toolCalls.entries) {
      final idx = entry.key;
      final toolInfo = entry.value;
      final buffered = state.toolArgBuffers[idx] ?? '';
      final sanitized = sanitizeToolArgs(toolInfo.name, buffered);

      results.add({
        'type': 'content_block_delta',
        'index': toolInfo.blockIndex,
        'delta': {
          'type': 'input_json_delta',
          'partial_json': sanitized,
        },
      });
      results.add({
        'type': 'content_block_stop',
        'index': toolInfo.blockIndex,
      });
    }

    final finishReason = choice.finishReason!;
    state.finishReason = finishReason;

    var claudeStop = 'end_turn';
    if (finishReason == 'length') {
      claudeStop = 'max_tokens';
    } else if (finishReason == 'tool_calls') {
      claudeStop = 'tool_use';
    }

    final finalUsage = {
      'input_tokens': state.usage?.promptTokens ?? 0,
      'output_tokens': state.usage?.completionTokens ?? 0,
    };

    results.add({
      'type': 'message_delta',
      'delta': {
        'stop_reason': claudeStop,
        'stop_sequence': null,
      },
      'usage': finalUsage,
    });
    results.add({
      'type': 'message_stop',
    });
  }

  final buffer = StringBuffer();
  for (final res in results) {
    buffer.write(formatSSE(res));
  }
  return buffer.toString();
}

/// Mentranslasikan 1 OpenAI SSE chunk ke Claude SSE format tanpa session key eksplisit.
/// Port dari `TranslateOpenAIToClaudeStream` di `internal/translator/response.go`.
String translateOpenAIToClaudeStream(String openaiChunkRaw) {
  return translateOpenAIToClaudeStreamSession('', openaiChunkRaw);
}

/// Memastikan stream ditutup secara rapi jika terjadi interrupt atau koneksi upstream terputus tanpa finish_reason.
/// Port dari `EnsureStreamClosed` di `internal/translator/response.go`.
String ensureStreamClosed(String sessionKey) {
  if (sessionKey.isEmpty) return '';
  final state = _streamStates[sessionKey];
  if (state == null) return '';
  if (state.finishReason.isNotEmpty) {
    return ''; // Stream sudah ditutup secara bersih
  }

  state.finishReason = 'stop';
  final results = <Map<String, dynamic>>[];

  if (!state.messageStartSent) {
    state.messageStartSent = true;
    results.add({
      'type': 'message_start',
      'message': {
        'id': state.messageId,
        'type': 'message',
        'role': 'assistant',
        'model': state.model,
        'content': <dynamic>[],
        'stop_reason': null,
        'stop_sequence': null,
        'usage': {
          'input_tokens': 0,
          'output_tokens': 0,
        },
      },
    });
  }

  _stopThinkingBlock(state, results);
  _stopTextBlock(state, results);

  for (final entry in state.toolCalls.entries) {
    final idx = entry.key;
    final toolInfo = entry.value;
    final buffered = state.toolArgBuffers[idx] ?? '';
    final sanitized = sanitizeToolArgs(toolInfo.name, buffered);

    results.add({
      'type': 'content_block_delta',
      'index': toolInfo.blockIndex,
      'delta': {
        'type': 'input_json_delta',
        'partial_json': sanitized,
      },
    });
    results.add({
      'type': 'content_block_stop',
      'index': toolInfo.blockIndex,
    });
  }

  final finalUsage = {
    'input_tokens': state.usage?.promptTokens ?? 0,
    'output_tokens': state.usage?.completionTokens ?? 0,
  };

  results.add({
    'type': 'message_delta',
    'delta': {
      'stop_reason': 'end_turn',
      'stop_sequence': null,
    },
    'usage': finalUsage,
  });
  results.add({
    'type': 'message_stop',
  });

  final buffer = StringBuffer();
  for (final res in results) {
    buffer.write(formatSSE(res));
  }
  return buffer.toString();
}

// ============================================================================
// 5. Schema Sanitization (Gemini & OpenRouter Compatibility)
// ============================================================================

/// Daftar kata kunci JSON Schema Draft 7/8 yang ditolak oleh Protobuf parser Gemini.
const _geminiUnsupportedKeywords = [
  'minLength', 'maxLength', 'exclusiveMinimum', 'exclusiveMaximum',
  'minItems', 'maxItems', 'format', 'multipleOf',
  'uniqueItems', 'contains', 'unevaluatedProperties', 'unevaluatedItems', 'contentSchema',
  'default', 'examples',
  r'$schema', r'$defs', 'definitions', 'const', r'$ref', r'$comment',
  'deprecated', 'readOnly', 'writeOnly',
  'additionalProperties', 'propertyNames', 'patternProperties', 'enumDescriptions',
  'allOf', 'not',
  'dependencies', 'dependentSchemas', 'dependentRequired',
  'title', 'optional', 'if', 'then', 'else', 'contentMediaType', 'contentEncoding',
  'cornerRadius', 'fillColor', 'fontFamily', 'fontSize', 'fontWeight',
  'gap', 'padding', 'strokeColor', 'strokeThickness', 'textColor',
];

/// Membersihkan skema parameter JSON secara rekursif agar kompatibel dengan Gemini.
/// Port dari `cleanGeminiSchema` di `schema.go`.
void cleanGeminiSchema(Map<dynamic, dynamic> schema) {
  void stripUnsupported(Map<dynamic, dynamic> s) {
    for (final k in _geminiUnsupportedKeywords) {
      s.remove(k);
    }
    // Delete all vendor extensions (x- prefixes)
    final xKeys = s.keys.where((k) => k is String && k.startsWith('x-')).toList();
    for (final k in xKeys) {
      s.remove(k);
    }
  }

  stripUnsupported(schema);

  // Ensure type="object" if properties exist
  if (schema.containsKey('properties') && !schema.containsKey('type')) {
    schema['type'] = 'object';
  }

  // Ensure enum is string array and type="string"
  if (schema.containsKey('enum')) {
    final enumRaw = schema['enum'];
    if (enumRaw is List) {
      schema['enum'] = enumRaw.map((item) {
        if (item is String) return item;
        final encoded = jsonEncode(item);
        if (encoded.length >= 2 && encoded.startsWith('"') && encoded.endsWith('"')) {
          return encoded.substring(1, encoded.length - 1);
        }
        return encoded;
      }).toList();
      if (!schema.containsKey('type')) {
        schema['type'] = 'string';
      }
    }
  }

  // Flatten anyOf / oneOf
  for (final key in const ['anyOf', 'oneOf']) {
    if (schema.containsKey(key)) {
      final rawArr = schema[key];
      if (rawArr is List && rawArr.isNotEmpty) {
        for (final item in rawArr) {
          if (item is Map) {
            final t = item['type'];
            if (t == null || t != 'null') {
              schema.addAll(item);
              break;
            }
          }
        }
      }
      schema.remove(key);
    }
  }

  stripUnsupported(schema);

  // Flatten type arrays e.g. ["string", "null"] -> "string"
  if (schema.containsKey('type')) {
    final typeRaw = schema['type'];
    if (typeRaw is List && typeRaw.isNotEmpty) {
      String? firstValid;
      for (final t in typeRaw) {
        if (t is String && t != 'null') {
          firstValid = t;
          break;
        }
      }
      schema['type'] = firstValid ?? 'string';
    }
  }

  // Handle prefixItems (JSON Schema 2020-12 tuple)
  if (schema.containsKey('prefixItems')) {
    final prefixItemsRaw = schema['prefixItems'];
    if (!schema.containsKey('items') && prefixItemsRaw is List && prefixItemsRaw.isNotEmpty) {
      final first = prefixItemsRaw[0];
      if (first is Map) {
        schema['items'] = first;
      }
    }
    schema.remove('prefixItems');
  }

  // Ensure every array has an items schema
  if (schema['type'] == 'array') {
    if (!schema.containsKey('items')) {
      schema['items'] = <String, dynamic>{'type': 'string'};
    } else {
      final items = schema['items'];
      if (items is List) {
        if (items.isNotEmpty && items[0] is Map) {
          schema['items'] = items[0] as Map;
        } else {
          schema['items'] = <String, dynamic>{'type': 'string'};
        }
      } else if (items is Map) {
        if (items.isEmpty) {
          schema['items'] = <String, dynamic>{'type': 'string'};
        } else if (!items.containsKey('type') &&
            !items.containsKey('properties') &&
            !items.containsKey('items') &&
            !items.containsKey('enum')) {
          items['type'] = 'string';
        }
      }
    }
  }

  // Fix misplaced required inside properties
  if (schema.containsKey('properties') && schema['properties'] is Map) {
    final props = schema['properties'] as Map;
    if (props.containsKey('required') && props['required'] is! Map) {
      final reqVal = props.remove('required');
      if (!schema.containsKey('required')) {
        if (reqVal is List) {
          schema['required'] = reqVal;
        }
      }
    }
  }

  // Recurse into properties
  if (schema.containsKey('properties') && schema['properties'] is Map) {
    final props = schema['properties'] as Map;
    for (final val in props.values) {
      if (val is Map) {
        cleanGeminiSchema(val);
      }
    }
  }

  // Recurse into items
  if (schema.containsKey('items')) {
    final items = schema['items'];
    if (items is Map) {
      cleanGeminiSchema(items);
    } else if (items is List) {
      for (final item in items) {
        if (item is Map) {
          cleanGeminiSchema(item);
        }
      }
    }
  }

  // Clean up required array (must only contain keys present in properties)
  if (schema.containsKey('required')) {
    final reqRaw = schema['required'];
    final reqStrs = <String>[];
    if (reqRaw is List) {
      for (final r in reqRaw) {
        if (r is String) reqStrs.add(r);
      }
    }
    if (reqStrs.isNotEmpty && schema['properties'] is Map) {
      final props = schema['properties'] as Map;
      final validReqs = reqStrs.where(props.containsKey).toList();
      if (validReqs.isNotEmpty) {
        schema['required'] = validReqs;
      } else {
        schema.remove('required');
      }
    } else {
      schema.remove('required');
    }
  }

  // Add reason placeholder for empty object schemas
  if (schema['type'] == 'object') {
    var needsPlaceholder = true;
    if (schema['properties'] is Map) {
      final props = schema['properties'] as Map;
      if (props.isNotEmpty) needsPlaceholder = false;
    }
    if (needsPlaceholder) {
      schema['properties'] = <String, dynamic>{
        'reason': <String, dynamic>{
          'type': 'string',
          'description': 'Brief explanation of why you are calling this tool',
        },
      };
      schema['required'] = ['reason'];
    }
  }

  // Empty schema {} becomes object with placeholder
  if (schema.isEmpty) {
    schema['type'] = 'object';
    schema['properties'] = <String, dynamic>{
      'reason': <String, dynamic>{
        'type': 'string',
        'description': 'Brief explanation of why you are calling this tool',
      },
    };
    schema['required'] = ['reason'];
  }
}

/// Mem-parse dan membersihkan raw parameter schema JSON.
/// Port dari `CleanParametersSchema` di `schema.go`.
Map<String, dynamic> cleanParametersSchema(dynamic raw) {
  if (raw == null) {
    return {'type': 'object', 'properties': <String, dynamic>{}};
  }

  Map<String, dynamic> parsed;
  if (raw is Map<String, dynamic>) {
    parsed = Map<String, dynamic>.from(raw);
  } else if (raw is String) {
    try {
      parsed = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {'type': 'object', 'properties': <String, dynamic>{}};
    }
  } else {
    return {'type': 'object', 'properties': <String, dynamic>{}};
  }

  cleanGeminiSchema(parsed);
  return parsed;
}

/// Membersihkan skema parameter setiap tool dalam payload request OpenAI.
/// Port dari `SanitizeOpenAITools` di `schema.go`.
Map<String, dynamic> sanitizeOpenAITools(Map<String, dynamic> body) {
  final copy = Map<String, dynamic>.from(body);
  final toolsRaw = copy['tools'];
  if (toolsRaw is! List || toolsRaw.isEmpty) {
    return copy;
  }

  final updatedTools = <dynamic>[];
  for (final t in toolsRaw) {
    if (t is Map) {
      final tm = Map<String, dynamic>.from(t as Map<String, dynamic>);
      final fn = tm['function'];
      if (fn is Map) {
        final fnMap = Map<String, dynamic>.from(fn as Map<String, dynamic>);
        if (fnMap.containsKey('parameters')) {
          fnMap['parameters'] = cleanParametersSchema(fnMap['parameters']);
        }
        tm['function'] = fnMap;
      }
      updatedTools.add(tm);
    } else {
      updatedTools.add(t);
    }
  }

  copy['tools'] = updatedTools;
  return copy;
}

/// Menghapus regex pattern yang tidak valid dari skema tool (khususnya untuk OpenRouter).
/// Port dari `NormalizeToolSchemasForProvider` & `stripPatterns` di `tool_schema.go`.
List<dynamic> normalizeToolSchemasForProvider(String provider, List<dynamic> tools) {
  if (provider != 'openrouter' || tools.isEmpty) {
    return tools;
  }

  dynamic strip(dynamic schema) {
    if (schema is List) {
      return schema.map(strip).toList();
    }
    if (schema is Map) {
      final cleaned = <String, dynamic>{};
      for (final entry in schema.entries) {
        final key = entry.key as String;
        final value = entry.value;

        if (key == 'pattern' && value is String) {
          try {
            RegExp(value);
            cleaned[key] = value;
          } catch (_) {
            // Drop invalid regex pattern
          }
          continue;
        }

        if (key == 'properties' && value is Map) {
          final newProps = <String, dynamic>{};
          for (final prop in value.entries) {
            newProps[prop.key as String] = strip(prop.value);
          }
          cleaned[key] = newProps;
          continue;
        }

        cleaned[key] = strip(value);
      }
      return cleaned;
    }
    return schema;
  }

  final normalized = <dynamic>[];
  for (final t in tools) {
    if (t is Map) {
      final toolMap = Map<String, dynamic>.from(t as Map<String, dynamic>);
      if (toolMap['function'] is Map) {
        final fn = Map<String, dynamic>.from(toolMap['function'] as Map<String, dynamic>);
        if (fn.containsKey('parameters')) {
          fn['parameters'] = strip(fn['parameters']);
        }
        toolMap['function'] = fn;
      }
      normalized.add(toolMap);
    } else {
      normalized.add(t);
    }
  }
  return normalized;
}

// ============================================================================
// 5. Tool Argument Sanitization (A.U.R.A relevant tools: search, read, fetch)
// ============================================================================

/// Menormalisasi argumen tool yang dikirimkan oleh model LLM.
/// Port dari `sanitizeToolArgs` di `sanitize.go`.
String sanitizeToolArgs(String toolName, String argsJson) {
  var trimmed = argsJson.trim();
  if (trimmed.isEmpty || trimmed == 'null') {
    trimmed = '{}';
  }

  Map<String, dynamic> args;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) {
      args = decoded;
    } else if (decoded is String && decoded.isNotEmpty) {
      args = {'query': decoded};
    } else {
      args = {};
    }
  } catch (_) {
    return argsJson;
  }

  var name = toolName;
  if (name.startsWith('proxy_')) {
    name = name.substring(6);
  }
  final nameLower = name.toLowerCase();

  if (name == 'Read' || nameLower == 'view_file' || nameLower == 'read_file' || nameLower == 'read_app_file') {
    sanitizeReadArgs(args);
  } else if (nameLower.contains('search') || nameLower == 'websearch') {
    sanitizeSearchArgs(args, trimmed);
  } else if (nameLower.contains('fetch') || nameLower == 'web_fetch' || nameLower == 'read_url') {
    sanitizeFetchArgs(args);
  }

  return jsonEncode(args);
}

/// Menormalisasi argumen tool pencarian (query, q).
/// Port dari `sanitizeSearchArgs` di `sanitize.go`.
void sanitizeSearchArgs(Map<String, dynamic> args, String origJson) {
  // Unwrap wrappers
  for (final wrapper in const ['input', 'params', 'arguments', 'parameters']) {
    if (args[wrapper] is Map) {
      final wrapped = args[wrapper] as Map<String, dynamic>;
      for (final entry in wrapped.entries) {
        args.putIfAbsent(entry.key, () => entry.value);
      }
    }
  }

  if (!args.containsKey('query') || args['query'] == null) {
    if (args['q'] is String && (args['q'] as String).trim().isNotEmpty) {
      args['query'] = (args['q'] as String).trim();
    } else if (args['search_query'] is String) {
      args['query'] = (args['search_query'] as String).trim();
    } else {
      // Fallback: cari nilai string pertama yang bukan kosong
      for (final v in args.values) {
        if (v is String && v.trim().isNotEmpty) {
          args['query'] = v.trim();
          break;
        }
      }
      args.putIfAbsent('query', () => 'search');
    }
  }
}

/// Menormalisasi argumen tool pembacaan berkas (filename, path, file_path).
/// Port dari `sanitizeReadArgs` di `sanitize.go`.
void sanitizeReadArgs(Map<String, dynamic> args) {
  for (final wrapper in const ['input', 'params', 'arguments', 'parameters']) {
    if (args[wrapper] is Map) {
      final wrapped = args[wrapper] as Map<String, dynamic>;
      for (final entry in wrapped.entries) {
        args.putIfAbsent(entry.key, () => entry.value);
      }
    }
  }

  if (!args.containsKey('filename') && args.containsKey('path')) {
    args['filename'] = args['path'];
  } else if (!args.containsKey('filename') && args.containsKey('file_path')) {
    args['filename'] = args['file_path'];
  }
}

/// Menormalisasi argumen tool fetch / HTTP URL (url, uri, link, target_url).
/// Port dari `sanitizeFetchArgs` di `sanitize.go`.
void sanitizeFetchArgs(Map<String, dynamic> args) {
  for (final wrapper in const ['input', 'params', 'arguments', 'parameters']) {
    if (args[wrapper] is Map) {
      final wrapped = args[wrapper] as Map<String, dynamic>;
      for (final entry in wrapped.entries) {
        args.putIfAbsent(entry.key, () => entry.value);
      }
    }
  }

  if (!args.containsKey('url')) {
    for (final alt in const ['uri', 'link', 'href', 'website', 'target_url']) {
      if (args[alt] is String && (args[alt] as String).isNotEmpty) {
        args['url'] = args[alt];
        break;
      }
    }
  }
}
