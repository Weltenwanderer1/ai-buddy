import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Manages API keys and config securely.
/// Priority: Secure Storage > .env file > hardcoded defaults.
class SecureConfigService {
  static const _storage = FlutterSecureStorage();

  // Keys
  static const keyOllamaBaseUrl = 'OLLAMA_CLOUD_BASE_URL';
  static const keyOllamaApiKey = 'OLLAMA_CLOUD_API_KEY';
  static const keyOllamaModel = 'OLLAMA_CLOUD_MODEL';
  static const keyOllamaFallbackModel = 'OLLAMA_CLOUD_FALLBACK_MODEL';
  static const keyOpenRouterBaseUrl = 'OPENROUTER_BASE_URL';
  static const keyOpenRouterApiKey = 'OPENROUTER_API_KEY';
  static const keyOpenRouterModel = 'OPENROUTER_MODEL';
  static const keyOpenRouterFallbackModel = 'OPENROUTER_FALLBACK_MODEL';
  static const keyLlmProvider = 'LLM_PROVIDER';  // 'ollama' or 'openrouter'
  static const keyElevenLabsApiKey = 'ELEVENLABS_API_KEY';
  static const keyElevenLabsVoiceId = 'ELEVENLABS_VOICE_ID';
  static const keyElevenLabsModelId = 'ELEVENLABS_MODEL_ID';
  static const keyTavilyApiKey = 'TAVILY_API_KEY';

  // Cache
  final Map<String, String> _cache = {};

  /// Initialize: read all keys into cache, migrate .env values if present.
  Future<void> init() async {
    final allKeys = [
      keyOllamaBaseUrl,
      keyOllamaApiKey,
      keyOllamaModel,
      keyOllamaFallbackModel,
      keyOpenRouterBaseUrl,
      keyOpenRouterApiKey,
      keyOpenRouterModel,
      keyOpenRouterFallbackModel,
      keyLlmProvider,
      keyElevenLabsApiKey,
      keyElevenLabsVoiceId,
      keyElevenLabsModelId,
      keyTtsEngine,
      keyTavilyApiKey,
    ];

    for (final key in allKeys) {
      final secured = await _storage.read(key: key);
      if (secured != null) {
        _cache[key] = secured;
      } else {
        // Migrate from .env if present
        final envVal = dotenv.env[key];
        if (envVal != null && envVal.isNotEmpty) {
          await _storage.write(key: key, value: envVal);
          _cache[key] = envVal;
        }
      }
    }

    // Default ElevenLabs config (Free Plan)
    if ((_cache[keyElevenLabsApiKey]?.isEmpty ?? true) &&
        (_env(keyElevenLabsApiKey)?.isEmpty ?? true)) {
      const defaultKey = 'sk_8a79b0838d5c6a1740dc325178bda09f9553e5979b0866d7';
      await _storage.write(key: keyElevenLabsApiKey, value: defaultKey);
      _cache[keyElevenLabsApiKey] = defaultKey;
    }
    if ((_cache[keyElevenLabsVoiceId]?.isEmpty ?? true) &&
        (_env(keyElevenLabsVoiceId)?.isEmpty ?? true)) {
      const defaultVoice = 'XB0fDUnXU5powFXDhCwa'; // ElevenLabs "Bella" (warm, natürlich)
      await _storage.write(key: keyElevenLabsVoiceId, value: defaultVoice);
      _cache[keyElevenLabsVoiceId] = defaultVoice;
    }
  }

  // --- Helpers ---

  /// Safe dotenv lookup — returns null if dotenv is not initialized.
  String? _env(String key) => dotenv.isInitialized ? dotenv.env[key] : null;

  // --- Getters with defaults ---

