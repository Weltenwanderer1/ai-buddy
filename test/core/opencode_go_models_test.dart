import 'package:flutter_test/flutter_test.dart';
import 'package:ai_buddy/core/opencode_go_models.dart';

void main() {
  group('OpenCode Go model catalog', () {
    test('contains every supported preset in the requested order', () {
      expect(
        openCodeGoModels.map((model) => model.name),
        [
          'Grok 4.5',
          'GLM-5.2',
          'GLM-5.1',
          'Kimi K3',
          'Kimi K2.7 Code',
          'Kimi K2.6',
          'MiMo-V2.5',
          'MiMo-V2.5-Pro',
          'MiniMax M3',
          'MiniMax M2.7',
          'Qwen3.7 Max',
          'Qwen3.7 Plus',
          'Qwen3.6 Plus',
          'DeepSeek V4 Pro',
          'DeepSeek V4 Flash',
        ],
      );
    });

    test('uses the official model IDs', () {
      expect(
        openCodeGoModels.map((model) => model.id),
        [
          'grok-4.5',
          'glm-5.2',
          'glm-5.1',
          'kimi-k3',
          'kimi-k2.7-code',
          'kimi-k2.6',
          'mimo-v2.5',
          'mimo-v2.5-pro',
          'minimax-m3',
          'minimax-m2.7',
          'qwen3.7-max',
          'qwen3.7-plus',
          'qwen3.6-plus',
          'deepseek-v4-pro',
          'deepseek-v4-flash',
        ],
      );
    });

    test('routes MiniMax and Qwen through the Anthropic-compatible endpoint',
        () {
      for (final id in [
        'minimax-m3',
        'minimax-m2.7',
        'qwen3.7-max',
        'qwen3.7-plus',
        'qwen3.6-plus',
      ]) {
        expect(openCodeGoUsesAnthropicApi(id), isTrue, reason: id);
      }
      expect(openCodeGoUsesAnthropicApi('glm-5.2'), isFalse);
      expect(openCodeGoUsesAnthropicApi('grok-4.5'), isFalse);
      expect(openCodeGoUsesAnthropicApi('kimi-k3'), isFalse);
    });

    test('keeps fallbacks on the same API protocol as the primary model', () {
      expect(
        openCodeGoFallbackForSameApi('glm-5.2', 'mimo-v2.5-pro'),
        'mimo-v2.5-pro',
      );
      expect(
        openCodeGoFallbackForSameApi('qwen3.7-max', 'minimax-m3'),
        'minimax-m3',
      );
      expect(
        openCodeGoFallbackForSameApi('glm-5.2', 'qwen3.7-max'),
        'glm-5.2',
      );
      expect(
        openCodeGoFallbackForSameApi('qwen3.7-max', 'glm-5.2'),
        'qwen3.7-max',
      );
    });
  });

  group('OpenCode Go endpoint migration', () {
    test('replaces the obsolete API host', () {
      expect(
        normalizeOpenCodeGoBaseUrl('https://api.opencode.ai'),
        openCodeGoBaseUrl,
      );
      expect(
        normalizeOpenCodeGoBaseUrl('https://api.opencode.ai/'),
        openCodeGoBaseUrl,
      );
    });

    test('keeps custom endpoints and normalizes trailing slashes', () {
      expect(
        normalizeOpenCodeGoBaseUrl('https://proxy.example.com/go///'),
        'https://proxy.example.com/go',
      );
    });
  });
}
