import 'dart:convert';
import 'package:test/test.dart';
import 'package:aura_core/src/llm_router/format_translator.dart';
import 'package:aura_core/src/llm_router/models/llm_router_models.dart';

void main() {
  group('format_translator - Request Translation', () {
    test('requiresMaxCompletionTokens detects gpt-5 and o-series', () {
      expect(requiresMaxCompletionTokens('gpt-5'), isTrue);
      expect(requiresMaxCompletionTokens('openai/gpt-5-turbo'), isTrue);
      expect(requiresMaxCompletionTokens('o1-mini'), isTrue);
      expect(requiresMaxCompletionTokens('o3-pro'), isTrue);
      expect(requiresMaxCompletionTokens('o4-preview'), isTrue);
      expect(requiresMaxCompletionTokens('gpt-4o'), isFalse);
      expect(requiresMaxCompletionTokens('claude-3-5-sonnet'), isFalse);
    });

    test('stripAnthropicBillingHeader removes billing headers', () {
      const input = 'x-anthropic-billing-header: test-header\nReal system prompt here';
      expect(stripAnthropicBillingHeader(input), equals('Real system prompt here'));
    });

    test('parseSystemPrompt handles string and blocks', () {
      expect(parseSystemPrompt('Hello system'), equals('Hello system'));
      expect(
        parseSystemPrompt([
          {'type': 'text', 'text': 'Part 1'},
          {'type': 'text', 'text': 'Part 2'},
        ]),
        equals('Part 1\nPart 2'),
      );
    });

    test('convertClaudeMessage handles text, thinking, and tool_use', () {
      const msg = ClaudeMessage(
        role: 'assistant',
        content: [
          {'type': 'thinking', 'thinking': 'Let me ponder this...'},
          {'type': 'text', 'text': 'I will search now.'},
          {
            'type': 'tool_use',
            'id': 'call_123',
            'name': 'search_web',
            'input': {'query': 'Flutter Dart'},
          }
        ],
      );

      final converted = convertClaudeMessage(msg);
      expect(converted.length, equals(1));
      final omsg = converted[0];
      expect(omsg.role, equals('assistant'));
      expect(omsg.reasoningContent, equals('Let me ponder this...'));
      expect(omsg.content, equals('I will search now.'));
      expect(omsg.toolCalls, isNotNull);
      expect(omsg.toolCalls!.length, equals(1));
      expect(omsg.toolCalls![0].id, equals('call_123'));
      expect(omsg.toolCalls![0].function.name, equals('search_web'));
    });

    test('convertClaudeMessage handles base64 image', () {
      const msg = ClaudeMessage(
        role: 'user',
        content: [
          {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': 'image/png',
              'data': 'iVBORw0KGgoAAAANSUhEUgAA...',
            }
          },
          {'type': 'text', 'text': 'What is this image?'}
        ],
      );

      final converted = convertClaudeMessage(msg);
      expect(converted.length, equals(1));
      final content = converted[0].content;
      expect(content, isA<List>());
      final list = content as List;
      expect(list.length, equals(2));
      expect(list[0]['type'], equals('image_url'));
      expect(list[0]['image_url']['url'], startsWith('data:image/png;base64,'));
    });

    test('fixMissingToolResponsesOpenAI inserts placeholder for unanswered tool calls', () {
      final messages = [
        const OpenAIMessage(
          role: 'assistant',
          toolCalls: [
            OpenAIToolCall(
              id: 'call_1',
              function: OpenAIFunctionCall(name: 't1', arguments: '{}'),
            ),
            OpenAIToolCall(
              id: 'call_2',
              function: OpenAIFunctionCall(name: 't2', arguments: '{}'),
            ),
          ],
        ),
        // Hanya call_1 yang dijawab
        const OpenAIMessage(role: 'tool', toolCallId: 'call_1', content: 'OK 1'),
      ];

      final fixed = fixMissingToolResponsesOpenAI(messages);
      expect(fixed.length, equals(3));
      expect(fixed[0].role, equals('assistant'));
      expect(fixed[1].toolCallId, equals('call_1'));
      expect(fixed[2].toolCallId, equals('call_2'));
      expect(fixed[2].content, equals('[No response received]'));
    });

    test('translateClaudeToOpenAI transforms complete request payload', () {
      final claudeReq = {
        'model': 'claude-3-5-sonnet-20241022',
        'system': 'You are AURA.',
        'messages': [
          {'role': 'user', 'content': 'Help me'}
        ],
        'tools': [
          {
            'name': 'calculator',
            'description': 'Simple calc',
            'input_schema': {
              'type': 'object',
              'properties': {
                'expr': {'type': 'string'}
              },
              'required': ['expr']
            }
          }
        ],
        'tool_choice': {'type': 'auto'},
        'thinking': {'type': 'enabled', 'budget_tokens': 10000},
      };

      final oreq = translateClaudeToOpenAI(claudeReq);
      expect(oreq['model'], equals('claude-3-5-sonnet-20241022'));
      final msgs = oreq['messages'] as List;
      expect(msgs[0]['role'], equals('system'));
      expect(msgs[0]['content'], equals('You are AURA.'));
      expect(msgs[1]['role'], equals('user'));
      expect(msgs[1]['content'], equals('Help me'));

      final tools = oreq['tools'] as List;
      expect(tools.length, equals(1));
      expect(tools[0]['type'], equals('function'));
      expect(tools[0]['function']['name'], equals('calculator'));

      expect(oreq['tool_choice'], equals('auto'));
      expect(oreq['reasoning_effort'], equals('medium'));
    });
  });

  group('format_translator - Claude Compatibility & Pipeline', () {
    test('sanitizeClaudePassthrough drops invalid server_tool_use and orphan results', () {
      final input = {
        'messages': [
          {
            'role': 'assistant',
            'content': [
              // Valid
              {'type': 'server_tool_use', 'id': 'srvtoolu_valid123', 'name': 'valid_tool'},
              // Foreign ID from non-Anthropic provider
              {'type': 'server_tool_use', 'id': 'call_foreign456', 'name': 'bad_tool'},
              {'type': 'text', 'text': 'Here is text.'},
              {'type': 'text', 'text': '   '}, // Empty text to strip
            ]
          },
          {
            'role': 'user',
            'content': [
              {'type': 'tool_result', 'tool_use_id': 'srvtoolu_valid123', 'content': 'res 1'},
              {'type': 'tool_result', 'tool_use_id': 'call_foreign456', 'content': 'orphan res'},
            ]
          }
        ]
      };

      final sanitized = sanitizeClaudePassthrough(input);
      final msgs = sanitized['messages'] as List;
      final aContent = msgs[0]['content'] as List;
      expect(aContent.length, equals(2));
      expect(aContent[0]['id'], equals('srvtoolu_valid123'));
      expect(aContent[1]['text'], equals('Here is text.'));

      final uContent = msgs[1]['content'] as List;
      expect(uContent.length, equals(1));
      expect(uContent[0]['tool_use_id'], equals('srvtoolu_valid123'));
    });

    test('defaultClaudeToolType ensures custom type for tools without type', () {
      final input = {
        'tools': [
          {'name': 't1', 'type': 'bash_20250124'},
          {'name': 't2'}, // Missing type
        ]
      };

      final output = defaultClaudeToolType(input);
      final tools = output['tools'] as List;
      expect(tools[0]['type'], equals('bash_20250124'));
      expect(tools[1]['type'], equals('custom'));
    });

    test('anchorClaudeCache places ephemeral cache_control on last non-deferred tool', () {
      final input = {
        'tools': [
          {'name': 't1', 'defer_loading': false},
          {'name': 't2', 'defer_loading': false},
          {'name': 't3', 'defer_loading': true}, // Tail deferred tool
        ]
      };

      final output = anchorClaudeCache(input);
      final tools = output['tools'] as List;
      expect(tools[0].containsKey('cache_control'), isFalse);
      expect(tools[1]['cache_control'], equals({'type': 'ephemeral', 'ttl': '1h'}));
      expect(tools[2].containsKey('cache_control'), isFalse);
    });

    test('applyClaudeCompatPipeline executes 3 steps in correct sequence', () {
      final input = {
        'messages': [
          {
            'role': 'assistant',
            'content': [
              {'type': 'server_tool_use', 'id': 'call_foreign', 'name': 't'},
              {'type': 'text', 'text': 'Hello'},
            ]
          }
        ],
        'tools': [
          {'name': 'tool_a'}, // No type, not deferred
        ]
      };

      final output = applyClaudeCompatPipeline(input);
      final msgs = output['messages'] as List;
      final content = msgs[0]['content'] as List;
      expect(content.length, equals(1));
      expect(content[0]['text'], equals('Hello'));

      final tools = output['tools'] as List;
      expect(tools[0]['type'], equals('custom'));
      expect(tools[0]['cache_control'], equals({'type': 'ephemeral', 'ttl': '1h'}));
    });
  });

  group('format_translator - Usage & Response Translation', () {
    test('parseClaudeUsage extracts tokens and cache metrics', () {
      final claudeBody = {
        'usage': {
          'input_tokens': 100,
          'output_tokens': 50,
          'cache_read_input_tokens': 25,
          'cache_creation_input_tokens': 10,
        }
      };

      final usage = parseClaudeUsage(claudeBody);
      expect(usage, isNotNull);
      expect(usage!.promptTokens, equals(100));
      expect(usage.completionTokens, equals(50));
      expect(usage.cachedTokens, equals(25));
      expect(usage.cacheCreationInputTokens, equals(10));
    });

    test('translateOpenAIToClaude transforms chat completion response', () {
      final openaiResp = {
        'id': 'chatcmpl-test1234',
        'object': 'chat.completion',
        'created': 1234567,
        'model': 'gpt-4o',
        'choices': [
          {
            'index': 0,
            'message': {
              'role': 'assistant',
              'content': 'Result answer',
              'reasoning_content': 'Reasoning step',
            },
            'finish_reason': 'stop'
          }
        ],
        'usage': {
          'prompt_tokens': 40,
          'completion_tokens': 20,
          'total_tokens': 60,
        }
      };

      final claude = translateOpenAIToClaude(openaiResp);
      expect(claude['type'], equals('message'));
      expect(claude['role'], equals('assistant'));
      expect(claude['model'], equals('gpt-4o'));
      expect(claude['stop_reason'], equals('end_turn'));

      final blocks = claude['content'] as List;
      expect(blocks.length, equals(2));
      expect(blocks[0]['type'], equals('thinking'));
      expect(blocks[0]['thinking'], equals('Reasoning step'));
      expect(blocks[1]['type'], equals('text'));
      expect(blocks[1]['text'], equals('Result answer'));

      final usage = claude['usage'] as Map;
      expect(usage['input_tokens'], equals(40));
      expect(usage['output_tokens'], equals(20));
    });
  });

  group('format_translator - Schema & Tool Sanitization', () {
    test('cleanGeminiSchema removes unsupported keywords and adds object placeholder', () {
      final schema = {
        'type': 'object',
        'minLength': 5,
        'maxLength': 100,
        'default': 'test',
        'x-vendor': 'secret',
        'properties': {},
      };

      cleanGeminiSchema(schema);
      expect(schema.containsKey('minLength'), isFalse);
      expect(schema.containsKey('maxLength'), isFalse);
      expect(schema.containsKey('default'), isFalse);
      expect(schema.containsKey('x-vendor'), isFalse);
      // Added reason placeholder for empty object
      final props = schema['properties'] as Map;
      expect(props.containsKey('reason'), isTrue);
      expect(schema['required'], equals(['reason']));
    });

    test('normalizeToolSchemasForProvider strips invalid regex for openrouter', () {
      final tools = [
        {
          'type': 'function',
          'function': {
            'name': 'search',
            'parameters': {
              'type': 'object',
              'properties': {
                'valid_regex': {'type': 'string', 'pattern': r'^[a-z]+$'},
                'invalid_regex': {'type': 'string', 'pattern': r'([a-z++'},
              }
            }
          }
        }
      ];

      final normalized = normalizeToolSchemasForProvider('openrouter', tools);
      final params = normalized[0]['function']['parameters'] as Map;
      final props = params['properties'] as Map;
      expect(props['valid_regex'].containsKey('pattern'), isTrue);
      expect(props['invalid_regex'].containsKey('pattern'), isFalse);
    });

    test('sanitizeToolArgs normalizes search and file read arguments', () {
      // Search with q instead of query
      final searchArgs = sanitizeToolArgs('web_search', jsonEncode({'q': 'Antigravity AI'}));
      final searchDecoded = jsonDecode(searchArgs) as Map;
      expect(searchDecoded['query'], equals('Antigravity AI'));

      // Read file with path instead of filename
      final readArgs = sanitizeToolArgs('read_app_file', jsonEncode({'path': 'settings.json'}));
      final readDecoded = jsonDecode(readArgs) as Map;
      expect(readDecoded['filename'], equals('settings.json'));
    });
  });

  group('format_translator - Streaming Response Translation', () {
    setUp(() {
      clearStreamState('session_1');
      clearStreamState('session_tool');
    });

    test('translateOpenAIToClaudeStreamSession streams message_start, text, and finish', () {
      const session = 'session_1';

      // Chunk 1: text delta
      final chunk1 = jsonEncode({
        'id': 'chatcmpl-stream1',
        'model': 'gpt-4o',
        'choices': [
          {
            'index': 0,
            'delta': {'role': 'assistant', 'content': 'Hello'},
          }
        ]
      });

      final sse1 = translateOpenAIToClaudeStreamSession(session, chunk1);
      expect(sse1, contains('event: message_start'));
      expect(sse1, contains('event: content_block_start'));
      expect(sse1, contains('"type":"text"'));
      expect(sse1, contains('event: content_block_delta'));
      expect(sse1, contains('"text":"Hello"'));

      // Chunk 2: text continuation
      final chunk2 = jsonEncode({
        'id': 'chatcmpl-stream1',
        'model': 'gpt-4o',
        'choices': [
          {
            'index': 0,
            'delta': {'content': ' World!'},
          }
        ]
      });

      final sse2 = translateOpenAIToClaudeStreamSession(session, chunk2);
      expect(sse2, isNot(contains('event: message_start')));
      expect(sse2, contains('event: content_block_delta'));
      expect(sse2, contains('"text":" World!"'));

      // Chunk 3: finish chunk with usage
      final chunk3 = jsonEncode({
        'id': 'chatcmpl-stream1',
        'model': 'gpt-4o',
        'choices': [
          {
            'index': 0,
            'delta': {},
            'finish_reason': 'stop',
          }
        ],
        'usage': {
          'prompt_tokens': 10,
          'completion_tokens': 5,
        }
      });

      final sse3 = translateOpenAIToClaudeStreamSession(session, chunk3);
      expect(sse3, contains('event: content_block_stop'));
      expect(sse3, contains('event: message_delta'));
      expect(sse3, contains('"stop_reason":"end_turn"'));
      expect(sse3, contains('"input_tokens":10'));
      expect(sse3, contains('event: message_stop'));

      final usage = getStreamUsage(session);
      expect(usage, isNotNull);
      expect(usage!.promptTokens, equals(10));
      expect(usage.completionTokens, equals(5));
    });

    test('translateOpenAIToClaudeStreamSession streams reasoning before text', () {
      const session = 'session_reasoning';
      final chunk = jsonEncode({
        'id': 'chatcmpl-stream2',
        'choices': [
          {
            'index': 0,
            'delta': {
              'reasoning_content': 'Thinking about this...',
              'content': 'Result answer',
            }
          }
        ]
      });

      final sse = translateOpenAIToClaudeStreamSession(session, chunk);
      expect(sse, contains('"type":"thinking"'));
      expect(sse, contains('"thinking":"Thinking about this..."'));
      expect(sse, contains('"type":"text"'));
      expect(sse, contains('"text":"Result answer"'));
      clearStreamState(session);
    });

    test('translateOpenAIToClaudeStreamSession streams tool calls and buffers input', () {
      const session = 'session_tool';

      // Tool call start
      final chunk1 = jsonEncode({
        'id': 'chatcmpl-stream-tool',
        'choices': [
          {
            'index': 0,
            'delta': {
              'tool_calls': [
                {
                  'index': 0,
                  'id': 'call_abc',
                  'type': 'function',
                  'function': {
                    'name': 'web_search',
                    'arguments': '{"q":"Flut',
                  }
                }
              ]
            }
          }
        ]
      });

      final sse1 = translateOpenAIToClaudeStreamSession(session, chunk1);
      expect(sse1, contains('event: content_block_start'));
      expect(sse1, contains('"type":"tool_use"'));
      expect(sse1, contains('"name":"web_search"'));

      // Tool call arg delta
      final chunk2 = jsonEncode({
        'id': 'chatcmpl-stream-tool',
        'choices': [
          {
            'index': 0,
            'delta': {
              'tool_calls': [
                {
                  'index': 0,
                  'function': {
                    'arguments': 'ter"}',
                  }
                }
              ]
            }
          }
        ]
      });

      translateOpenAIToClaudeStreamSession(session, chunk2);

      // Finish tool call
      final chunk3 = jsonEncode({
        'id': 'chatcmpl-stream-tool',
        'choices': [
          {
            'index': 0,
            'delta': {},
            'finish_reason': 'tool_calls',
          }
        ]
      });

      final sse3 = translateOpenAIToClaudeStreamSession(session, chunk3);
      expect(sse3, contains('event: content_block_delta'));
      expect(sse3, contains('"type":"input_json_delta"'));
      // sanitizeToolArgs should convert {"q": "Flutter"} to query inside the json-encoded payload
      expect(sse3, contains(r'\"query\":\"Flutter\"'));
      expect(sse3, contains('"stop_reason":"tool_use"'));
      expect(sse3, contains('event: message_stop'));
    });

    test('ensureStreamClosed generates message_stop if stream ends abruptly', () {
      const session = 'session_abrupt';

      final chunk = jsonEncode({
        'id': 'chatcmpl-abrupt',
        'choices': [
          {
            'index': 0,
            'delta': {'content': 'Partial text'},
          }
        ]
      });

      translateOpenAIToClaudeStreamSession(session, chunk);

      final closingSSE = ensureStreamClosed(session);
      expect(closingSSE, contains('event: content_block_stop'));
      expect(closingSSE, contains('event: message_delta'));
      expect(closingSSE, contains('"stop_reason":"end_turn"'));
      expect(closingSSE, contains('event: message_stop'));

      clearStreamState(session);
    });

    test('translateOpenAIToClaudeStreamSession correctly handles parallel tool calls with index', () {
      const session = 'session_parallel_tools';

      // Chunk 1: Two parallel tool calls announced (index 0 and index 1)
      final chunk1 = jsonEncode({
        'id': 'chatcmpl-parallel',
        'choices': [
          {
            'index': 0,
            'delta': {
              'tool_calls': [
                {
                  'index': 0,
                  'id': 'call_tool_0',
                  'type': 'function',
                  'function': {'name': 'web_search', 'arguments': '{"q":'}
                },
                {
                  'index': 1,
                  'id': 'call_tool_1',
                  'type': 'function',
                  'function': {'name': 'read_file', 'arguments': '{"path":'}
                }
              ]
            }
          }
        ]
      });

      final sse1 = translateOpenAIToClaudeStreamSession(session, chunk1);
      expect(sse1, contains('"name":"web_search"'));
      expect(sse1, contains('"name":"read_file"'));

      // Chunk 2: Tool 0 gets argument delta
      final chunk2 = jsonEncode({
        'id': 'chatcmpl-parallel',
        'choices': [
          {
            'index': 0,
            'delta': {
              'tool_calls': [
                {
                  'index': 0,
                  'function': {'arguments': '"AURA AI"}'}
                }
              ]
            }
          }
        ]
      });
      translateOpenAIToClaudeStreamSession(session, chunk2);

      // Chunk 3: Tool 1 gets argument delta
      final chunk3 = jsonEncode({
        'id': 'chatcmpl-parallel',
        'choices': [
          {
            'index': 0,
            'delta': {
              'tool_calls': [
                {
                  'index': 1,
                  'function': {'arguments': '"config.json"}'}
                }
              ]
            }
          }
        ]
      });
      translateOpenAIToClaudeStreamSession(session, chunk3);

      // Chunk 4: Finish tool_calls
      final chunk4 = jsonEncode({
        'id': 'chatcmpl-parallel',
        'choices': [
          {
            'index': 0,
            'delta': {},
            'finish_reason': 'tool_calls',
          }
        ]
      });

      final sse4 = translateOpenAIToClaudeStreamSession(session, chunk4);
      // Tool 0 must get query, Tool 1 must get filename
      expect(sse4, contains(r'\"query\":\"AURA AI\"'));
      expect(sse4, contains(r'\"filename\":\"config.json\"'));
      expect(sse4, contains('"stop_reason":"tool_use"'));

      clearStreamState(session);
    });

    test('translateOpenAIToClaudeStream handles [DONE]', () {
      expect(translateOpenAIToClaudeStream('[DONE]'), equals('data: [DONE]\n\n'));
      expect(translateOpenAIToClaudeStream('data: [DONE]'), equals('data: [DONE]\n\n'));
    });
  });

  group('format_translator - Addendum 2 Edge Cases', () {
    test('convertClaudeMessage drops blocks if only non-producing blocks exist', () {
      const msg = ClaudeMessage(
        role: 'assistant',
        content: [
          {'type': 'thinking', 'thinking': 'Just pondering internal thoughts...'}
        ],
      );
      final converted = convertClaudeMessage(msg);
      expect(converted, isEmpty);
    });

    test('translateOpenAIToClaude skips empty tool names and sanitizes args', () {
      final openaiResp = {
        'id': 'chatcmpl-chat', // edge case chatcmpl-chat
        'model': '', // empty model fallback
        'choices': [
          {
            'index': 0,
            'message': {
              'role': 'assistant',
              'tool_calls': [
                {
                  'id': 'call_valid',
                  'type': 'function',
                  'function': {
                    'name': 'web_search',
                    'arguments': '{"q":"Flutter"}',
                  }
                },
                {
                  'id': 'call_invalid',
                  'type': 'function',
                  'function': {
                    'name': '', // empty name must be skipped
                    'arguments': '{}',
                  }
                }
              ]
            },
            'finish_reason': 'tool_calls',
          }
        ]
      };

      final claude = translateOpenAIToClaude(openaiResp);
      expect(claude['model'], equals('claude-3-5-sonnet'));
      expect(claude['id'], startsWith('msg_'));
      final blocks = claude['content'] as List;
      expect(blocks.length, equals(1));
      expect(blocks[0]['name'], equals('web_search'));
      expect(blocks[0]['input'], equals({'q': 'Flutter', 'query': 'Flutter'}));
      expect(claude['stop_reason'], equals('tool_use'));
    });

    test('cleanGeminiSchema safely encodes non-string enum items without stripping interior quotes', () {
      final schema = <dynamic, dynamic>{
        'type': 'object',
        'properties': <dynamic, dynamic>{
          'status': <dynamic, dynamic>{
            'enum': [1, 2, 'active "special" mode']
          }
        }
      };

      cleanGeminiSchema(schema);
      final props = schema['properties'] as Map;
      final enumList = props['status']['enum'] as List;
      expect(enumList[0], equals('1'));
      expect(enumList[1], equals('2'));
      // Interior quotes must be preserved
      expect(enumList[2], equals('active "special" mode'));
    });
  });
}

