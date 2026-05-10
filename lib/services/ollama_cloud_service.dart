import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';

/// Service for communicating with Ollama Cloud LLM API.
/// Reads config from constructor params (injected from SecureConfigService).
///
/// Supports two endpoint styles based on the base URL:
/// - Ollama native:  POST <base>/chat  with body {model, messages, stream}
///   → response {message: {role, content}}
/// - OpenAI-compatible: POST <base>/v1/chat/completions  with body {model, messages, temperature}
///   → response {choices: [{message: {content}}]}
///
/// Detection: if base URL ends with "/api" (e.g. https://ollama.com/api),
/// we use the Ollama native endpoint. Otherwise we use OpenAI-compatible.
class OllamaCloudService extends ChangeNotifier {
  String baseUrl;
  String apiKey;
  String defaultModel;
  String fallbackModel;

  final http.Client _client;
  bool _preconnected = false;

  OllamaCloudService({
    required this.baseUrl,
    required this.apiKey,
    required this.defaultModel,
    required this.fallbackModel,
  }) : _client = _createClient();

  /// Create an http.Client with connection and response timeouts.
  static http.Client _createClient() {
    final ioClient = HttpClient();
    ioClient.connectionTimeout = const Duration(seconds: 30);
    ioClient.idleTimeout = const Duration(seconds: 120);
    return IOClient(ioClient);
  }

  static const _timeout = Duration(seconds: 120);
  static const _maxRetries = 3;

  /// Preconnect to the API endpoint to warm up the TCP/TLS connection.
  /// Call this at app startup for faster first request.
  Future<void> preconnect() async {
    if (_preconnected) return;
    try {
      final uri = Uri.parse('$_normalizedBase/');
      await _client.head(uri, headers: _baseHeaders).timeout(
            const Duration(seconds: 5),
          );
    } catch (_) {
      // Non-critical — request will still work, just slower first time
    }
    _preconnected = true;
  }

  Map<String, String> get _baseHeaders => {
        'Content-Type': 'application/json',
        'Connection': 'keep-alive',
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      };

  /// Update config (e.g. after settings change).
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

  /// @visibleForTesting
  @visibleForTesting
  bool get isOllamaNative => _isOllamaNative;

  /// @visibleForTesting
  @visibleForTesting
  String get normalizedBase => _normalizedBase;

  /// @visibleForTesting
  @visibleForTesting
  int? extractStatus(dynamic e) => _extractStatus(e);

  /// Returns true if the base URL points to an Ollama native API
  /// (URL ends with /api or /api/).
  bool get _isOllamaNative {
    final trimmed = baseUrl.replaceAll(RegExp(r'/+$'), '');
    return trimmed.endsWith('/api');
  }

  /// Normalize base URL: remove trailing slashes.
  /// Also tracks whether the base already includes /v1 for correct path building.
  String get _normalizedBase => baseUrl.replaceAll(RegExp(r'/+$'), '');

  /// The native Ollama chat endpoint URL (for simple non-tool requests).
  /// e.g. https://ollama.com/api → https://ollama.com/api/chat
  String get _nativeChatPath {
    final base = _normalizedBase;
    if (base.endsWith('/v1')) {
      // Unusual but handle: https://host/v1 → https://host/v1/chat
      return '$base/chat';
    }
    return '$base/chat';
  }

  /// Build the correct OpenAI-compatible chat completions URL.
  /// Normalizes any URL variant to: <host>/v1/chat/completions
  /// Handles all URL variants:
  ///   https://ollama.com/api          → https://ollama.com/v1/chat/completions
  ///   https://ollama.com/api/v1       → https://ollama.com/v1/chat/completions
  ///   https://api.ollama.com/v1       → https://api.ollama.com/v1/chat/completions
  ///   https://ollama.com              → https://ollama.com/v1/chat/completions
  ///   https://ollama.com/v1           → https://ollama.com/v1/chat/completions
  String get _chatCompletionsPath {
    var base = _normalizedBase;
    // Strip common suffixes that users might paste from docs
    if (base.endsWith('/api/v1')) {
      base = base.substring(0, base.length - 6); // https://ollama.com/api/v1 → https://ollama.com
    } else if (base.endsWith('/api')) {
      base = base.substring(0, base.length - 4); // https://ollama.com/api → https://ollama.com
    }
    if (base.endsWith('/v1')) {
      return '$base/chat/completions'; // https://ollama.com/v1 → .../v1/chat/completions
    }
    return '$base/v1/chat/completions'; // https://ollama.com → .../v1/chat/completions
  }

