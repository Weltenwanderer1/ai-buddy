import 'package:flutter_test/flutter_test.dart';
import 'package:ai_buddy/services/ollama_cloud_service.dart';

void main() {
  group('OllamaCloudService config', () {
    test('updateConfig updates all fields', () {
      final service = OllamaCloudService(
        baseUrl: 'https://old.example.com/api',
        apiKey: 'old-key',
        defaultModel: 'old-model',
        fallbackModel: 'old-fallback',
      );

      service.updateConfig(
        baseUrl: 'https://new.example.com/api',
        apiKey: 'new-key',
        defaultModel: 'new-model',
        fallbackModel: 'new-fallback',
      );

      expect(service.baseUrl, 'https://new.example.com/api');
      expect(service.apiKey, 'new-key');
      expect(service.defaultModel, 'new-model');
      expect(service.fallbackModel, 'new-fallback');
    });

    test('updateConfig partial update only changes provided fields', () {
      final service = OllamaCloudService(
        baseUrl: 'https://example.com/api',
        apiKey: 'original-key',
        defaultModel: 'original-model',
        fallbackModel: 'original-fallback',
      );

      service.updateConfig(apiKey: 'new-key');

      expect(service.baseUrl, 'https://example.com/api');
      expect(service.apiKey, 'new-key');
      expect(service.defaultModel, 'original-model');
      expect(service.fallbackModel, 'original-fallback');
    });
  });

  group('OllamaCloudService endpoint detection', () {
    test('detects Ollama native API when base URL ends with /api', () {
      final service = OllamaCloudService(
        baseUrl: 'https://ollama.com/api',
        apiKey: 'key',
        defaultModel: 'model',
        fallbackModel: 'fallback',
      );
      expect(service.isOllamaNative, isTrue);
    });

    test('detects Ollama native API with trailing slashes', () {
      final service = OllamaCloudService(
        baseUrl: 'https://ollama.com/api///',
        apiKey: 'key',
        defaultModel: 'model',
        fallbackModel: 'fallback',
      );
      expect(service.isOllamaNative, isTrue);
    });

    test('detects OpenAI-compatible when base URL does not end with /api', () {
      final service = OllamaCloudService(
        baseUrl: 'https://api.openai.com',
        apiKey: 'key',
        defaultModel: 'model',
        fallbackModel: 'fallback',
      );
      expect(service.isOllamaNative, isFalse);
    });

    test('detects OpenAI-compatible with /v1 path', () {
      final service = OllamaCloudService(
        baseUrl: 'https://api.ohmyllama.com',
        apiKey: 'key',
        defaultModel: 'model',
        fallbackModel: 'fallback',
      );
      expect(service.isOllamaNative, isFalse);
    });
  });

  group('OllamaCloudService normalized base URL', () {
    test('removes trailing slashes', () {
      final service = OllamaCloudService(
        baseUrl: 'https://example.com/api///',
        apiKey: 'key',
        defaultModel: 'model',
        fallbackModel: 'fallback',
      );
      expect(service.normalizedBase, 'https://example.com/api');
    });

    test('no trailing slashes is unchanged', () {
      final service = OllamaCloudService(
        baseUrl: 'https://example.com',
        apiKey: 'key',
        defaultModel: 'model',
        fallbackModel: 'fallback',
      );
      expect(service.normalizedBase, 'https://example.com');
    });
  });

  group('OllamaApiException', () {
    test('carries status code', () {
      final ex = OllamaApiException(429, 'Rate limited');
      expect(ex.statusCode, 429);
      expect(ex.toString(), 'Rate limited');
    });

    test('carries server error status', () {
      final ex = OllamaApiException(500, 'Internal server error');
      expect(ex.statusCode, 500);
    });
  });

  group('LLMTimeoutException', () {
    test('carries message', () {
      final ex = LLMTimeoutException('Connection timed out after 120s');
      expect(ex.toString(), 'Connection timed out after 120s');
    });
  });

  group('accumulateToolCallDelta', () {
    test('assembles id, name and fragmented arguments by index', () {
      final drafts = <int, ToolCallDraft>{};
      OllamaCloudService.accumulateToolCallDelta(drafts, {
        'index': 0,
        'id': 'call_1',
        'function': {'name': 'get_weather', 'arguments': '{"ci'},
      });
      OllamaCloudService.accumulateToolCallDelta(drafts, {
        'index': 0,
        'function': {'arguments': 'ty": "Wien"}'},
      });

      expect(drafts, hasLength(1));
      expect(drafts[0]!.id, 'call_1');
      expect(drafts[0]!.name, 'get_weather');
      expect(drafts[0]!.arguments.toString(), '{"city": "Wien"}');
    });

    test('keeps parallel tool calls separate by index', () {
      final drafts = <int, ToolCallDraft>{};
      OllamaCloudService.accumulateToolCallDelta(drafts, {
        'index': 0,
        'id': 'a',
        'function': {'name': 'tool_a', 'arguments': '{}'},
      });
      OllamaCloudService.accumulateToolCallDelta(drafts, {
        'index': 1,
        'id': 'b',
        'function': {'name': 'tool_b', 'arguments': '{"x":1}'},
      });

      expect(drafts, hasLength(2));
      expect(drafts[0]!.name, 'tool_a');
      expect(drafts[1]!.name, 'tool_b');
      expect(drafts[1]!.arguments.toString(), '{"x":1}');
    });

    test('missing index defaults to 0', () {
      final drafts = <int, ToolCallDraft>{};
      OllamaCloudService.accumulateToolCallDelta(drafts, {
        'function': {'name': 'tool', 'arguments': '{}'},
      });
      expect(drafts.keys, [0]);
    });
  });

  group('extractStatus', () {
    test('extracts HTTP status from exception message', () {
      final service = OllamaCloudService(
        baseUrl: 'https://example.com',
        apiKey: 'key',
        defaultModel: 'model',
        fallbackModel: 'fallback',
      );

      expect(service.extractStatus('Error 429 rate limited'), 429);
      expect(service.extractStatus('Server returned 500'), 500);
      expect(service.extractStatus('401 Unauthorized'), 401);
      expect(service.extractStatus('No status here'), isNull);
      expect(service.extractStatus('200 OK'), 200);
    });
  });
}
