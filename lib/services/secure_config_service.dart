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
  static const keyLlmProvider = 'LLM_PROVIDER';  // 'ollama', 'openrouter', 'openai', 'anthropic', 'opencode-go'
  static const keyTavilyApiKey = 'TAVILY_API_KEY';

  // OpenAI (direct API — OpenAI-compatible)
  static const keyOpenAIBaseUrl = 'OPENAI_BASE_URL';
  static const keyOpenAIApiKey = 'OPENAI_API_KEY';
  static const keyOpenAIModel = 'OPENAI_MODEL';
  static const keyOpenAIFallbackModel = 'OPENAI_FALLBACK_MODEL';

  // Anthropic (direct Messages API)
  static const keyAnthropicBaseUrl = 'ANTHROPIC_BASE_URL';
  static const keyAnthropicApiKey = 'ANTHROPIC_API_KEY';
  static const keyAnthropicModel = 'ANTHROPIC_MODEL';
  static const keyAnthropicFallbackModel = 'ANTHROPIC_FALLBACK_MODEL';

  // OpenCode Go (OpenAI-compatible API)
  static const keyOpenCodeGoBaseUrl = 'OPENCODE_GO_BASE_URL';
  static const keyOpenCodeGoApiKey = 'OPENCODE_GO_API_KEY';
  static const keyOpenCodeGoModel = 'OPENCODE_GO_MODEL';
  static const keyOpenCodeGoFallbackModel = 'OPENCODE_GO_FALLBACK_MODEL';

  // Email (IMAP)
  static const keyImapServer = 'IMAP_SERVER';
  static const keyImapPort = 'IMAP_PORT';
  static const keyEmailAddress = 'EMAIL_ADDRESS';
  static const keyEmailPassword = 'EMAIL_PASSWORD';
  static const keyImapUseSsl = 'IMAP_USE_SSL';

  // Embedding config
  static const keyEmbeddingProvider = 'EMBEDDING_PROVIDER';  // 'ollama', 'openai', 'openrouter'
  static const keyEmbeddingBaseUrl = 'EMBEDDING_BASE_URL';
  static const keyEmbeddingApiKey = 'EMBEDDING_API_KEY';
  static const keyEmbeddingModel = 'EMBEDDING_MODEL';

  // TTS config
  static const keyTtsEngine = 'TTS_ENGINE';
  static const keyPiperVoice = 'PIPER_VOICE';
  static const keyPiperSpeed = 'PIPER_SPEED';
  // Cloud TTS (optional, higher quality): OpenAI TTS + ElevenLabs
  static const keyTtsCloudProvider = 'TTS_CLOUD_PROVIDER'; // 'openai' | 'elevenlabs'
  static const keyOpenAiTtsKey = 'OPENAI_TTS_API_KEY';
  static const keyOpenAiTtsVoice = 'OPENAI_TTS_VOICE';
  static const keyOpenAiTtsModel = 'OPENAI_TTS_MODEL';
  static const keyElevenLabsKey = 'ELEVENLABS_API_KEY';
  static const keyElevenLabsVoice = 'ELEVENLABS_VOICE_ID';
  static const keyElevenLabsModel = 'ELEVENLABS_MODEL';

  // Buddy name
  static const keyBuddyName = 'BUDDY_NAME';
  static const keyProactivityLevel = 'PROACTIVITY_LEVEL';

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
      keyOpenAIBaseUrl,
      keyOpenAIApiKey,
      keyOpenAIModel,
      keyOpenAIFallbackModel,
      keyAnthropicBaseUrl,
      keyAnthropicApiKey,
      keyAnthropicModel,
      keyAnthropicFallbackModel,
      keyOpenCodeGoBaseUrl,
      keyOpenCodeGoApiKey,
      keyOpenCodeGoModel,
      keyOpenCodeGoFallbackModel,
      keyImapServer,
      keyImapPort,
      keyEmailAddress,
      keyEmailPassword,
      keyImapUseSsl,
      keyEmbeddingProvider,
      keyEmbeddingBaseUrl,
      keyEmbeddingApiKey,
      keyEmbeddingModel,
      keyTtsEngine,
      keyPiperVoice,
      keyPiperSpeed,
      keyTtsCloudProvider,
      keyOpenAiTtsKey,
      keyOpenAiTtsVoice,
      keyOpenAiTtsModel,
      keyElevenLabsKey,
      keyElevenLabsVoice,
      keyElevenLabsModel,
      keyBuddyName,
      keyProactivityLevel,
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
  // Kein eingebauter Default-Key: echte Keys gehören in Secure Storage
  // oder .env, nie ins Repo (siehe README).
  String get ollamaApiKey =>
      _cache[keyOllamaApiKey] ?? _env(keyOllamaApiKey) ?? '';
  String get ollamaModel =>
      _cache[keyOllamaModel] ?? _env(keyOllamaModel) ?? 'kimi-k2.6:cloud';
  String get ollamaFallbackModel =>
      _cache[keyOllamaFallbackModel] ?? _env(keyOllamaFallbackModel) ?? 'deepseek-v4-flash:cloud';
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
  bool get useLocalModel => llmProvider == 'local';
  bool get useOpenAI => llmProvider == 'openai';
  bool get useAnthropic => llmProvider == 'anthropic';
  bool get useOpenCodeGo => llmProvider == 'opencode-go';

  // OpenAI getters
  String get openAIBaseUrl =>
      _cache[keyOpenAIBaseUrl] ?? _env(keyOpenAIBaseUrl) ?? 'https://api.openai.com';
  String get openAIApiKey =>
      _cache[keyOpenAIApiKey] ?? _env(keyOpenAIApiKey) ?? '';
  String get openAIModel =>
      _cache[keyOpenAIModel] ?? _env(keyOpenAIModel) ?? 'gpt-4o';
  String get openAIFallbackModel =>
      _cache[keyOpenAIFallbackModel] ?? _env(keyOpenAIFallbackModel) ?? 'gpt-4o-mini';

  // Anthropic getters
  String get anthropicBaseUrl =>
      _cache[keyAnthropicBaseUrl] ?? _env(keyAnthropicBaseUrl) ?? 'https://api.anthropic.com';
  String get anthropicApiKey =>
      _cache[keyAnthropicApiKey] ?? _env(keyAnthropicApiKey) ?? '';
  String get anthropicModel =>
      _cache[keyAnthropicModel] ?? _env(keyAnthropicModel) ?? 'claude-sonnet-4-20250514';
  String get anthropicFallbackModel =>
      _cache[keyAnthropicFallbackModel] ?? _env(keyAnthropicFallbackModel) ?? 'claude-3-5-haiku-20241022';

  // OpenCode Go getters
  String get openCodeGoBaseUrl =>
      _cache[keyOpenCodeGoBaseUrl] ?? _env(keyOpenCodeGoBaseUrl) ?? 'https://api.opencode.ai';
  String get openCodeGoApiKey =>
      _cache[keyOpenCodeGoApiKey] ?? _env(keyOpenCodeGoApiKey) ?? '';
  String get openCodeGoModel =>
      _cache[keyOpenCodeGoModel] ?? _env(keyOpenCodeGoModel) ?? 'glm-5.2';
  String get openCodeGoFallbackModel =>
      _cache[keyOpenCodeGoFallbackModel] ?? _env(keyOpenCodeGoFallbackModel) ?? 'mimo-v2.5-pro';

  /// Active config — resolves based on the selected LLM provider.
  String get activeBaseUrl {
    switch (llmProvider) {
      case 'openrouter': return openRouterBaseUrl;
      case 'openai': return openAIBaseUrl;
      case 'anthropic': return anthropicBaseUrl;
      case 'opencode-go': return openCodeGoBaseUrl;
      default: return ollamaBaseUrl;
    }
  }
  String get activeApiKey {
    switch (llmProvider) {
      case 'openrouter': return openRouterApiKey;
      case 'openai': return openAIApiKey;
      case 'anthropic': return anthropicApiKey;
      case 'opencode-go': return openCodeGoApiKey;
      default: return ollamaApiKey;
    }
  }
  String get activeModel {
    switch (llmProvider) {
      case 'openrouter': return openRouterModel;
      case 'openai': return openAIModel;
      case 'anthropic': return anthropicModel;
      case 'opencode-go': return openCodeGoModel;
      default: return ollamaModel;
    }
  }
  String get activeFallbackModel {
    switch (llmProvider) {
      case 'openrouter': return openRouterFallbackModel;
      case 'openai': return openAIFallbackModel;
      case 'anthropic': return anthropicFallbackModel;
      case 'opencode-go': return openCodeGoFallbackModel;
      default: return ollamaFallbackModel;
    }
  }
  String get tavilyApiKey =>
      _cache[keyTavilyApiKey] ?? _env(keyTavilyApiKey) ?? '';

  // Email (IMAP) getters
  String get imapServer =>
      _cache[keyImapServer] ?? _env(keyImapServer) ?? 'imap.gmail.com';
  int get imapPort {
    final raw = _cache[keyImapPort] ?? _env(keyImapPort) ?? '993';
    return int.tryParse(raw) ?? 993;
  }
  String get emailAddress =>
      _cache[keyEmailAddress] ?? _env(keyEmailAddress) ?? '';
  String get emailPassword =>
      _cache[keyEmailPassword] ?? _env(keyEmailPassword) ?? '';
  bool get imapUseSsl {
    final raw = _cache[keyImapUseSsl] ?? _env(keyImapUseSsl) ?? 'true';
    return raw.toLowerCase() == 'true';
  }
  bool get isEmailConfigured =>
      emailAddress.isNotEmpty && emailPassword.isNotEmpty && imapServer.isNotEmpty;

  // Embedding getters
  String get embeddingProvider =>
      _cache[keyEmbeddingProvider] ?? _env(keyEmbeddingProvider) ?? 'ollama';
  String get embeddingBaseUrl =>
      _cache[keyEmbeddingBaseUrl] ?? _env(keyEmbeddingBaseUrl) ?? 'https://ollama.com/api';
  String get embeddingApiKey =>
      _cache[keyEmbeddingApiKey] ?? _env(keyEmbeddingApiKey) ?? '';
  String get embeddingModel =>
      _cache[keyEmbeddingModel] ?? _env(keyEmbeddingModel) ?? 'nomic-embed-text';

  // TTS config
  String get ttsEngine => _cache[keyTtsEngine] ?? _env(keyTtsEngine) ?? 'piper';
  String get piperVoice => _cache[keyPiperVoice] ?? _env(keyPiperVoice) ?? 'de_DE-thorsten-high';

  // Cloud TTS getters
  String get ttsCloudProvider =>
      _cache[keyTtsCloudProvider] ?? _env(keyTtsCloudProvider) ?? 'openai';
  /// OpenAI TTS key — falls back to the OpenAI LLM key so a user who already
  /// configured OpenAI doesn't have to enter it twice.
  String get openAiTtsKey {
    final dedicated = _cache[keyOpenAiTtsKey] ?? _env(keyOpenAiTtsKey) ?? '';
    return dedicated.isNotEmpty ? dedicated : openAIApiKey;
  }
  String get openAiTtsVoice =>
      _cache[keyOpenAiTtsVoice] ?? _env(keyOpenAiTtsVoice) ?? 'alloy';
  String get openAiTtsModel =>
      _cache[keyOpenAiTtsModel] ?? _env(keyOpenAiTtsModel) ?? 'tts-1';
  String get elevenLabsKey =>
      _cache[keyElevenLabsKey] ?? _env(keyElevenLabsKey) ?? '';
  String get elevenLabsVoice =>
      _cache[keyElevenLabsVoice] ?? _env(keyElevenLabsVoice) ?? 'JBFqnCBsd6RMkjVDRZzb';
  String get elevenLabsModel =>
      _cache[keyElevenLabsModel] ?? _env(keyElevenLabsModel) ?? 'eleven_multilingual_v2';

  Future<void> setTtsCloudProvider(String value) async {
    await _storage.write(key: keyTtsCloudProvider, value: value);
    _cache[keyTtsCloudProvider] = value;
  }
  Future<void> setOpenAiTtsKey(String value) async {
    await _storage.write(key: keyOpenAiTtsKey, value: value);
    _cache[keyOpenAiTtsKey] = value;
  }
  Future<void> setOpenAiTtsVoice(String value) async {
    await _storage.write(key: keyOpenAiTtsVoice, value: value);
    _cache[keyOpenAiTtsVoice] = value;
  }
  Future<void> setElevenLabsKey(String value) async {
    await _storage.write(key: keyElevenLabsKey, value: value);
    _cache[keyElevenLabsKey] = value;
  }
  Future<void> setElevenLabsVoice(String value) async {
    await _storage.write(key: keyElevenLabsVoice, value: value);
    _cache[keyElevenLabsVoice] = value;
  }
  /// Buddy display name (e.g. "Buddy" or a custom name).
  String get buddyName => _cache[keyBuddyName] ?? 'Buddy';

  // --- Buddy name setter ---
  Future<void> setBuddyName(String value) async {
    await _storage.write(key: keyBuddyName, value: value);
    _cache[keyBuddyName] = value;
  }

  double get piperSpeed {
    final raw = _cache[keyPiperSpeed] ?? _env(keyPiperSpeed) ?? '1.0';
    return double.tryParse(raw) ?? 1.0;
  }

  int get proactivityLevel {
    final raw = _cache[keyProactivityLevel] ?? _env(keyProactivityLevel) ?? '2';
    return int.tryParse(raw) ?? 2;
  }

  Future<void> setProactivityLevel(int value) async {
    final clamped = value.clamp(0, 3);
    await _storage.write(key: keyProactivityLevel, value: clamped.toString());
    _cache[keyProactivityLevel] = clamped.toString();
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

  // OpenAI setters
  Future<void> setOpenAIBaseUrl(String value) async {
    await _storage.write(key: keyOpenAIBaseUrl, value: value);
    _cache[keyOpenAIBaseUrl] = value;
  }
  Future<void> setOpenAIApiKey(String value) async {
    await _storage.write(key: keyOpenAIApiKey, value: value);
    _cache[keyOpenAIApiKey] = value;
  }
  Future<void> setOpenAIModel(String value) async {
    await _storage.write(key: keyOpenAIModel, value: value);
    _cache[keyOpenAIModel] = value;
  }
  Future<void> setOpenAIFallbackModel(String value) async {
    await _storage.write(key: keyOpenAIFallbackModel, value: value);
    _cache[keyOpenAIFallbackModel] = value;
  }

  // Anthropic setters
  Future<void> setAnthropicBaseUrl(String value) async {
    await _storage.write(key: keyAnthropicBaseUrl, value: value);
    _cache[keyAnthropicBaseUrl] = value;
  }
  Future<void> setAnthropicApiKey(String value) async {
    await _storage.write(key: keyAnthropicApiKey, value: value);
    _cache[keyAnthropicApiKey] = value;
  }
  Future<void> setAnthropicModel(String value) async {
    await _storage.write(key: keyAnthropicModel, value: value);
    _cache[keyAnthropicModel] = value;
  }
  Future<void> setAnthropicFallbackModel(String value) async {
    await _storage.write(key: keyAnthropicFallbackModel, value: value);
    _cache[keyAnthropicFallbackModel] = value;
  }

  // OpenCode Go setters
  Future<void> setOpenCodeGoBaseUrl(String value) async {
    await _storage.write(key: keyOpenCodeGoBaseUrl, value: value);
    _cache[keyOpenCodeGoBaseUrl] = value;
  }
  Future<void> setOpenCodeGoApiKey(String value) async {
    await _storage.write(key: keyOpenCodeGoApiKey, value: value);
    _cache[keyOpenCodeGoApiKey] = value;
  }
  Future<void> setOpenCodeGoModel(String value) async {
    await _storage.write(key: keyOpenCodeGoModel, value: value);
    _cache[keyOpenCodeGoModel] = value;
  }
  Future<void> setOpenCodeGoFallbackModel(String value) async {
    await _storage.write(key: keyOpenCodeGoFallbackModel, value: value);
    _cache[keyOpenCodeGoFallbackModel] = value;
  }

  Future<void> setTavilyApiKey(String value) async {
    await _storage.write(key: keyTavilyApiKey, value: value);
    _cache[keyTavilyApiKey] = value;
  }

  // Email (IMAP) setters
  Future<void> setImapServer(String value) async {
    await _storage.write(key: keyImapServer, value: value);
    _cache[keyImapServer] = value;
  }

  Future<void> setImapPort(int value) async {
    await _storage.write(key: keyImapPort, value: value.toString());
    _cache[keyImapPort] = value.toString();
  }

  Future<void> setEmailAddress(String value) async {
    await _storage.write(key: keyEmailAddress, value: value);
    _cache[keyEmailAddress] = value;
  }

  Future<void> setEmailPassword(String value) async {
    await _storage.write(key: keyEmailPassword, value: value);
    _cache[keyEmailPassword] = value;
  }

  Future<void> setImapUseSsl(bool value) async {
    await _storage.write(key: keyImapUseSsl, value: value.toString());
    _cache[keyImapUseSsl] = value.toString();
  }

  // Embedding setters
  Future<void> setEmbeddingProvider(String value) async {
    await _storage.write(key: keyEmbeddingProvider, value: value);
    _cache[keyEmbeddingProvider] = value;
  }

  Future<void> setEmbeddingBaseUrl(String value) async {
    await _storage.write(key: keyEmbeddingBaseUrl, value: value);
    _cache[keyEmbeddingBaseUrl] = value;
  }

  Future<void> setEmbeddingApiKey(String value) async {
    await _storage.write(key: keyEmbeddingApiKey, value: value);
    _cache[keyEmbeddingApiKey] = value;
  }

  Future<void> setEmbeddingModel(String value) async {
    await _storage.write(key: keyEmbeddingModel, value: value);
    _cache[keyEmbeddingModel] = value;
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
  bool get isOpenAIConfigured => openAIApiKey.isNotEmpty;
  bool get isAnthropicConfigured => anthropicApiKey.isNotEmpty;
  bool get isOpenCodeGoConfigured => openCodeGoApiKey.isNotEmpty;
}