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
  static const keyLlmProvider = 'LLM_PROVIDER';  // 'ollama', 'openrouter', or 'local'
  static const keyTavilyApiKey = 'TAVILY_API_KEY';

  // TTS config
  static const keyTtsEngine = 'TTS_ENGINE';
  static const keyPiperVoice = 'PIPER_VOICE';
  static const keyPiperSpeed = 'PIPER_SPEED';

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
      keyTavilyApiKey,
      keyTtsEngine,
      keyPiperVoice,
      keyPiperSpeed,
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
  String get openRouterBaseUrl =>
      _cache[keyOpenRouterBaseUrl] ?? _env(keyOpenRouterBaseUrl) ?? 'https://openrouter.ai/api';
  String get openRouterApiKey =>
      _cache[keyOpenRouterApiKey] ?? _env(keyOpenRouterApiKey) ?? 'sk-or-...1477';
  String get openRouterModel =>
      _cache[keyOpenRouterModel] ?? _env(keyOpenRouterModel) ?? 'anthropic/claude-3.5-sonnet';
  String get openRouterFallbackModel =>
      _cache[keyOpenRouterFallbackModel] ?? _env(keyOpenRouterFallbackModel) ?? 'google/gemini-2.0-flash-001';
  String get llmProvider =>
      _cache[keyLlmProvider] ?? _env(keyLlmProvider) ?? 'ollama';
  bool get useOpenRouter => llmProvider == 'openrouter';
  bool get useLocalModel => llmProvider == 'local';

  String get activeBaseUrl => useOpenRouter ? openRouterBaseUrl : ollamaBaseUrl;
  String get activeApiKey => useOpenRouter ? openRouterApiKey : ollamaApiKey;
  String get activeModel => useOpenRouter ? openRouterModel : ollamaModel;
  String get activeFallbackModel => useOpenRouter ? openRouterFallbackModel : ollamaFallbackModel;
  String get tavilyApiKey =>
      _cache[keyTavilyApiKey] ?? _env(keyTavilyApiKey) ?? '';

  // TTS config
  String get ttsEngine => _cache[keyTtsEngine] ?? _env(keyTtsEngine) ?? 'piper';
  String get piperVoice => _cache[keyPiperVoice] ?? _env(keyPiperVoice) ?? 'de_DE-thorsten-high';
  double get piperSpeed {
    final raw = _cache[keyPiperSpeed] ?? _env(keyPiperSpeed) ?? '1.0';
    return double.tryParse(raw) ?? 1.0;
  }

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

  Future<void> setTavilyApiKey(String value) async {
    await _storage.write(key: keyTavilyApiKey, value: value);
    _cache[keyTavilyApiKey] = value;
  }

  Future<void> setTtsEngine(String value) async {
    await _storage.write(key: keyTtsEngine, value: value);
    _cache[keyTtsEngine] = value;
  }

  Future<void> setPiperVoice(String value) async {
    await _storage.write(key: keyPiperVoice, value: value);
    _cache[keyPiperVoice] = value;
  }

  Future<void> setPiperSpeed(double value) async {
    final str = value.toStringAsFixed(2);
    await _storage.write(key: keyPiperSpeed, value: str);
    _cache[keyPiperSpeed] = str;
  }

  bool get isOllamaConfigured => ollamaApiKey.isNotEmpty;
  bool get isOpenRouterConfigured => openRouterApiKey.isNotEmpty;
}