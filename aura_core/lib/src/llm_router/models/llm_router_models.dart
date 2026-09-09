/// Data models untuk LLM Router — port dari definisi struct di 9router-go
/// (`internal/translator/`, `internal/handlers/chat/`).
///
/// Berisi model data immutable untuk request, response, content block, tool,
/// usage, dan konfigurasi multi-model.
library llm_router_models;

// ============================================================================
// OpenAI Models
// ============================================================================

/// URL gambar untuk OpenAI image content block.
/// Port dari `OpenAIImageUrl` di `internal/translator/types.go`.
class OpenAIImageUrl {
  final String url;
  final String? detail;

  const OpenAIImageUrl({
    required this.url,
    this.detail,
  });

  factory OpenAIImageUrl.fromJson(Map<String, dynamic> json) {
    return OpenAIImageUrl(
      url: json['url'] as String? ?? '',
      detail: json['detail'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'url': url};
    if (detail != null) map['detail'] = detail;
    return map;
  }
}

/// Content block untuk multimodal input pada OpenAI message.
/// Port dari `OpenAIContentBlock` di `internal/translator/types.go`.
class OpenAIContentBlock {
  final String type;
  final String? text;
  final OpenAIImageUrl? imageUrl;

  const OpenAIContentBlock({
    required this.type,
    this.text,
    this.imageUrl,
  });

