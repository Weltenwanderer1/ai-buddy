/// Canonical OpenCode Go API base. OpenAI-compatible models use
/// `/v1/chat/completions`; Anthropic-compatible models use `/v1/messages`.
const openCodeGoBaseUrl = 'https://opencode.ai/zen/go';

class OpenCodeGoModel {
  const OpenCodeGoModel(this.id, this.name, {this.usesAnthropicApi = false});

  final String id;
  final String name;
  final bool usesAnthropicApi;

  Map<String, String> toDropdownEntry() => {'id': id, 'name': name};
}

/// Presets shown in Settings. IDs follow the OpenCode Go model API.
const openCodeGoModels = <OpenCodeGoModel>[
  OpenCodeGoModel('grok-4.5', 'Grok 4.5'),
  OpenCodeGoModel('glm-5.2', 'GLM-5.2'),
  OpenCodeGoModel('glm-5.1', 'GLM-5.1'),
  OpenCodeGoModel('kimi-k3', 'Kimi K3'),
  OpenCodeGoModel('kimi-k2.7-code', 'Kimi K2.7 Code'),
  OpenCodeGoModel('kimi-k2.6', 'Kimi K2.6'),
  OpenCodeGoModel('mimo-v2.5', 'MiMo-V2.5'),
  OpenCodeGoModel('mimo-v2.5-pro', 'MiMo-V2.5-Pro'),
  OpenCodeGoModel('minimax-m3', 'MiniMax M3', usesAnthropicApi: true),
  OpenCodeGoModel('minimax-m2.7', 'MiniMax M2.7', usesAnthropicApi: true),
  OpenCodeGoModel('qwen3.7-max', 'Qwen3.7 Max', usesAnthropicApi: true),
  OpenCodeGoModel('qwen3.7-plus', 'Qwen3.7 Plus', usesAnthropicApi: true),
  OpenCodeGoModel('qwen3.6-plus', 'Qwen3.6 Plus', usesAnthropicApi: true),
  OpenCodeGoModel('deepseek-v4-pro', 'DeepSeek V4 Pro'),
  OpenCodeGoModel('deepseek-v4-flash', 'DeepSeek V4 Flash'),
];

bool openCodeGoUsesAnthropicApi(String modelId) => openCodeGoModels
    .any((model) => model.id == modelId && model.usesAnthropicApi);

/// Provider clients cannot switch wire protocols during their internal
/// fallback. Keep a cross-protocol fallback from being sent to the wrong URL.
String openCodeGoFallbackForSameApi(String primaryModel, String fallbackModel) {
  return openCodeGoUsesAnthropicApi(primaryModel) ==
          openCodeGoUsesAnthropicApi(fallbackModel)
      ? fallbackModel
      : primaryModel;
}

/// Migrates the obsolete host shipped in AI-Buddy 1.25.0 and accepts custom
/// compatible gateways without mangling their path.
String normalizeOpenCodeGoBaseUrl(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'/+$'), '');
  if (normalized.isEmpty || normalized == 'https://api.opencode.ai') {
    return openCodeGoBaseUrl;
  }
  return normalized;
}
