import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';
import 'tool_call_parser.dart';

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
    final trimmed = baseUrl.replaceAll(RegExp(r'/+$'), '').toLowerCase();
    // OpenRouter/OpenAI/Anthropic enden zwar teils auf /api, sind aber
    // OpenAI-kompatibel — sie dürfen NICHT über den Ollama-Native-Endpunkt
    // (/api/chat) laufen, sonst 404/Format-Fehler.
    if (trimmed.contains('openrouter') ||
        trimmed.contains('openai') ||
        trimmed.contains('anthropic')) {
      return false;
    }
    return trimmed.endsWith('/api');
  }

  /// Normalize base URL: remove trailing slashes.
  /// Also tracks whether the base already includes /v1 for correct path building.
  String get _normalizedBase => baseUrl.replaceAll(RegExp(r'/+$'), '');

  /// The native Ollama chat endpoint URL (for simple non-tool requests).
  /// e.g. https://ollama.com/api → https://ollama.com/api/chat
  String get _nativeChatPath {
    return '$_normalizedBase/chat';
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
    // OpenRouter: URL already ends with /api — keep it
    final isOpenRouter = base.contains('openrouter');
    if (isOpenRouter) {
      return '$base/v1/chat/completions';
    }
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
    required List<Map<String, dynamic>> messages,
    String? model,
    double temperature = 0.7,
  }) {
    return _doStreamRequest(
        systemPrompt, messages, model ?? defaultModel, temperature);
  }

  /// Streaming chat WITH tool support.
  ///
  /// Streams content tokens to the caller while accumulating structured
  /// `delta.tool_calls` fragments (OpenAI streaming format). When the model
  /// requests tools, they are executed via [onToolCall], the results are
  /// appended to the conversation, and the next round is streamed — up to
  /// [maxToolRounds] rounds. Always uses the OpenAI-compatible endpoint
  /// (tools are not supported on the Ollama-native path).
  Stream<String> chatStreamWithTools({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
    Future<String> Function(String toolName, Map<String, dynamic> args)?
        onToolCall,
    void Function(String toolName)? onToolActivity,
    int maxToolRounds = 5,
    String? model,
    double temperature = 0.7,
  }) async* {
    final current = <Map<String, dynamic>>[
      {'role': 'system', 'content': _sanitize(systemPrompt)},
      ...messages,
    ];
    final url = Uri.parse(_chatCompletionsPath);
    final hasTools =
        tools != null && tools.isNotEmpty && onToolCall != null;

    for (var round = 0; round <= maxToolRounds; round++) {
      final body = <String, dynamic>{
        'model': _sanitize(model ?? defaultModel),
        'messages': current,
        'temperature': temperature,
        'stream': true,
      };
      // Letzte Runde ohne Tools erzwingen, damit das Modell eine
      // Textantwort liefert statt endlos Tools anzufordern.
      if (hasTools && round < maxToolRounds) {
        body['tools'] = tools;
      }

      final collected = <int, ToolCallDraft>{};
      await for (final chunk
          in _streamResponseWithToolCapture(url, _baseHeaders, body, collected)) {
        yield chunk;
      }

      final toolCalls = _draftsToToolCalls(collected);
      if (!hasTools || toolCalls.isEmpty) return;

      // Assistant-Nachricht mit allen Tool-Calls in die History
      current.add({
        'role': 'assistant',
        'content': '',
        'tool_calls': [
          for (final tc in toolCalls)
            {
              'id': tc.id,
              'type': tc.type,
              'function': {
                'name': tc.name,
                'arguments': jsonEncode(tc.arguments),
              },
            },
        ],
      });

      for (final tc in toolCalls) {
        debugPrint('chatStreamWithTools tool: ${tc.name}');
        onToolActivity?.call(tc.name);
        String result;
        try {
          result = await onToolCall(tc.name, tc.arguments);
        } catch (e) {
          result = 'Fehler: $e';
        }
        final trimmed =
            result.length > 2000 ? '${result.substring(0, 2000)}...' : result;
        current.add({
          'role': 'tool',
          'tool_call_id': tc.id,
          'content': trimmed,
        });
      }
    }
  }

  /// Convert accumulated streaming tool-call drafts into [ToolCall]s.
  List<ToolCall> _draftsToToolCalls(Map<int, ToolCallDraft> drafts) {
    final indices = drafts.keys.toList()..sort();
    final calls = <ToolCall>[];
    for (final i in indices) {
      final d = drafts[i]!;
      if (d.name.isEmpty) continue;
      Map<String, dynamic> args = {};
      final argsStr = d.arguments.toString().trim();
      if (argsStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(argsStr);
          if (decoded is Map) args = decoded.cast<String, dynamic>();
        } catch (_) {
          // Unvollständiges/ungültiges JSON — Tool mit leeren Args aufrufen
          // ist sinnlos, also überspringen.
          continue;
        }
      }
      calls.add(ToolCall(
        id: d.id.isNotEmpty ? d.id : 'stream_tool_$i',
        type: 'function',
        name: d.name,
        arguments: args,
      ));
    }
    return calls;
  }

  /// Accumulate one OpenAI streaming `delta.tool_calls` entry into [drafts].
  @visibleForTesting
  static void accumulateToolCallDelta(
      Map<int, ToolCallDraft> drafts, Map<String, dynamic> entry) {
    final index = (entry['index'] as num?)?.toInt() ?? 0;
    final draft = drafts.putIfAbsent(index, () => ToolCallDraft());
    final id = entry['id'] as String?;
    if (id != null && id.isNotEmpty) draft.id = id;
    final func = entry['function'];
    if (func is Map) {
      final name = func['name'] as String?;
      if (name != null && name.isNotEmpty) draft.name += name;
      final args = func['arguments'] as String?;
      if (args != null) draft.arguments.write(args);
    }
  }

  /// Internal: streaming request that handles both Ollama native and OpenAI-compatible endpoints.
  /// Sanitize a string for safe JSON/UTF-8 encoding.
  /// Removes C0 control chars AND unpaired surrogates that cause
  /// 'Contains invalid characters' errors in Dart's HTTP client.
  static String _sanitize(String s) {
    final buf = StringBuffer();
    for (final rune in s.runes) {
      // Skip C0 control chars (except TAB/LF/CR)
      if (rune >= 0x00 && rune <= 0x1F && rune != 0x09 && rune != 0x0A && rune != 0x0D) continue;
      // Skip unpaired surrogates (invalid in UTF-8)
      if (rune >= 0xD800 && rune <= 0xDFFF) continue;
      buf.writeCharCode(rune);
    }
    return buf.toString();
  }

  Stream<String> _doStreamRequest(
    String systemPrompt,
    List<Map<String, dynamic>> messages,
    String model,
    double temperature,
  ) {
    final allMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _sanitize(systemPrompt)},
      ...messages.map((m) {
        final rawContent = m['content'];
        if (rawContent is List) {
          // Vision multi-content: preserve array format
          return {
            'role': m['role']!,
            'content': rawContent,
          };
        }
        return {
          'role': m['role']!,
          'content': _sanitize(rawContent as String? ?? ''),
        };
      }),
    ];

    final isNative = _isOllamaNative;

    final url = isNative
        ? Uri.parse(_nativeChatPath)
        : Uri.parse(_chatCompletionsPath);

    final body = <String, dynamic>{
      'model': _sanitize(model),
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
      // Write as UTF-8 bytes to avoid Dart HTTP client string encoding issues
      final jsonStr = jsonEncode(body);
      final bytes = utf8.encode(jsonStr);
      request.add(bytes);
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
      // detachSocket() liefert ein Future — Fehler dort dürfen nicht als
      // unhandled async error hochblubbern.
      try {
        unawaited(response
            ?.detachSocket()
            .then((socket) => socket.destroy())
            .catchError((_) {}));
      } catch (_) {}
      client?.close();
    }
  }

  /// Like [_streamResponse], but additionally captures streaming
  /// `delta.tool_calls` fragments into [drafts] (OpenAI format only).
  Stream<String> _streamResponseWithToolCapture(
    Uri url,
    Map<String, String> headers,
    Map<String, dynamic> body,
    Map<int, ToolCallDraft> drafts,
  ) async* {
    HttpClient? client;
    HttpClientResponse? response;

    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);
      client.idleTimeout = const Duration(seconds: 120);
      final request = await client.postUrl(url);
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      request.add(utf8.encode(jsonEncode(body)));
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
          final chunk = _parseToolStreamChunk(currentData, drafts);
          if (chunk != null) yield chunk;
          currentData = null;
        } else if (line.isNotEmpty && !line.startsWith(':')) {
          final chunk = _parseToolStreamChunk(line.trim(), drafts);
          if (chunk != null) yield chunk;
        }
      }
      if (currentData != null) {
        final chunk = _parseToolStreamChunk(currentData, drafts);
        if (chunk != null) yield chunk;
      }
    } catch (e) {
      if (e is OllamaApiException) rethrow;
      throw Exception('Streaming failed: $e');
    } finally {
      try {
        unawaited(response
            ?.detachSocket()
            .then((socket) => socket.destroy())
            .catchError((_) {}));
      } catch (_) {}
      client?.close();
    }
  }

  /// Parse an OpenAI streaming chunk: returns content text (or null) and
  /// accumulates tool-call deltas into [drafts].
  String? _parseToolStreamChunk(String data, Map<int, ToolCallDraft> drafts) {
    if (data.isEmpty || data == '[DONE]') return null;
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final delta = choices[0]['delta'] as Map<String, dynamic>?;
      if (delta == null) return null;
      final toolDeltas = delta['tool_calls'];
      if (toolDeltas is List) {
        for (final entry in toolDeltas) {
          if (entry is Map) {
            accumulateToolCallDelta(drafts, entry.cast<String, dynamic>());
          }
        }
      }
      return delta['content'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Describe an image with a vision-capable model.
  ///
  /// Sends the image as base64 data URL in the OpenAI-compatible
  /// `image_url` content format (supported by OpenRouter and the
  /// Ollama `/v1` endpoint). Tries the default model first, then the
  /// fallback model.
  Future<String> describeImage({
    required String imageBase64,
    String mimeType = 'image/jpeg',
    String? question,
    String? model,
  }) async {
    final messages = [
      {
        'role': 'user',
        'content': [
          {
            'type': 'text',
            'text': question ?? 'Beschreibe dieses Bild detailliert auf Deutsch.',
          },
          {
            'type': 'image_url',
            'image_url': {'url': 'data:$mimeType;base64,$imageBase64'},
          },
        ],
      },
    ];

    Future<String> request(String useModel) async {
      final response = await _client
          .post(
            Uri.parse(_chatCompletionsPath),
            headers: _baseHeaders,
            body: jsonEncode({
              'model': useModel,
              'messages': messages,
              'temperature': 0.3,
            }),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw OllamaApiException(
          response.statusCode,
          'Vision API error (${response.statusCode}): ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}',
        );
      }
      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content'];
      if (content is! String || content.isEmpty) {
        throw const FormatException('Vision-Antwort ohne Inhalt');
      }
      return content;
    }

    if (model != null) return request(model);
    try {
      return await request(defaultModel);
    } catch (e) {
      debugPrint('Vision mit $defaultModel fehlgeschlagen: $e — versuche $fallbackModel');
      return request(fallbackModel);
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
    required List<Map<String, dynamic>> messages,
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
    List<Map<String, dynamic>> messages,
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
    List<Map<String, dynamic>> messages,
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

  /// OpenAI-compatible API: POST <base>/v1/chat/completions
  /// Body: {model, messages, temperature}
  /// Response: {choices: [{message: {content}}]}
  Future<String> _doOpenAICompatibleRequest(
    String base,
    List<Map<String, dynamic>> messages,
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
        return _maybeExtractInlineToolCalls(
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
      return _maybeExtractInlineToolCalls(
        content: content,
        toolCalls: toolCalls,
      );
    }

    // Fallback: try to get any content
    final content = data['content'] as String? ??
        data['message']?['content'] as String? ??
        '';
    return _maybeExtractInlineToolCalls(content: content, toolCalls: []);
  }

  /// If no structured tool_calls found, try extracting XML/JSON inline tool
  /// calls from the content text (common with cloud LLMs that embed tool calls
  /// as text instead of using the structured API format).
  ChatResponse _maybeExtractInlineToolCalls({
    required String content,
    required List<ToolCall> toolCalls,
    String finishReason = '',
  }) {
    // Only fall back to inline parsing if structured tool_calls is empty
    if (toolCalls.isNotEmpty) {
      return ChatResponse(
        content: content,
        toolCalls: toolCalls,
        finishReason: finishReason,
      );
    }

    // Try extracting inline tool calls from content
    final inlineCalls = ToolCallParser.parseInline(content, null);
    if (inlineCalls.isEmpty) {
      return ChatResponse(content: content, finishReason: finishReason);
    }

    // Convert to ToolCall objects and strip from content
    final parsed = inlineCalls.map((call) => ToolCall(
      id: 'inline_${call['name']}_${DateTime.now().millisecondsSinceEpoch}',
      type: 'function',
      name: call['name'] as String? ?? '',
      arguments: (call['arguments'] as Map<String, dynamic>?) ?? {},
    )).toList();

    final cleanedContent = ToolCallParser.stripFunctionCallTags(content).trim();

    return ChatResponse(
      content: cleanedContent,
      toolCalls: parsed,
      finishReason: finishReason,
    );
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

/// Mutable accumulator for one streamed tool call (OpenAI delta format:
/// id/name arrive once, arguments arrive as string fragments).
class ToolCallDraft {
  String id = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();
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
  Map<String, dynamic> toAssistantMessage() => assistantMessageFor([this]);

  /// Build ONE assistant message carrying ALL tool calls of a turn.
  ///
  /// Wichtig bei parallelen Tool-Calls: die Assistant-Nachricht muss jeden
  /// tool_call enthalten, sonst referenzieren die nachfolgenden tool-Results
  /// eine tool_call_id, die es in der Historie nicht gibt (Anthropic/OpenAI
  /// antworten dann mit 400).
  static Map<String, dynamic> assistantMessageFor(List<ToolCall> calls) => {
        'role': 'assistant',
        'content': '',
        'tool_calls': [
          for (final c in calls)
            {
              'id': c.id,
              'type': c.type,
              'function': {
                'name': c.name,
                'arguments': jsonEncode(c.arguments),
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