  /// Public getter for debugging — shows the OpenAI-compatible endpoint URL.
  String get chatCompletionsUrl => _chatCompletionsPath;

  /// Streaming chat without tools — yields token chunks as they arrive.
  /// Falls back to non-streaming on error.
  Stream<String> chatStream({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    String? model,
    double temperature = 0.7,
  }) {
    return _doStreamRequest(
        systemPrompt, messages, model ?? defaultModel, temperature);
  }

  /// Internal: streaming request that handles both Ollama native and OpenAI-compatible endpoints.
  Stream<String> _doStreamRequest(
    String systemPrompt,
    List<Map<String, String>> messages,
    String model,
    double temperature,
  ) {
    final allMessages = [
      {'role': 'system', 'content': systemPrompt},
      ...messages,
    ];

    final base = _normalizedBase;
    final isNative = _isOllamaNative;

    final url = isNative
        ? Uri.parse(_nativeChatPath)
        : Uri.parse(_chatCompletionsPath);

    final body = <String, dynamic>{
      'model': model,
      'messages': allMessages,
      'stream': true,
    };
    if (!isNative) {
      body['temperature'] = temperature;
    }

    final headers = _baseHeaders;

    return _streamResponse(url, headers, body, isNative);
  }

  /// Core SSE stream parser — connects via HTTP, reads Server-Sent Events,
  /// and yields token chunks.
  Stream<String> _streamResponse(
    Uri url,
    Map<String, String> headers,
    Map<String, dynamic> body,
    bool isOllamaNative,
  ) async* {
    HttpClient? client;
    HttpClientRequest? request;
    HttpClientResponse? response;

    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);
      client.idleTimeout = const Duration(seconds: 120);
      request = await client.postUrl(url);
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      request.write(jsonEncode(body));
      response = await request.close().timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        final errorBody = await response.transform(utf8.decoder).join();
        throw OllamaApiException(
          response.statusCode,
          'Streaming API error (${response.statusCode}): $errorBody',
        );
      }

      final lines =
          response.transform(utf8.decoder).transform(const LineSplitter());
      String? currentData;

      await for (final line in lines) {
        if (line.startsWith('data: ')) {
          currentData = line.substring(6).trim();
        } else if (line.isEmpty && currentData != null) {
          // End of SSE event — process the accumulated data
          final chunk = _parseStreamChunk(currentData, isOllamaNative);
          if (chunk != null) yield chunk;
          currentData = null;
        } else if (line.isNotEmpty && !line.startsWith(':')) {
          // Some APIs send JSON lines directly (no SSE framing)
          final chunk = _parseStreamChunk(line.trim(), isOllamaNative);
          if (chunk != null) yield chunk;
        }
      }

      // Process any remaining data
      if (currentData != null) {
        final chunk = _parseStreamChunk(currentData, isOllamaNative);
        if (chunk != null) yield chunk;
      }
    } catch (e) {
      if (e is OllamaApiException) rethrow;
      throw Exception('Streaming failed: $e');
    } finally {
      try {
        response?.detachSocket().then((socket) => socket.destroy());
      } catch (_) {}
      client?.close();
    }
  }

  /// Parse a single SSE data chunk into the token text.
  /// Returns null for [DONE] markers or non-content chunks.
  String? _parseStreamChunk(String data, bool isOllamaNative) {
    if (data.isEmpty || data == '[DONE]') return null;

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;

      if (isOllamaNative) {
        // Ollama native: {message: {role, content}, done: bool}
        final content = json['message']?['content'] as String?;
        if (content != null) return content;
        return null;
      } else {
        // OpenAI-compatible: {choices: [{delta: {content: "..."}}]}
        final choices = json['choices'] as List?;
        if (choices == null || choices.isEmpty) return null;
        final delta = choices[0]['delta'] as Map<String, dynamic>?;
        if (delta == null) return null;
        final content = delta['content'] as String?;
        if (content != null) return content;
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// Basic chat without tools — backward compatible.
  Future<String> chat({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    String? model,
    double temperature = 0.7,
  }) async {
    final allMessages = [
      {'role': 'system', 'content': systemPrompt},
      ...messages,
    ];

    String? lastError;

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        return await _doRequest(
            allMessages, model ?? defaultModel, temperature);
      } on TimeoutException catch (e) {
        lastError = 'Timeout: $e';
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        continue;
      } on LLMTimeoutException catch (e) {
        lastError = 'Timeout: $e';
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        continue;
      } on http.ClientException catch (e) {
        lastError = 'Network error: $e';
        // DNS failures and connection issues are retryable
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        continue;
      } on SocketException catch (e) {
        lastError = 'Network error: $e';
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

    // Fallback to secondary model
    if (model == null) {
      try {
        return await _doRequest(allMessages, fallbackModel, temperature);
      } catch (e) {
        throw Exception(
          'Primary model failed: $lastError; Fallback failed: $e',
        );
      }
    }
    throw Exception('All retries exhausted: $lastError');
  }

  /// Chat with tool support — returns the full response including potential tool calls.
  /// The caller (ChatService) handles the tool-call loop.
  Future<ChatResponse> chatWithTools({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
    String? model,
    double temperature = 0.7,
  }) async {
    final allMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ...messages,
    ];

    String? lastError;

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        return await _doRequestWithTools(
            allMessages, model ?? defaultModel, temperature, tools);
      } on TimeoutException catch (e) {
        lastError = 'Timeout: $e';
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        continue;
      } on LLMTimeoutException catch (e) {
        lastError = 'Timeout: $e';
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        continue;
      } on http.ClientException catch (e) {
        lastError = 'Network error: $e';
        // DNS failures and connection issues are retryable
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        continue;
      } on SocketException catch (e) {
        lastError = 'Network error: $e';
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

    // Fallback to secondary model
    if (model == null) {
      try {
        return await _doRequestWithTools(
            allMessages, fallbackModel, temperature, tools);
      } catch (e) {
        throw Exception(
          'Primary model failed: $lastError; Fallback failed: $e',
        );
      }
    }
    throw Exception('All retries exhausted: $lastError');
  }

  Future<String> _doRequest(
    List<Map<String, String>> messages,
    String model,
    double temperature,
  ) async {
    final base = _normalizedBase;

    if (_isOllamaNative) {
      // Ollama native endpoint: POST <base>/chat
      return _doOllamaNativeRequest(base, messages, model);
    } else {
      // OpenAI-compatible endpoint: POST <base>/v1/chat/completions
      return _doOpenAICompatibleRequest(base, messages, model, temperature);
    }
  }

  Future<ChatResponse> _doRequestWithTools(
    List<Map<String, dynamic>> messages,
    String model,
    double temperature,
    List<Map<String, dynamic>>? tools,
  ) async {
    final base = _normalizedBase;
    // ALWAYS use OpenAI-compatible endpoint for tools — Ollama Cloud
    // is OpenAI-compatible even when base URL contains /api
    return _doOpenAICompatibleRequestWithTools(
        base, messages, model, temperature, tools);
  }

  /// Ollama native API: POST <base>/chat
  /// Body: {model, messages, stream: false}
  /// Response: {message: {role, content}}
  Future<String> _doOllamaNativeRequest(
    String base,
    List<Map<String, String>> messages,
    String model,
  ) async {
    final url = Uri.parse(_nativeChatPath);

    final response = await _client
        .post(
          url,
          headers: _baseHeaders,
          body: jsonEncode({
            'model': model,
            'messages': messages,
            'stream': false,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Ollama native response: {message: {role, content}}
      final content = data['message']?['content'];
      if (content != null) {
        return content as String;
      }

      // Fallback: maybe it's OpenAI-format (some proxies)
      final choices = data['choices'];
      if (choices != null && choices is List && choices.isNotEmpty) {
        final msgContent = choices[0]['message']?['content'];
        if (msgContent != null) return msgContent as String;
      }

      throw FormatException(
        'Unexpected Ollama API response format. '
        'Expected {message:{content}} or {choices:[{message:{content}}]}. '
        'Got: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
      );
    } else {
      throw OllamaApiException(
        response.statusCode,
        'Ollama native API error (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Ollama native with tools support.
  // ignore: unused_element
  Future<ChatResponse> _doOllamaNativeRequestWithTools(
    String base,
    List<Map<String, dynamic>> messages,
    String model,
    List<Map<String, dynamic>>? tools,
  ) async {
    final url = Uri.parse(_nativeChatPath);

    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': false,
    };
    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools;
    }

    final response = await _client
        .post(
          url,
          headers: _baseHeaders,
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseResponse(data);
    } else {
      throw OllamaApiException(
        response.statusCode,
        'Ollama native API error (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// OpenAI-compatible API: POST <base>/v1/chat/completions
  /// Body: {model, messages, temperature}
  /// Response: {choices: [{message: {content}}]}
  Future<String> _doOpenAICompatibleRequest(
    String base,
    List<Map<String, String>> messages,
    String model,
    double temperature,
  ) async {
    final url = Uri.parse(_chatCompletionsPath);

    final response = await _client
        .post(
          url,
          headers: _baseHeaders,
          body: jsonEncode({
            'model': model,
            'messages': messages,
            'temperature': temperature,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content'];
      if (content == null) {
        throw FormatException(
          'Unexpected API response: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
        );
      }
      return content as String;
    } else {
      throw OllamaApiException(
        response.statusCode,
        'API error (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// OpenAI-compatible with tools support.
  /// Always use this for tools — Ollama Cloud only supports tools via /v1/chat/completions
  Future<ChatResponse> _doOpenAICompatibleRequestWithTools(
    String base,
    List<Map<String, dynamic>> messages,
    String model,
    double temperature,
    List<Map<String, dynamic>>? tools,
  ) async {
    final url = Uri.parse(_chatCompletionsPath);

    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': temperature,
    };
    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools;
    }

    final response = await _client
        .post(
          url,
          headers: _baseHeaders,
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return _parseResponse(data as Map<String, dynamic>);
    } else {
      throw OllamaApiException(
        response.statusCode,
        'API error (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Parse LLM response into ChatResponse, extracting tool calls if present.
  ChatResponse _parseResponse(Map<String, dynamic> data) {
    // OpenAI format: choices[0].message
    final choices = data['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      final message = choices[0]['message'] as Map<String, dynamic>?;
      if (message != null) {
        final content = message['content'] as String? ?? '';
        final toolCalls = _parseToolCalls(message['tool_calls']);
        final finishReason = choices[0]['finish_reason'] as String? ?? '';
        return ChatResponse(
          content: content,
          toolCalls: toolCalls,
          finishReason: finishReason,
        );
      }
    }

    // Ollama native format: message
    final msg = data['message'] as Map<String, dynamic>?;
    if (msg != null) {
      final content = msg['content'] as String? ?? '';
      final toolCalls = _parseToolCalls(msg['tool_calls']);
      return ChatResponse(
        content: content,
        toolCalls: toolCalls,
      );
    }

    // Fallback: try to get any content
    final content = data['content'] as String? ??
        data['message']?['content'] as String? ??
        '';
    return ChatResponse(content: content);
  }

  /// Parse tool_calls from the LLM response.
  List<ToolCall> _parseToolCalls(dynamic raw) {
    if (raw == null) return [];
    if (raw is! List) return [];

    var index = 0;
    return raw
        .map((tc) {
          if (tc is! Map<String, dynamic>) return null;
          final id = tc['id'] as String? ?? 'tool_call_${index++}';
          final type = tc['type'] as String? ?? 'function';
          final func = tc['function'] as Map<String, dynamic>? ?? {};
          final name = func['name'] as String? ?? '';

          Map<String, dynamic> arguments;
          final rawArgs = func['arguments'];
          if (rawArgs is Map<String, dynamic>) {
            arguments = rawArgs;
          } else if (rawArgs is String) {
            try {
              final decoded = jsonDecode(rawArgs);
              if (decoded is Map<String, dynamic>) {
                arguments = decoded;
              } else if (decoded is Map) {
                arguments = decoded.cast<String, dynamic>();
              } else {
                arguments = {};
              }
            } catch (_) {
              arguments = {};
            }
          } else {
            arguments = {};
          }

          if (name.isEmpty) return null;
          return ToolCall(
            id: id,
            type: type,
            name: name,
            arguments: arguments,
          );
        })
        .whereType<ToolCall>()
        .toList();
  }

  int? _extractStatus(dynamic e) {
    final msg = e.toString();
    final match = RegExp(r'\b([1-5]\d{2})\b').firstMatch(msg);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

/// Parsed LLM response with optional tool calls.
class ChatResponse {
  final String content;
  final List<ToolCall> toolCalls;
  final String finishReason;

  ChatResponse({
    this.content = '',
    this.toolCalls = const [],
    this.finishReason = '',
  });

  bool get hasToolCalls => toolCalls.isNotEmpty;
}

/// A single tool call from the LLM.
class ToolCall {
  final String id;
  final String type;
  final String name;
  final Map<String, dynamic> arguments;

  ToolCall({
    required this.id,
    required this.type,
    required this.name,
    required this.arguments,
  });

  /// Convert to the assistant message format for the conversation history.
  Map<String, dynamic> toAssistantMessage() => {
        'role': 'assistant',
        'content': '',
        'tool_calls': [
          {
            'id': id,
            'type': type,
            'function': {
              'name': name,
              'arguments': jsonEncode(arguments),
            },
          },
        ],
      };
}

class LLMTimeoutException implements Exception {
  final String message;
  LLMTimeoutException(this.message);
  @override
  String toString() => message;
}

/// Rich exception carrying the HTTP status code.
class OllamaApiException implements Exception {
  final int statusCode;
  final String message;
  OllamaApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}
