import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';
import 'ollama_cloud_service.dart' show ChatResponse, ToolCall, OllamaApiException;

/// Service for communicating with the Anthropic Messages API.
///
/// Anthropic uses a distinct API format:
/// - Endpoint: POST /v1/messages
/// - Headers: x-api-key, anthropic-version
/// - Body: {model, max_tokens, system, messages, tools, temperature}
/// - Response: {content: [{type: "text", text: "..."}, {type: "tool_use", ...}]}
///
/// Tool calls are returned as content blocks, not as a separate
/// `tool_calls` field like OpenAI.
class AnthropicService extends ChangeNotifier {
  String baseUrl;
  String apiKey;
  String defaultModel;
  String fallbackModel;

  final http.Client _client;
  final HttpClient _streamClient;

  AnthropicService({
    required this.baseUrl,
    required this.apiKey,
    required this.defaultModel,
    required this.fallbackModel,
  })  : _client = _createClient(),
        _streamClient = _createStreamClient();

  static http.Client _createClient() {
    final ioClient = HttpClient();
    ioClient.connectionTimeout = const Duration(seconds: 30);
    ioClient.idleTimeout = const Duration(seconds: 120);
    return IOClient(ioClient);
  }

  static HttpClient _createStreamClient() {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);
    client.idleTimeout = const Duration(seconds: 120);
    return client;
  }

  static const _timeout = Duration(seconds: 120);
  static const _maxRetries = 3;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      };

  /// Normalize base URL: remove trailing slashes and /v1 suffix.
  String get _normalizedBase {
    var b = baseUrl.replaceAll(RegExp(r'/+$'), '');
    if (b.endsWith('/v1')) {
      b = b.substring(0, b.length - 3);
    }
    return b;
  }

  String get _messagesPath => '$_normalizedBase/v1/messages';

  void updateConfig({
    String? baseUrl,
    String? apiKey,
    String? defaultModel,
    String? fallbackModel,
  }) {
    if (baseUrl != null) this.baseUrl = baseUrl;
    if (apiKey != null) this.apiKey = apiKey;
    if (defaultModel != null) this.defaultModel = defaultModel;
    if (fallbackModel != null) this.fallbackModel = fallbackModel;
    notifyListeners();
  }

  /// Chat with tool support — returns ChatResponse (reusing the same
  /// data class as OllamaCloudService for compatibility).
  Future<ChatResponse> chatWithTools({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
    String? model,
    double temperature = 0.7,
  }) async {
    final allMessages = _convertMessages(messages);
    final useModel = model ?? defaultModel;

    String? lastError;
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        return await _doRequest(
          systemPrompt, allMessages, useModel, temperature, tools);
      } on TimeoutException catch (e) {
        lastError = 'Timeout: $e';
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        continue;
      } catch (e) {
        final status = _extractStatus(e);
        if (status == 429 || (status != null && status >= 500)) {
          lastError = 'Retryable ($status): $e';
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
          continue;
        }
        rethrow;
      }
    }

    // Fallback model
    try {
      return await _doRequest(
        systemPrompt, allMessages, fallbackModel, temperature, tools);
    } catch (e) {
      throw Exception('Primary model failed: $lastError; Fallback failed: $e');
    }
  }

  /// Simple chat without tools.
  Future<String> chat({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    String? model,
    double temperature = 0.7,
  }) async {
    final response = await chatWithTools(
      systemPrompt: systemPrompt,
      messages: messages,
      tools: null,
      model: model,
      temperature: temperature,
    );
    return response.content;
  }

  /// Streaming chat — yields text chunks.
  /// Tool support via streaming is complex; for streaming we skip tools
  /// and let the caller fall back to non-streaming if tools are needed.
  Stream<String> chatStream({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    String? model,
    double temperature = 0.7,
  }) async* {
    final allMessages = _convertMessages(messages);
    final useModel = model ?? defaultModel;
    final url = Uri.parse(_messagesPath);

    final body = <String, dynamic>{
      'model': useModel,
      'max_tokens': 4096,
      'system': systemPrompt,
      'messages': allMessages,
      'temperature': temperature,
      'stream': true,
    };

    try {
      final request = await _streamClient.postUrl(url);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('x-api-key', apiKey);
      request.headers.set('anthropic-version', '2023-06-01');
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close().timeout(_timeout);

      if (response.statusCode != 200) {
        final errorBody = await response.transform(utf8.decoder).join();
        throw OllamaApiException(
          response.statusCode,
          'Anthropic streaming error (${response.statusCode}): $errorBody',
        );
      }

      final lines = response.transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in lines) {
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data.isEmpty) continue;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final type = json['type'] as String?;
          if (type == 'content_block_delta') {
            final delta = json['delta'] as Map<String, dynamic>?;
            if (delta != null && delta['type'] == 'text_delta') {
              final text = delta['text'] as String?;
              if (text != null) yield text;
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      if (e is OllamaApiException) rethrow;
      throw Exception('Anthropic streaming failed: $e');
    }
  }

  Future<ChatResponse> _doRequest(
    String systemPrompt,
    List<Map<String, dynamic>> messages,
    String model,
    double temperature,
    List<Map<String, dynamic>>? tools,
  ) async {
    final url = Uri.parse(_messagesPath);

    final body = <String, dynamic>{
      'model': model,
      'max_tokens': 4096,
      'system': systemPrompt,
      'messages': messages,
      'temperature': temperature,
    };
    if (tools != null && tools.isNotEmpty) {
      // Convert OpenAI tool format → Anthropic tool format
      body['tools'] = tools.map(_convertToolToAnthropic).toList();
    }

    final response = await _client
        .post(url, headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseResponse(data);
    } else {
      throw OllamaApiException(
        response.statusCode,
        'Anthropic API error (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Convert OpenAI-style messages to Anthropic format.
  /// - System message is extracted separately (passed via `system` param).
  /// - Tool role messages → user role with tool_result content blocks.
  /// - Assistant messages with tool_calls → assistant with tool_use blocks.
  List<Map<String, dynamic>> _convertMessages(
      List<Map<String, dynamic>> messages) {
    final result = <Map<String, dynamic>>[];

    for (final msg in messages) {
      final role = msg['role'] as String;
      final content = msg['content'];

      if (role == 'system') continue; // System is passed separately

      if (role == 'tool') {
        // OpenAI tool result → Anthropic user message with tool_result block
        final toolCallId = msg['tool_call_id'] as String? ?? '';
        result.add({
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': toolCallId,
              'content': content is String ? content : jsonEncode(content),
            }
          ],
        });
        continue;
      }

      if (role == 'assistant') {
        // Check for tool_calls (OpenAI format)
        final toolCalls = msg['tool_calls'];
        if (toolCalls is List && toolCalls.isNotEmpty) {
          final blocks = <Map<String, dynamic>>[];
          final textContent = content is String ? content : '';
          if (textContent.isNotEmpty) {
            blocks.add({'type': 'text', 'text': textContent});
          }
          for (final tc in toolCalls) {
            if (tc is Map<String, dynamic>) {
              final func = tc['function'] as Map<String, dynamic>?;
              if (func != null) {
                final name = func['name'] as String? ?? '';
                final argsRaw = func['arguments'];
                Map<String, dynamic> args;
                if (argsRaw is String) {
                  try {
                    args = (jsonDecode(argsRaw) as Map).cast<String, dynamic>();
                  } catch (_) {
                    args = {};
                  }
                } else if (argsRaw is Map) {
                  args = argsRaw.cast<String, dynamic>();
                } else {
                  args = {};
                }
                blocks.add({
                  'type': 'tool_use',
                  'id': tc['id'] as String? ?? 'tool_${name}_${DateTime.now().millisecondsSinceEpoch}',
                  'name': name,
                  'input': args,
                });
              }
            }
          }
          result.add({'role': 'assistant', 'content': blocks});
          continue;
        }
      }

      // Standard text message — Anthropic accepts string content
      if (content is List) {
        // Vision multi-content: OpenAI-Format in Anthropic-Format übersetzen.
        // Anthropic erwartet {type:image, source:{type:base64, media_type, data}}
        // statt {type:image_url, image_url:{url:"data:..."}} → sonst 400.
        result.add({'role': role, 'content': _convertContentBlocks(content)});
      } else {
        result.add({'role': role, 'content': content is String ? content : ''});
      }
    }

    return result;
  }

  /// Übersetzt OpenAI-Content-Blöcke (text / image_url-Data-URL) in das
  /// Anthropic-Format (text / image mit base64-source).
  List<Map<String, dynamic>> _convertContentBlocks(List content) {
    final out = <Map<String, dynamic>>[];
    for (final raw in content) {
      if (raw is! Map) continue;
      final type = raw['type'];
      if (type == 'image_url') {
        final url = (raw['image_url'] is Map)
            ? raw['image_url']['url'] as String?
            : raw['image_url'] as String?;
        if (url != null && url.startsWith('data:')) {
          // data:<media_type>;base64,<data>
          final comma = url.indexOf(',');
          final header = url.substring(5, comma); // media_type;base64
          final mediaType = header.split(';').first;
          final data = url.substring(comma + 1);
          out.add({
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': mediaType.isNotEmpty ? mediaType : 'image/jpeg',
              'data': data,
            },
          });
        }
      } else if (type == 'text') {
        out.add({'type': 'text', 'text': raw['text'] as String? ?? ''});
      } else {
        out.add(raw.cast<String, dynamic>());
      }
    }
    return out;
  }

  /// Convert OpenAI tool definition to Anthropic format.
  Map<String, dynamic> _convertToolToAnthropic(Map<String, dynamic> tool) {
    final function = tool['function'] as Map<String, dynamic>?;
    if (function == null) return tool;
    return {
      'name': function['name'] ?? '',
      'description': function['description'] ?? '',
      'input_schema': function['parameters'] ?? {'type': 'object', 'properties': {}},
    };
  }

  /// Parse Anthropic response into ChatResponse.
  ChatResponse _parseResponse(Map<String, dynamic> data) {
    final contentBlocks = data['content'] as List? ?? [];
    final textParts = <String>[];
    final toolCalls = <ToolCall>[];

    for (final block in contentBlocks) {
      if (block is! Map<String, dynamic>) continue;
      final type = block['type'] as String?;
      if (type == 'text') {
        textParts.add(block['text'] as String? ?? '');
      } else if (type == 'tool_use') {
        toolCalls.add(ToolCall(
          id: block['id'] as String? ?? 'tool_${DateTime.now().millisecondsSinceEpoch}',
          type: 'function',
          name: block['name'] as String? ?? '',
          arguments: (block['input'] as Map?)?.cast<String, dynamic>() ?? {},
        ));
      }
    }

    final stopReason = data['stop_reason'] as String? ?? '';
    return ChatResponse(
      content: textParts.join(),
      toolCalls: toolCalls,
      finishReason: stopReason,
    );
  }

  int? _extractStatus(dynamic e) {
    final msg = e.toString();
    final match = RegExp(r'\b([1-5]\d{2})\b').firstMatch(msg);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  @override
  void dispose() {
    _client.close();
    _streamClient.close(force: true);
    super.dispose();
  }
}