  String get ollamaBaseUrl =>
      _cache[keyOllamaBaseUrl] ?? _env(keyOllamaBaseUrl) ?? 'https://ollama.com/api';
  String get ollamaApiKey =>
      _cache[keyOllamaApiKey] ?? _env(keyOllamaApiKey) ?? 'b8ddca52fce64596b6e075c5537222a6.hbKSd4qQklkZQs6PQLwc4uBU';
  String get ollamaModel =>
      _cache[keyOllamaModel] ?? _env(keyOllamaModel) ?? 'kimi-k2.6:cloud';
  String get ollamaFallbackModel =>
      _cache[keyOllamaFallbackModel] ?? _env(keyOllamaFallbackModel) ?? 'deepseek-v4-flash:cloud';
  String get elevenLabsApiKey =>
      _cache[keyElevenLabsApiKey] ?? _env(keyElevenLabsApiKey) ?? '';
  String get elevenLabsVoiceId =>
      _cache[keyElevenLabsVoiceId] ?? _env(keyElevenLabsVoiceId) ?? '';
  String get elevenLabsModelId =>
      _cache[keyElevenLabsModelId] ?? _env(keyElevenLabsModelId) ?? 'eleven_multilingual_v2';
  String get openRouterBaseUrl =>
      _cache[keyOpenRouterBaseUrl] ?? _env(keyOpenRouterBaseUrl) ?? 'https://openrouter.ai/api';
  String get openRouterApiKey =>
      _cache[keyOpenRouterApiKey] ?? _env(keyOpenRouterApiKey) ?? '';
  String get openRouterModel =>
      _cache[keyOpenRouterModel] ?? _env(keyOpenRouterModel) ?? 'anthropic/claude-3.5-sonnet';
  String get openRouterFallbackModel =>
      _cache[keyOpenRouterFallbackModel] ?? _env(keyOpenRouterFallbackModel) ?? 'google/gemini-2.0-flash-001';
  String get llmProvider =>
      _cache[keyLlmProvider] ?? _env(keyLlmProvider) ?? 'ollama';
  bool get useOpenRouter => llmProvider == 'openrouter';

  String get activeBaseUrl => useOpenRouter ? openRouterBaseUrl : ollamaBaseUrl;
  String get activeApiKey => useOpenRouter ? openRouterApiKey : ollamaApiKey;
  String get activeModel => useOpenRouter ? openRouterModel : ollamaModel;
  String get activeFallbackModel => useOpenRouter ? openRouterFallbackModel : ollamaFallbackModel;
  String get tavilyApiKey =>
      _cache[keyTavilyApiKey] ?? _env(keyTavilyApiKey) ?? '';

  // --- Setters ---

  Future<void> setOllamaBaseUrl(String value) async {
    await _storage.write(key: keyOllamaBaseUrl, value: value);
    _cache[keyOllamaBaseUrl] = value;
  }

  Future<void> setOllamaApiKey(String value) async {
    await _storage.write(key: keyOllamaApiKey, value: value);
    _cache[keyOllamaApiKey] = value;
  }

  Future<void> setOllamaModel(String value) async {
    await _storage.write(key: keyOllamaModel, value: value);
    _cache[keyOllamaModel] = value;
  }

  Future<void> setOllamaFallbackModel(String value) async {
    await _storage.write(key: keyOllamaFallbackModel, value: value);
    _cache[keyOllamaFallbackModel] = value;
  }

  Future<void> setElevenLabsApiKey(String value) async {
    await _storage.write(key: keyElevenLabsApiKey, value: value);
    _cache[keyElevenLabsApiKey] = value;
  }

  Future<void> setElevenLabsVoiceId(String value) async {
    await _storage.write(key: keyElevenLabsVoiceId, value: value);
    _cache[keyElevenLabsVoiceId] = value;
  }

  Future<void> setElevenLabsModelId(String value) async {
    await _storage.write(key: keyElevenLabsModelId, value: value);
    _cache[keyElevenLabsModelId] = value;
  }

  Future<void> setTavilyApiKey(String value) async {
    await _storage.write(key: keyTavilyApiKey, value: value);
    _cache[keyTavilyApiKey] = value;
  }

  Future<void> setOpenRouterApiKey(String value) async {
    await _storage.write(key: keyOpenRouterApiKey, value: value);
    _cache[keyOpenRouterApiKey] = value;
  }

  Future<void> setOpenRouterModel(String value) async {
    await _storage.write(key: keyOpenRouterModel, value: value);
    _cache[keyOpenRouterModel] = value;
  }

  Future<void> setOpenRouterFallbackModel(String value) async {
    await _storage.write(key: keyOpenRouterFallbackModel, value: value);
    _cache[keyOpenRouterFallbackModel] = value;
  }

  Future<void> setLlmProvider(String value) async {
    await _storage.write(key: keyLlmProvider, value: value);
    _cache[keyLlmProvider] = value;
  }

  bool get isOllamaConfigured => ollamaApiKey.isNotEmpty;
  bool get isOpenRouterConfigured => openRouterApiKey.isNotEmpty;
  bool get isElevenLabsConfigured => elevenLabsApiKey.isNotEmpty && elevenLabsVoiceId.isNotEmpty;

  // TTS engine preference
  static const keyTtsEngine = 'TTS_ENGINE';
  String get ttsEngine => _cache[keyTtsEngine] ?? _env(keyTtsEngine) ?? 'elevenlabs';

  Future<void> setTtsEngine(String value) async {
    await _storage.write(key: keyTtsEngine, value: value);
    _cache[keyTtsEngine] = value;
  }
}