  factory OpenAIContentBlock.fromJson(Map<String, dynamic> json) {
    return OpenAIContentBlock(
      type: json['type'] as String? ?? 'text',
      text: json['text'] as String?,
      imageUrl: json['image_url'] != null && json['image_url'] is Map<String, dynamic>
          ? OpenAIImageUrl.fromJson(json['image_url'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type};
    if (text != null) map['text'] = text;
    if (imageUrl != null) map['image_url'] = imageUrl!.toJson();
    return map;
  }
}

/// Representasi panggilan fungsi dalam tool call OpenAI.
/// Port dari `OpenAIFunctionCall` di `internal/translator/types.go`.
class OpenAIFunctionCall {
  final String name;
  final String arguments;

  const OpenAIFunctionCall({
    required this.name,
    required this.arguments,
  });

  factory OpenAIFunctionCall.fromJson(Map<String, dynamic> json) {
    return OpenAIFunctionCall(
      name: json['name'] as String? ?? '',
      arguments: json['arguments'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'arguments': arguments,
      };
}

/// Representasi tool call yang di-emit oleh OpenAI model.
/// Port dari `OpenAIToolCall` di `internal/translator/types.go`.
class OpenAIToolCall {
  final String id;
  final String type;
  final OpenAIFunctionCall function;
  final int? index;

  const OpenAIToolCall({
    required this.id,
    this.type = 'function',
    required this.function,
    this.index,
  });

  factory OpenAIToolCall.fromJson(Map<String, dynamic> json) {
    return OpenAIToolCall(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'function',
      function: json['function'] != null && json['function'] is Map<String, dynamic>
          ? OpenAIFunctionCall.fromJson(json['function'] as Map<String, dynamic>)
          : const OpenAIFunctionCall(name: '', arguments: ''),
      index: json['index'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'type': type,
      'function': function.toJson(),
    };
    if (index != null) map['index'] = index;
    return map;
  }
}

/// Message tunggal dalam format OpenAI chat completion.
/// Port dari `OpenAIMessage` di `internal/translator/types.go`.
class OpenAIMessage {
  final String role;
  /// Bisa berupa String murni atau List<OpenAIContentBlock> / List<Map<String, dynamic>>
  final dynamic content;
  final String? reasoningContent;
  final List<OpenAIToolCall>? toolCalls;
  final String? toolCallId;
  final String? name;

  const OpenAIMessage({
    required this.role,
    this.content,
    this.reasoningContent,
    this.toolCalls,
    this.toolCallId,
    this.name,
  });

  factory OpenAIMessage.fromJson(Map<String, dynamic> json) {
    List<OpenAIToolCall>? toolCalls;
    if (json['tool_calls'] is List) {
      toolCalls = (json['tool_calls'] as List)
          .whereType<Map<String, dynamic>>()
          .map(OpenAIToolCall.fromJson)
          .toList();
    }
    return OpenAIMessage(
      role: json['role'] as String? ?? 'user',
      content: json['content'],
      reasoningContent: json['reasoning_content'] as String?,
      toolCalls: toolCalls,
      toolCallId: json['tool_call_id'] as String?,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'role': role};
    if (content != null) map['content'] = content;
    if (reasoningContent != null) map['reasoning_content'] = reasoningContent;
    if (toolCalls != null && toolCalls!.isNotEmpty) {
      map['tool_calls'] = toolCalls!.map((e) => e.toJson()).toList();
    }
    if (toolCallId != null) map['tool_call_id'] = toolCallId;
    if (name != null) map['name'] = name;
    return map;
  }
}

/// Definisi skema fungsi OpenAI tool.
/// Port dari `OpenAIFunction` di `internal/translator/types.go`.
class OpenAIFunction {
  final String name;
  final String? description;
  final dynamic parameters;

  const OpenAIFunction({
    required this.name,
    this.description,
    this.parameters,
  });

  factory OpenAIFunction.fromJson(Map<String, dynamic> json) {
    return OpenAIFunction(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      parameters: json['parameters'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'name': name};
    if (description != null) map['description'] = description;
    if (parameters != null) map['parameters'] = parameters;
    return map;
  }
}

/// Definisi tool dalam OpenAI request format.
/// Port dari `OpenAITool` di `internal/translator/types.go`.
class OpenAITool {
  final String type;
  final OpenAIFunction function;

  const OpenAITool({
    this.type = 'function',
    required this.function,
  });

  factory OpenAITool.fromJson(Map<String, dynamic> json) {
    return OpenAITool(
      type: json['type'] as String? ?? 'function',
      function: json['function'] != null && json['function'] is Map<String, dynamic>
          ? OpenAIFunction.fromJson(json['function'] as Map<String, dynamic>)
          : const OpenAIFunction(name: ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'function': function.toJson(),
      };
}

/// Request payload format OpenAI `/v1/chat/completions`.
/// Port dari `OpenAIRequest` di `internal/translator/types.go`.
class OpenAIRequest {
  final String model;
  final List<OpenAIMessage> messages;
  final double? temperature;
  final int? maxTokens;
  final int? maxCompletionTokens;
  final bool? stream;
  final List<OpenAITool>? tools;
  final dynamic toolChoice;
  final String? reasoningEffort;

  const OpenAIRequest({
    required this.model,
    required this.messages,
    this.temperature,
    this.maxTokens,
    this.maxCompletionTokens,
    this.stream,
    this.tools,
    this.toolChoice,
    this.reasoningEffort,
  });

  factory OpenAIRequest.fromJson(Map<String, dynamic> json) {
    final msgs = (json['messages'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(OpenAIMessage.fromJson)
        .toList();

    List<OpenAITool>? tools;
    if (json['tools'] is List) {
      tools = (json['tools'] as List)
          .whereType<Map<String, dynamic>>()
          .map(OpenAITool.fromJson)
          .toList();
    }

    return OpenAIRequest(
      model: json['model'] as String? ?? '',
      messages: msgs,
      temperature: (json['temperature'] as num?)?.toDouble(),
      maxTokens: json['max_tokens'] as int?,
      maxCompletionTokens: json['max_completion_tokens'] as int?,
      stream: json['stream'] as bool?,
      tools: tools,
      toolChoice: json['tool_choice'],
      reasoningEffort: json['reasoning_effort'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
    if (temperature != null) map['temperature'] = temperature;
    if (maxTokens != null) map['max_tokens'] = maxTokens;
    if (maxCompletionTokens != null) {
      map['max_completion_tokens'] = maxCompletionTokens;
    }
    if (stream != null) map['stream'] = stream;
    if (tools != null && tools!.isNotEmpty) {
      map['tools'] = tools!.map((t) => t.toJson()).toList();
    }
    if (toolChoice != null) map['tool_choice'] = toolChoice;
    if (reasoningEffort != null) map['reasoning_effort'] = reasoningEffort;
    return map;
  }
}

/// Token usage tracking metrics.
/// Port dari `OpenAIUsage` di `internal/translator/types.go`.
class OpenAIUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int cachedTokens;
  final int cacheCreationInputTokens;

  const OpenAIUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    int? totalTokens,
    this.cachedTokens = 0,
    this.cacheCreationInputTokens = 0,
  }) : totalTokens = totalTokens ?? (promptTokens + completionTokens);

  factory OpenAIUsage.fromJson(Map<String, dynamic> json) {
    final pt = json['prompt_tokens'] as int? ?? 0;
    final ct = json['completion_tokens'] as int? ?? 0;
    final tt = json['total_tokens'] as int? ?? (pt + ct);
    final cached = json['cached_tokens'] as int? ?? 0;
    final cacheCreation = json['cache_creation_input_tokens'] as int? ?? 0;
    return OpenAIUsage(
      promptTokens: pt,
      completionTokens: ct,
      totalTokens: tt,
      cachedTokens: cached,
      cacheCreationInputTokens: cacheCreation,
    );
  }

  Map<String, dynamic> toJson() => {
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'total_tokens': totalTokens,
        'cached_tokens': cachedTokens,
        'cache_creation_input_tokens': cacheCreationInputTokens,
      };
}

/// Delta streaming chunk pada OpenAI completion.
/// Port dari `OpenAIDelta` di `internal/translator/types.go`.
class OpenAIDelta {
  final String? role;
  final String? content;
  final String? reasoningContent;
  final String? reasoning;
  final List<OpenAIToolCall>? toolCalls;

  const OpenAIDelta({
    this.role,
    this.content,
    this.reasoningContent,
    this.reasoning,
    this.toolCalls,
  });

  factory OpenAIDelta.fromJson(Map<String, dynamic> json) {
    List<OpenAIToolCall>? toolCalls;
    if (json['tool_calls'] is List) {
      toolCalls = (json['tool_calls'] as List)
          .whereType<Map<String, dynamic>>()
          .map(OpenAIToolCall.fromJson)
          .toList();
    }
    return OpenAIDelta(
      role: json['role'] as String?,
      content: json['content'] as String?,
      reasoningContent: json['reasoning_content'] as String?,
      reasoning: json['reasoning'] as String?,
      toolCalls: toolCalls,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (role != null) map['role'] = role;
    if (content != null) map['content'] = content;
    if (reasoningContent != null) map['reasoning_content'] = reasoningContent;
    if (reasoning != null) map['reasoning'] = reasoning;
    if (toolCalls != null) {
      map['tool_calls'] = toolCalls!.map((e) => e.toJson()).toList();
    }
    return map;
  }
}

/// Choice item pada response OpenAI.
/// Port dari `OpenAIChoice` di `internal/translator/types.go`.
class OpenAIChoice {
  final int index;
  final OpenAIMessage? message;
  final OpenAIDelta? delta;
  final String? finishReason;

  const OpenAIChoice({
    this.index = 0,
    this.message,
    this.delta,
    this.finishReason,
  });

  factory OpenAIChoice.fromJson(Map<String, dynamic> json) {
    return OpenAIChoice(
      index: json['index'] as int? ?? 0,
      message: json['message'] is Map<String, dynamic>
          ? OpenAIMessage.fromJson(json['message'] as Map<String, dynamic>)
          : null,
      delta: json['delta'] is Map<String, dynamic>
          ? OpenAIDelta.fromJson(json['delta'] as Map<String, dynamic>)
          : null,
      finishReason: json['finish_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'index': index};
    if (message != null) map['message'] = message!.toJson();
    if (delta != null) map['delta'] = delta!.toJson();
    if (finishReason != null) map['finish_reason'] = finishReason;
    return map;
  }
}

/// SSE stream chunk payload dari OpenAI-compatible stream.
/// Port dari `OpenAIChunk` di `internal/translator/types.go`.
class OpenAIChunk {
  final String id;
  final String model;
  final List<OpenAIChoice> choices;
  final OpenAIUsage? usage;

  const OpenAIChunk({
    this.id = '',
    this.model = '',
    this.choices = const [],
    this.usage,
  });

  factory OpenAIChunk.fromJson(Map<String, dynamic> json) {
    final choices = (json['choices'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(OpenAIChoice.fromJson)
        .toList();
    return OpenAIChunk(
      id: json['id'] as String? ?? '',
      model: json['model'] as String? ?? '',
      choices: choices,
      usage: json['usage'] is Map<String, dynamic>
          ? OpenAIUsage.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'model': model,
      'choices': choices.map((c) => c.toJson()).toList(),
    };
    if (usage != null) map['usage'] = usage!.toJson();
    return map;
  }
}

/// State parsial satu pemanggilan tool saat SSE streaming berlangsung.
/// Port dari `ToolCallState` di `internal/translator/types.go`.
class ToolCallState {
  final String id;
  final String name;
  final int blockIndex;

  const ToolCallState({
    required this.id,
    required this.name,
    required this.blockIndex,
  });
}

/// State per-session untuk translasi OpenAI SSE stream chunks ke Claude SSE events.
/// Port dari `StreamState` di `internal/translator/types.go`.
class ClaudeStreamSessionState {
  DateTime createdAt;
  bool messageStartSent;
  String messageId;
  String model;
  int nextBlockIndex;
  bool textBlockStarted;
  bool textBlockClosed;
  int textBlockIndex;
  bool thinkingBlockStarted;
  int thinkingBlockIndex;
  final Map<int, ToolCallState> toolCalls;
  final Map<int, String> toolArgBuffers;
  String finishReason;
  OpenAIUsage? usage;

  ClaudeStreamSessionState({
    DateTime? createdAt,
    this.messageStartSent = false,
    this.messageId = '',
    this.model = '',
    this.nextBlockIndex = 0,
    this.textBlockStarted = false,
    this.textBlockClosed = false,
    this.textBlockIndex = 0,
    this.thinkingBlockStarted = false,
    this.thinkingBlockIndex = 0,
    Map<int, ToolCallState>? toolCalls,
    Map<int, String>? toolArgBuffers,
    this.finishReason = '',
    this.usage,
  })  : createdAt = createdAt ?? DateTime.now(),
        toolCalls = toolCalls ?? {},
        toolArgBuffers = toolArgBuffers ?? {};
}

/// Response payload OpenAI chat completion.
/// Port dari `OpenAIResponse` di `internal/translator/types.go`.
class OpenAIResponse {
  final String id;
  final String object;
  final int created;
  final String model;
  final List<OpenAIChoice> choices;
  final OpenAIUsage? usage;

  const OpenAIResponse({
    required this.id,
    this.object = 'chat.completion',
    this.created = 0,
    required this.model,
    required this.choices,
    this.usage,
  });

  factory OpenAIResponse.fromJson(Map<String, dynamic> json) {
    final choices = (json['choices'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(OpenAIChoice.fromJson)
        .toList();
    return OpenAIResponse(
      id: json['id'] as String? ?? '',
      object: json['object'] as String? ?? 'chat.completion',
      created: json['created'] as int? ?? 0,
      model: json['model'] as String? ?? '',
      choices: choices,
      usage: json['usage'] is Map<String, dynamic>
          ? OpenAIUsage.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'object': object,
      'created': created,
      'model': model,
      'choices': choices.map((c) => c.toJson()).toList(),
    };
    if (usage != null) map['usage'] = usage!.toJson();
    return map;
  }
}

// ============================================================================
// Claude Models
// ============================================================================

/// Claude system block item.
/// Port dari `ClaudeSystemBlock` di `internal/translator/types.go`.
class ClaudeSystemBlock {
  final String type;
  final String text;

  const ClaudeSystemBlock({
    this.type = 'text',
    required this.text,
  });

  factory ClaudeSystemBlock.fromJson(Map<String, dynamic> json) {
    return ClaudeSystemBlock(
      type: json['type'] as String? ?? 'text',
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'text': text,
      };
}

/// Sumber gambar base64 Claude.
/// Port dari `ClaudeSource` di `internal/translator/types.go`.
class ClaudeSource {
  final String type;
  final String mediaType;
  final String data;

  const ClaudeSource({
    required this.type,
    required this.mediaType,
    required this.data,
  });

  factory ClaudeSource.fromJson(Map<String, dynamic> json) {
    return ClaudeSource(
      type: json['type'] as String? ?? 'base64',
      mediaType: json['media_type'] as String? ?? '',
      data: json['data'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'media_type': mediaType,
        'data': data,
      };
}

/// Content block untuk Claude message.
/// Port dari `ClaudeContentBlock` di `internal/translator/types.go`.
class ClaudeContentBlock {
  final String type;
  final String? text;
  final String? thinking;
  final ClaudeSource? source;
  final String? id;
  final String? name;
  final dynamic input;
  final String? toolUseId;
  final dynamic content;

  const ClaudeContentBlock({
    required this.type,
    this.text,
    this.thinking,
    this.source,
    this.id,
    this.name,
    this.input,
    this.toolUseId,
    this.content,
  });

  factory ClaudeContentBlock.fromJson(Map<String, dynamic> json) {
    return ClaudeContentBlock(
      type: json['type'] as String? ?? 'text',
      text: json['text'] as String?,
      thinking: json['thinking'] as String?,
      source: json['source'] is Map<String, dynamic>
          ? ClaudeSource.fromJson(json['source'] as Map<String, dynamic>)
          : null,
      id: json['id'] as String?,
      name: json['name'] as String?,
      input: json['input'],
      toolUseId: json['tool_use_id'] as String?,
      content: json['content'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type};
    if (text != null) map['text'] = text;
    if (thinking != null) map['thinking'] = thinking;
    if (source != null) map['source'] = source!.toJson();
    if (id != null) map['id'] = id;
    if (name != null) map['name'] = name;
    if (input != null) map['input'] = input;
    if (toolUseId != null) map['tool_use_id'] = toolUseId;
    if (content != null) map['content'] = content;
    return map;
  }
}

/// Claude message item.
/// Port dari `ClaudeMessage` di `internal/translator/types.go`.
class ClaudeMessage {
  final String role;
  /// String murni atau List<ClaudeContentBlock> / List<Map<String, dynamic>>
  final dynamic content;

  const ClaudeMessage({
    required this.role,
    required this.content,
  });

  factory ClaudeMessage.fromJson(Map<String, dynamic> json) {
    return ClaudeMessage(
      role: json['role'] as String? ?? 'user',
      content: json['content'],
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };
}

/// Konfigurasi thinking Claude.
/// Port dari `ClaudeThinking` di `internal/translator/types.go`.
class ClaudeThinkingConfig {
  final String type;
  final int budget;

  const ClaudeThinkingConfig({
    required this.type,
    this.budget = 0,
  });

  factory ClaudeThinkingConfig.fromJson(Map<String, dynamic> json) {
    return ClaudeThinkingConfig(
      type: json['type'] as String? ?? 'disabled',
      budget: json['budget_tokens'] as int? ?? json['budget'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'budget_tokens': budget,
      };
}

/// Konfigurasi output Claude (misal adaptive thinking effort).
/// Port dari `ClaudeOutputConfig` di `internal/translator/types.go`.
class ClaudeOutputConfig {
  final String? effort;

  const ClaudeOutputConfig({this.effort});

  factory ClaudeOutputConfig.fromJson(Map<String, dynamic> json) {
    return ClaudeOutputConfig(
      effort: json['effort'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (effort != null) map['effort'] = effort;
    return map;
  }
}

/// Tool choice Claude.
/// Port dari `ClaudeToolChoice` di `internal/translator/types.go`.
class ClaudeToolChoice {
  final String type;
  final String? name;

  const ClaudeToolChoice({
    required this.type,
    this.name,
  });

  factory ClaudeToolChoice.fromJson(Map<String, dynamic> json) {
    return ClaudeToolChoice(
      type: json['type'] as String? ?? 'auto',
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type};
    if (name != null) map['name'] = name;
    return map;
  }
}

/// Definisi tool Claude format.
/// Port dari `ClaudeTool` di `internal/translator/types.go`.
class ClaudeTool {
  final String name;
  final String? description;
  final dynamic inputSchema;
  final String? type;
  final bool? deferLoading;
  final Map<String, dynamic>? cacheControl;

  const ClaudeTool({
    required this.name,
    this.description,
    this.inputSchema,
    this.type,
    this.deferLoading,
    this.cacheControl,
  });

  factory ClaudeTool.fromJson(Map<String, dynamic> json) {
    return ClaudeTool(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      inputSchema: json['input_schema'],
      type: json['type'] as String?,
      deferLoading: json['defer_loading'] as bool?,
      cacheControl: json['cache_control'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'name': name};
    if (description != null) map['description'] = description;
    if (inputSchema != null) map['input_schema'] = inputSchema;
    if (type != null) map['type'] = type;
    if (deferLoading != null) map['defer_loading'] = deferLoading;
    if (cacheControl != null) map['cache_control'] = cacheControl;
    return map;
  }
}

/// Request body format Claude Messages API.
/// Port dari `ClaudeRequest` di `internal/translator/types.go`.
class ClaudeRequest {
  final String model;
  final List<ClaudeMessage> messages;
  final dynamic system;
  final double? temperature;
  final int? maxTokens;
  final bool? stream;
  final List<ClaudeTool>? tools;
  final dynamic toolChoice;
  final ClaudeThinkingConfig? thinking;
  final ClaudeOutputConfig? outputConfig;

  const ClaudeRequest({
    required this.model,
    required this.messages,
    this.system,
    this.temperature,
    this.maxTokens,
    this.stream,
    this.tools,
    this.toolChoice,
    this.thinking,
    this.outputConfig,
  });

  factory ClaudeRequest.fromJson(Map<String, dynamic> json) {
    final msgs = (json['messages'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ClaudeMessage.fromJson)
        .toList();

    List<ClaudeTool>? tools;
    if (json['tools'] is List) {
      tools = (json['tools'] as List)
          .whereType<Map<String, dynamic>>()
          .map(ClaudeTool.fromJson)
          .toList();
    }

    return ClaudeRequest(
      model: json['model'] as String? ?? '',
      messages: msgs,
      system: json['system'],
      temperature: (json['temperature'] as num?)?.toDouble(),
      maxTokens: json['max_tokens'] as int?,
      stream: json['stream'] as bool?,
      tools: tools,
      toolChoice: json['tool_choice'],
      thinking: json['thinking'] is Map<String, dynamic>
          ? ClaudeThinkingConfig.fromJson(json['thinking'] as Map<String, dynamic>)
          : null,
      outputConfig: json['output_config'] is Map<String, dynamic>
          ? ClaudeOutputConfig.fromJson(json['output_config'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
    if (system != null) map['system'] = system;
    if (temperature != null) map['temperature'] = temperature;
    if (maxTokens != null) map['max_tokens'] = maxTokens;
    if (stream != null) map['stream'] = stream;
    if (tools != null && tools!.isNotEmpty) {
      map['tools'] = tools!.map((t) => t.toJson()).toList();
    }
    if (toolChoice != null) map['tool_choice'] = toolChoice;
    if (thinking != null) map['thinking'] = thinking!.toJson();
    if (outputConfig != null) map['output_config'] = outputConfig!.toJson();
    return map;
  }
}

// ============================================================================
// Model Resolution & Fusion Models
// ============================================================================

/// Informasi model konkret yang berhasil di-resolve dari string identifier.
/// Port dari `ModelInfo` di `internal/handlers/chat/resolution.go`.
class ModelInfo {
  final String provider;
  final String model;
  final String? connectionId;
  final List<String>? comboModels;
  final String? strategy;

  const ModelInfo({
    required this.provider,
    required this.model,
    this.connectionId,
    this.comboModels,
    this.strategy,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'provider': provider,
      'model': model,
    };
    if (connectionId != null) map['connection_id'] = connectionId;
    if (comboModels != null) map['combo_models'] = comboModels;
    if (strategy != null) map['strategy'] = strategy;
    return map;
  }
}

/// Hasil jawaban dari satu model panel dalam proses model fusion.
/// Port dari `fusionAnswer` di `internal/handlers/chat/combo_fusion.go`.
class FusionAnswer {
  final String model;
  final String text;

  const FusionAnswer({
    required this.model,
    required this.text,
  });
}

/// Hasil eksekusi satu call panel fusion.
/// Port dari `fusionResult` di `internal/handlers/chat/combo_fusion.go`.
class FusionResult {
  final String model;
  final bool ok;
  final String? text;
  final dynamic error;

  const FusionResult({
    required this.model,
    this.ok = false,
    this.text,
    this.error,
  });
}

/// Parameter konfigurasi timeout dan quorum untuk model-fusion panel.
/// Port dari `FusionTuning` di `internal/handlers/chat/combo_fusion.go`
/// dan Addendum Section 3.
class FusionTuning {
  final int minPanel;
  final int stragglerGraceMs;
  final int panelHardTimeoutMs;

  const FusionTuning({
    this.minPanel = 2,
    this.stragglerGraceMs = 8000,
    this.panelHardTimeoutMs = 90000,
  });
}
