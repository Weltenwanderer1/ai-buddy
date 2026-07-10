import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/i18n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../core/theme/buddy_colors.dart';
import '../core/version.dart';
import '../services/secure_config_service.dart';
import '../services/tts_playback_service.dart';
import '../services/piper_tts_service.dart';
import '../services/backup_service.dart';

import '../services/chat_history_service.dart';
import '../services/memory_service.dart';
import '../services/persona_service.dart';
import '../services/persona_evolution_service.dart';
import '../services/self_identity_service.dart';
import '../services/tile_download_service.dart';
import '../services/ollama_cloud_service.dart';
import '../services/anthropic_service.dart';
import '../services/embedding_service.dart';
import '../widgets/offline_map_dialog.dart';
import 'persona_editor_screen.dart';
import 'self_identity_screen.dart';
import 'buddy_notes_screen.dart';
import 'buddy_capabilities_screen.dart';
import 'memory_browser_screen.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import 'package:package_info_plus/package_info_plus.dart';
import '../tools/tool_registry.dart';
import '../tools/read_email_tool.dart';
import '../tools/control_screen_tool.dart';
import '../widgets/settings/model_dropdown.dart';
import '../widgets/settings/section_header.dart';
import '../widgets/settings/expandable_section.dart';
import '../widgets/settings/settings_button.dart';
import '../widgets/settings/glass_text_field.dart';
import '../widgets/settings/gradient_button.dart';
import '../widgets/settings/outline_button.dart';
import '../widgets/settings/result_box.dart';
import '../widgets/settings/badge.dart';
import '../widgets/settings/divider.dart';
import '../widgets/settings/piper_voice_tile.dart';
import '../widgets/settings/scheduler_section.dart';
import '../widgets/settings/proactivity_tile.dart';
import '../widgets/settings/appearance_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  final _ollamaKeyController = TextEditingController();
  final _ollamaBaseUrlController = TextEditingController();
  final _ollamaModelController = TextEditingController();
  final _ollamaFallbackController = TextEditingController();
  // OpenRouter controllers
  final _openRouterKeyController = TextEditingController();
  final _openRouterModelController = TextEditingController();
  final _openRouterFallbackController = TextEditingController();
  // OpenAI controllers
  final _openAIKeyController = TextEditingController();
  final _openAIModelController = TextEditingController();
  final _openAIFallbackController = TextEditingController();
  // Anthropic controllers
  final _anthropicKeyController = TextEditingController();
  final _anthropicModelController = TextEditingController();
  final _anthropicFallbackController = TextEditingController();
  // OpenCode Go controllers
  final _openCodeGoKeyController = TextEditingController();
  final _openCodeGoModelController = TextEditingController();
  final _openCodeGoFallbackController = TextEditingController();
  // Buddy name controller
  final _buddyNameController = TextEditingController();
  // Email controllers
  final _emailAddressController = TextEditingController();
  final _emailPasswordController = TextEditingController();
  final _imapServerController = TextEditingController();
  final _imapPortController = TextEditingController();
  // Embedding controllers
  final _embeddingBaseUrlController = TextEditingController();
  final _embeddingApiKeyController = TextEditingController();
  final _embeddingModelController = TextEditingController();
  // Cloud TTS controllers
  final _openAiTtsKeyController = TextEditingController();
  final _openAiTtsVoiceController = TextEditingController();
  final _elevenLabsKeyController = TextEditingController();
  final _elevenLabsVoiceController = TextEditingController();
  String _ttsCloudProvider = 'openai';

  // Cached futures — creating these inline in build() re-runs the
  // filesystem/platform-channel call on every rebuild (every expand/collapse).
  late final Future<PackageInfo> _packageInfoFuture = PackageInfo.fromPlatform();
  Future<bool> _offlineTilesFuture = TileDownloadService.hasOfflineTiles();

  bool _isTestingOllama = false;
  String? _ollamaTestResult;
  bool _isTestingEmbedding = false;
  String? _embeddingTestResult;

  bool _ollamaExpanded = true;
  bool _elevenExpanded = true;
  bool _buddyNameExpanded = true;
  bool _emailExpanded = false;
  bool _embeddingExpanded = false;
  String _embeddingProvider = 'ollama';

  // Kollabierbare Settings-Sektionen
  bool _secAppearance = false;
  bool _secBuddy = false;
  bool _secTools = false;
  bool _secConfig = false;
  bool _secScheduler = false;
  bool _secData = false;
  bool _secAbout = false;
  String _llmProvider = 'ollama';
  TtsEngine _ttsEngine = TtsEngine.piper;
  String _piperLangFilter = 'all';

  // Cloud model presets
  List<Map<String, String>> get _ollamaModels => [
    {'id': 'kimi-k2.6:cloud', 'name': 'Kimi K2.6 (Kontext: 262k)'},
    {'id': 'deepseek-chat-v4:cloud', 'name': 'DeepSeek Chat V4 (Kontext: 128k)'},
    {'id': 'deepseek-v4-flash:cloud', 'name': 'DeepSeek Flash V4 (Schnell)'},
  ];
  List<Map<String, String>> get _openRouterModels => [
    {'id': 'openrouter/moonshotai/kimi-k2.6', 'name': 'Kimi K2.6 (262k Kontext)'},
    {'id': 'openrouter/deepseek/deepseek-chat-v4', 'name': 'DeepSeek V4 Pro (128k)'},
    {'id': 'anthropic/claude-3.5-sonnet', 'name': 'Claude 3.5 Sonnet (ausgewogen)'},
    {'id': 'google/gemini-2.0-flash-001', 'name': 'Gemini 2.0 Flash (schnell)'},
  ];
  List<Map<String, String>> get _openAIModels => [
    {'id': 'gpt-4o', 'name': 'GPT-4o (ausgewogen)'},
    {'id': 'gpt-4o-mini', 'name': 'GPT-4o mini (schnell)'},
    {'id': 'gpt-4.1', 'name': 'GPT-4.1 (kreativ)'},
    {'id': 'o4-mini', 'name': 'o4-mini (reasoning)'},
  ];
  List<Map<String, String>> get _anthropicModels => [
    {'id': 'claude-sonnet-4-20250514', 'name': 'Claude Sonnet 4 (ausgewogen)'},
    {'id': 'claude-opus-4-20250514', 'name': 'Claude Opus 4 (leistungsstark)'},
    {'id': 'claude-3-5-haiku-20241022', 'name': 'Claude 3.5 Haiku (schnell)'},
  ];
  List<Map<String, String>> get _openCodeGoModels => [
    {'id': 'glm-5.2', 'name': 'GLM-5.2 (Standard)'},
    {'id': 'mimo-v2.5-pro', 'name': 'Mimo V2.5 Pro (Fallback)'},
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final config = context.read<SecureConfigService>();
    _ollamaKeyController.text = config.ollamaApiKey;
    _ollamaBaseUrlController.text = config.ollamaBaseUrl;
    _ollamaModelController.text = config.ollamaModel;
    _ollamaFallbackController.text = config.ollamaFallbackModel;
    _openRouterKeyController.text = config.openRouterApiKey;
    _openRouterModelController.text = config.openRouterModel;
    _openRouterFallbackController.text = config.openRouterFallbackModel;
    _openAIKeyController.text = config.openAIApiKey;
    _openAIModelController.text = config.openAIModel;
    _openAIFallbackController.text = config.openAIFallbackModel;
    _anthropicKeyController.text = config.anthropicApiKey;
    _anthropicModelController.text = config.anthropicModel;
    _anthropicFallbackController.text = config.anthropicFallbackModel;
    _openCodeGoKeyController.text = config.openCodeGoApiKey;
    _openCodeGoModelController.text = config.openCodeGoModel;
    _openCodeGoFallbackController.text = config.openCodeGoFallbackModel;
    _buddyNameController.text = config.buddyName;
    _emailAddressController.text = config.emailAddress;
    _emailPasswordController.text = config.emailPassword;
    _imapServerController.text = config.imapServer;
    _imapPortController.text = config.imapPort.toString();
    _embeddingBaseUrlController.text = config.embeddingBaseUrl;
    _embeddingApiKeyController.text = config.embeddingApiKey;
    _embeddingModelController.text = config.embeddingModel;
    _embeddingProvider = config.embeddingProvider;
    // Cloud TTS: leave the OpenAI key field empty (it falls back to the OpenAI
    // LLM key), prefill voices + the ElevenLabs key.
    _ttsCloudProvider = config.ttsCloudProvider;
    _openAiTtsVoiceController.text = config.openAiTtsVoice;
    _elevenLabsKeyController.text = config.elevenLabsKey;
    _elevenLabsVoiceController.text = config.elevenLabsVoice;
    _llmProvider = config.llmProvider;
    _ttsEngine = switch (config.ttsEngine) {
      'device' => TtsEngine.device,
      'cloud' => TtsEngine.cloud,
      _ => TtsEngine.piper,
    };
  }

  @override
  void dispose() {
    _ollamaKeyController.dispose();
    _ollamaBaseUrlController.dispose();
    _ollamaModelController.dispose();
    _ollamaFallbackController.dispose();
    _openRouterKeyController.dispose();
    _openRouterModelController.dispose();
    _openRouterFallbackController.dispose();
    _openAIKeyController.dispose();
    _openAIModelController.dispose();
    _openAIFallbackController.dispose();
    _anthropicKeyController.dispose();
    _anthropicModelController.dispose();
    _anthropicFallbackController.dispose();
    _openCodeGoKeyController.dispose();
    _openCodeGoModelController.dispose();
    _openCodeGoFallbackController.dispose();
    _buddyNameController.dispose();
    _emailAddressController.dispose();
    _emailPasswordController.dispose();
    _imapServerController.dispose();
    _imapPortController.dispose();
    _embeddingBaseUrlController.dispose();
    _embeddingApiKeyController.dispose();
    _embeddingModelController.dispose();
    _openAiTtsKeyController.dispose();
    _openAiTtsVoiceController.dispose();
    _elevenLabsKeyController.dispose();
    _elevenLabsVoiceController.dispose();
    super.dispose();
  }

  Future<void> _saveBuddyName() async {
    final config = context.read<SecureConfigService>();
    final name = _buddyNameController.text.trim();
    if (name.isEmpty) {
      _buddyNameController.text = 'Buddy';
      await config.setBuddyName('Buddy');
    } else {
      await config.setBuddyName(name);
    }
    if (mounted) _showSnack('Buddy-Name gespeichert ✅', context.buddy.success);
  }

  Future<void> _saveEmailConfig() async {
    final config = context.read<SecureConfigService>();
    await config.setEmailAddress(_emailAddressController.text.trim());
    await config.setEmailPassword(_emailPasswordController.text.trim());
    await config.setImapServer(_imapServerController.text.trim().isEmpty ? 'imap.gmail.com' : _imapServerController.text.trim());
    final port = int.tryParse(_imapPortController.text.trim()) ?? 993;
    await config.setImapPort(port);

    if (!mounted) return;

    // Re-register the email tool so the LLM picks up the new credentials immediately.
    final registry = context.read<ToolRegistry>();
    registry.register(ReadEmailTool(
      server: config.imapServer,
      port: config.imapPort,
      email: config.emailAddress,
      password: config.emailPassword,
      useSsl: config.imapUseSsl,
    ));

    _showSnack('E-Mail-Konfiguration gespeichert ✅', context.buddy.success);
  }

  Future<void> _saveOllamaConfig() async {
    final config = context.read<SecureConfigService>();

    // Persist the selected provider
    await config.setLlmProvider(_llmProvider);

    // Save all cloud config fields
    await config.setOllamaBaseUrl(_ollamaBaseUrlController.text.trim());
    await config.setOllamaApiKey(_ollamaKeyController.text.trim());
    await config.setOllamaModel(_ollamaModelController.text.trim());
    await config.setOllamaFallbackModel(_ollamaFallbackController.text.trim());
    await config.setOpenRouterApiKey(_openRouterKeyController.text.trim());
    await config.setOpenRouterModel(_openRouterModelController.text.trim());
    await config.setOpenRouterFallbackModel(_openRouterFallbackController.text.trim());
    await config.setOpenAIApiKey(_openAIKeyController.text.trim());
    await config.setOpenAIModel(_openAIModelController.text.trim());
    await config.setOpenAIFallbackModel(_openAIFallbackController.text.trim());
    await config.setAnthropicApiKey(_anthropicKeyController.text.trim());
    await config.setAnthropicModel(_anthropicModelController.text.trim());
    await config.setAnthropicFallbackModel(_anthropicFallbackController.text.trim());
    await config.setOpenCodeGoApiKey(_openCodeGoKeyController.text.trim());
    await config.setOpenCodeGoModel(_openCodeGoModelController.text.trim());
    await config.setOpenCodeGoFallbackModel(_openCodeGoFallbackController.text.trim());

    final providerLabel = switch (_llmProvider) {
      'openrouter' => 'OpenRouter',
      'openai' => 'OpenAI',
      'anthropic' => 'Anthropic',
      'opencode-go' => 'OpenCode Go',
      _ => 'Ollama',
    };
    if (mounted) _showSnack('$providerLabel gespeichert ✅', context.buddy.success);
  }

  Future<void> _saveEmbeddingConfig() async {
    final config = context.read<SecureConfigService>();
    final memory = context.read<MemoryService>();

    await config.setEmbeddingProvider(_embeddingProvider);
    await config.setEmbeddingBaseUrl(_embeddingBaseUrlController.text.trim());
    await config.setEmbeddingApiKey(_embeddingApiKeyController.text.trim());
    await config.setEmbeddingModel(_embeddingModelController.text.trim());

    // Re-inject updated config into the active EmbeddingService so
    // memory searches immediately use the new provider.
    final embedding = memory.embeddingService;
    if (embedding != null) {
      embedding.updateConfig(
        provider: _embeddingProvider,
        baseUrl: _embeddingBaseUrlController.text.trim().isNotEmpty
            ? _embeddingBaseUrlController.text.trim()
            : config.embeddingBaseUrl,
        model: _embeddingModelController.text.trim().isNotEmpty
            ? _embeddingModelController.text.trim()
            : config.embeddingModel,
        apiKey: _embeddingApiKeyController.text.trim().isNotEmpty
            ? _embeddingApiKeyController.text.trim()
            : config.embeddingApiKey,
      );
    }

    if (mounted) _showSnack('Embedding-Konfiguration gespeichert ✅', context.buddy.success);
  }

  Future<void> _saveTtsConfig() async {
    final config = context.read<SecureConfigService>();
    final tts = context.read<TtsPlaybackService>();
    await config.setTtsEngine(_ttsEngine.name);
    tts.engine = _ttsEngine;
    await config.setPiperSpeed(tts.piperSpeed);

    // Persist cloud-TTS config and push it into the live service.
    await config.setTtsCloudProvider(_ttsCloudProvider);
    if (_openAiTtsKeyController.text.trim().isNotEmpty) {
      await config.setOpenAiTtsKey(_openAiTtsKeyController.text.trim());
    }
    await config.setOpenAiTtsVoice(_openAiTtsVoiceController.text.trim());
    await config.setElevenLabsKey(_elevenLabsKeyController.text.trim());
    await config.setElevenLabsVoice(_elevenLabsVoiceController.text.trim());
    tts.configureCloud(config);

    if (_ttsEngine == TtsEngine.device) {
      await tts.initDeviceTts();
    }
    if (mounted) _showSnack('Sprachausgabe gespeichert ✅', context.buddy.success);
  }

  Future<void> _testOllama() async {
    setState(() { _isTestingOllama = true; _ollamaTestResult = null; });
    try {
      final config = context.read<SecureConfigService>();
      final providerLabel = switch (_llmProvider) {
        'openrouter' => 'OpenRouter',
        'openai' => 'OpenAI',
        'anthropic' => 'Anthropic',
        'opencode-go' => 'OpenCode Go',
        _ => 'Ollama',
      };

      if (_llmProvider == 'anthropic') {
        // Anthropic has its own API format
        final key = _anthropicKeyController.text.trim().isNotEmpty
            ? _anthropicKeyController.text.trim()
            : config.anthropicApiKey;
        final model = _anthropicModelController.text.trim().isNotEmpty
            ? _anthropicModelController.text.trim()
            : config.anthropicModel;
        final svc = AnthropicService(
          baseUrl: config.anthropicBaseUrl,
          apiKey: key,
          defaultModel: model,
          fallbackModel: config.anthropicFallbackModel,
        );
        try {
          final reply = await svc.chat(
            systemPrompt: 'Du bist ein Test. Antworte kurz: OK',
            messages: [{'role': 'user', 'content': 'Hallo, Test!'}],
            temperature: 0.1,
          );
          final text = reply.length > 60 ? '${reply.substring(0, 60)}...' : reply;
          if (!mounted) return;
          setState(() => _ollamaTestResult = '$providerLabel OK — $text');
        } finally {
          svc.dispose();
        }
      } else {
        // ollama, openrouter, openai — all OpenAI-compatible via OllamaCloudService
        final baseUrl = switch (_llmProvider) {
          'openrouter' => config.openRouterBaseUrl,
          'openai' => config.openAIBaseUrl,
          'opencode-go' => config.openCodeGoBaseUrl,
          _ => config.ollamaBaseUrl,
        };
        final apiKey = switch (_llmProvider) {
          'openrouter' => (_openRouterKeyController.text.trim().isNotEmpty ? _openRouterKeyController.text.trim() : config.openRouterApiKey),
          'openai' => (_openAIKeyController.text.trim().isNotEmpty ? _openAIKeyController.text.trim() : config.openAIApiKey),
          'opencode-go' => (_openCodeGoKeyController.text.trim().isNotEmpty ? _openCodeGoKeyController.text.trim() : config.openCodeGoApiKey),
          _ => (_ollamaKeyController.text.trim().isNotEmpty ? _ollamaKeyController.text.trim() : config.ollamaApiKey),
        };
        final model = switch (_llmProvider) {
          'openrouter' => (_openRouterModelController.text.trim().isNotEmpty ? _openRouterModelController.text.trim() : config.openRouterModel),
          'openai' => (_openAIModelController.text.trim().isNotEmpty ? _openAIModelController.text.trim() : config.openAIModel),
          'opencode-go' => (_openCodeGoModelController.text.trim().isNotEmpty ? _openCodeGoModelController.text.trim() : config.openCodeGoModel),
          _ => (_ollamaModelController.text.trim().isNotEmpty ? _ollamaModelController.text.trim() : config.ollamaModel),
        };
        final fallback = switch (_llmProvider) {
          'openrouter' => (_openRouterFallbackController.text.trim().isNotEmpty ? _openRouterFallbackController.text.trim() : config.openRouterFallbackModel),
          'openai' => (_openAIFallbackController.text.trim().isNotEmpty ? _openAIFallbackController.text.trim() : config.openAIFallbackModel),
          'opencode-go' => (_openCodeGoFallbackController.text.trim().isNotEmpty ? _openCodeGoFallbackController.text.trim() : config.openCodeGoFallbackModel),
          _ => (_ollamaFallbackController.text.trim().isNotEmpty ? _ollamaFallbackController.text.trim() : config.ollamaFallbackModel),
        };
        final cloud = OllamaCloudService(
          baseUrl: baseUrl,
          apiKey: apiKey,
          defaultModel: model,
          fallbackModel: fallback,
        );
        try {
          final reply = await cloud.chat(
            systemPrompt: 'Du bist ein Test. Antworte kurz: OK',
            messages: [{'role': 'user', 'content': 'Hallo, Test!'}],
            temperature: 0.1,
          );
          final text = reply.length > 60 ? '${reply.substring(0, 60)}...' : reply;
          if (!mounted) return;
          setState(() => _ollamaTestResult = '$providerLabel OK — $text');
        } finally {
          cloud.dispose();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _ollamaTestResult = 'Fehler: ${_trunc(e.toString(), 120)}');
    } finally {
      if (mounted) setState(() => _isTestingOllama = false);
    }
  }

  Future<void> _testEmbedding() async {
    final t = AppLocalizations.of(context);
    setState(() { _isTestingEmbedding = true; _embeddingTestResult = null; });
    try {
      final config = context.read<SecureConfigService>();
      final embedding = EmbeddingService(
        baseUrl: _embeddingBaseUrlController.text.trim().isNotEmpty
            ? _embeddingBaseUrlController.text.trim()
            : config.embeddingBaseUrl,
        model: _embeddingModelController.text.trim().isNotEmpty
            ? _embeddingModelController.text.trim()
            : config.embeddingModel,
        apiKey: _embeddingApiKeyController.text.trim().isNotEmpty
            ? _embeddingApiKeyController.text.trim()
            : config.embeddingApiKey,
        provider: _embeddingProvider,
      );
      try {
        final result = await embedding.getEmbedding('Hallo Welt');
        if (!mounted) return;
        if (result != null) {
          setState(() => _embeddingTestResult =
              t.config_embedding_ok.replaceFirst('{dim}', '${result.length}'));
        } else {
          // Platzhalter füllen — sonst stünde wortwörtlich "Error: {msg}" da.
          setState(() => _embeddingTestResult =
              t.config_embedding_error.replaceFirst('{msg}', 'No embedding received'));
        }
      } finally {
        embedding.dispose();
      }
    } catch (e) {
      if (mounted) setState(() => _embeddingTestResult = 'Fehler: ${_trunc(e.toString(), 120)}');
    } finally {
      if (mounted) setState(() => _isTestingEmbedding = false);
    }
  }

  Future<void> _clearChatHistory() async {
    final t = AppLocalizations.of(context);
    final chatHistory = context.read<ChatHistoryService>();
    final confirmed = await _confirm(t.data_chat_delete_confirm,
        t.data_chat_delete_body);
    if (confirmed) {
      await chatHistory.clear();
      if (mounted) {
        _showSnack(t.data_chat_deleted, context.buddy.error);
      }
    }
  }

  Future<void> _clearMemories() async {
    final t = AppLocalizations.of(context);
    final memoryService = context.read<MemoryService>();
    final confirmed = await _confirm(t.data_memories_delete_confirm,
        t.data_memories_delete_body);
    if (confirmed) {
      await memoryService.clearAll();
      if (mounted) {
        _showSnack(t.data_memories_deleted, context.buddy.error);
      }
    }
  }

  Future<void> _createBackup() async {
    final backupService = context.read<BackupService>();
    try {
      final path = await backupService.exportBackup();
      // Share the backup file so user can save it externally
      await share_plus.Share.shareXFiles(
        [share_plus.XFile(path)],
        text: 'AI-Buddy Backup',
        subject: 'AI-Buddy Backup',
      );
      if (mounted) {
        _showSnack('Backup erstellt — speicher es sicher ab ✅', context.buddy.success);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Fehler: ${_trunc(e.toString(), 80)}', context.buddy.error);
      }
    }
  }

  Future<void> _restoreBackup() async {
    final t = AppLocalizations.of(context);
    final backupService = context.read<BackupService>();
    final confirmed = await _confirm('Backup wiederherstellen?',
        t.data_backup_overwrite_warning);
    if (!confirmed) {
      return;
    }
    try {
      final path = await backupService.importBackupWithPicker();
      if (path != null && mounted) {
        _showSnack('Backup eingespielt ✅', context.buddy.success);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Fehler: ${_trunc(e.toString(), 80)}', context.buddy.error);
      }
    }
  }

  Future<void> _resetApp() async {
    final t = AppLocalizations.of(context);
    final chatHistory = context.read<ChatHistoryService>();
    final memoryService = context.read<MemoryService>();
    final selfIdentity = context.read<SelfIdentityService>();
    final persona = context.read<PersonaService>();
    final personaEvolution = context.read<PersonaEvolutionService>();

    final confirmed = await _confirm(t.data_reset_confirm,
        t.data_reset_warning);
    if (!confirmed) {
      return;
    }
    try {
      await chatHistory.clear();
      await memoryService.clearAll();
      await selfIdentity.clear();
      await persona.clear();
      await personaEvolution.clear();
      if (mounted) {
        _showSnack(t.data_reset_done, context.buddy.error);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Fehler: ${_trunc(e.toString(), 80)}', context.buddy.error);
      }
    }
  }

  void _showSnack(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Flexible(child: Text(msg, maxLines: 2)),
      ]),
      backgroundColor: c.withValues(alpha: 0.9),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<bool> _confirm(String title, String body) async {
    final t = AppLocalizations.of(context);
    return (await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.buddy.elev,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.buddy.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.warning_rounded, color: context.buddy.error, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title,
              style: TextStyle(color: context.buddy.t1, fontSize: 18, fontWeight: FontWeight.w700))),
          ]),
          content: Text(body,
            style: TextStyle(color: context.buddy.t2, fontSize: 14, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.common_cancel, style: TextStyle(
                color: context.buddy.t2, fontWeight: FontWeight.w600))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.buddy.error.withValues(alpha: 0.2),
                foregroundColor: context.buddy.error,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(t.common_confirm, style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      )) == true;
  }

  static String _trunc(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}...' : s;

  void _showKIEntwicklung() {
    final t = AppLocalizations.of(context);
    final traits = context.read<PersonaEvolutionService>().learnedTraits;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.buddy.elev.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: context.buddy.border),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          builder: (_, scrollCtrl) => Column(children: [
            Container(
              width: 40, height: 5,
              decoration: BoxDecoration(
                color: context.buddy.t3.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.buddy.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('KI-Entwicklung',
                  style: TextStyle(color: context.buddy.t1, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${traits.length} ${t.buddy_evolution_traits}',
                  style: TextStyle(color: context.buddy.t2, fontSize: 13)),
              ])),
            ]),
            const SizedBox(height: 20),
            Expanded(
              child: traits.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.psychology_alt_outlined,
                      size: 48, color: context.buddy.t3.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    Text(t.buddy_evolution_empty,
                      style: TextStyle(color: context.buddy.t2, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(t.buddy_evolution_desc,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.buddy.t3, fontSize: 13, height: 1.5)),
                  ]))
                : ListView.builder(
                    controller: scrollCtrl,
                    physics: const BouncingScrollPhysics(),
                    itemCount: traits.length,
                    itemBuilder: (_, i) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: context.buddy.card.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.buddy.border),
                      ),
                      child: Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: context.buddy.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: Text((i + 1).toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Text(traits[i],
                          style: TextStyle(color: context.buddy.t1, fontSize: 15))),
                        Icon(Icons.check_rounded, size: 18, color: context.buddy.success),
                      ]),
                    ),
                  ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final persona = context.watch<PersonaService>();
    final evolution = context.watch<PersonaEvolutionService>();

    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: context.buddy.bg,
        systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        systemNavigationBarDividerColor: context.buddy.bg,
      ),
      sized: true,
      child: Scaffold(
      backgroundColor: context.buddy.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header (SafeArea-aware) ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 16, 20, 8),
              child: Row(
                children: [
                  Text(t.settings_title,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                      color: context.buddy.t1, letterSpacing: -0.5)),
                ],
              ),
            ),
          ),

          // ── Erscheinungsbild ──
          SliverToBoxAdapter(child: SectionHeader(t.settings_tab_appearance,
            icon: Icons.palette_rounded,
            expanded: _secAppearance,
            onTap: () => setState(() => _secAppearance = !_secAppearance),
          )),
          if (_secAppearance) const SliverToBoxAdapter(child: AppearanceSection()),

          // ── Buddy ──
          SliverToBoxAdapter(child: SectionHeader(t.settings_tab_buddy,
            icon: Icons.smart_toy_rounded,
            expanded: _secBuddy,
            onTap: () => setState(() => _secBuddy = !_secBuddy),
          )),
          if (_secBuddy) SliverToBoxAdapter(child: Column(children: [
            SettingsButton(nested: true,
              icon: Icons.face_5_rounded,
              title: t.buddy_persona_edit,
              subtitle: persona.name.isEmpty ? 'Standard' : persona.name,
              color: context.buddy.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PersonaEditorScreen()),
              ),
            ),
            SettingsButton(nested: true,
              icon: Icons.self_improvement_rounded,
              title: t.buddy_self_identity,
              subtitle: t.buddy_persona_desc,
              color: context.buddy.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SelfIdentityScreen()),
              ),
            ),
            SettingsButton(nested: true,
              icon: Icons.psychology_rounded,
              title: t.buddy_evolution,
              subtitle: '${evolution.learnedTraits.length} ${t.buddy_evolution_traits}',
              color: context.buddy.accent,
              trailing: SettingsBadge('${evolution.learnedTraits.length}'),
              onTap: _showKIEntwicklung,
            ),
            SettingsButton(nested: true,
              icon: Icons.memory_rounded,
              title: t.buddy_memories,
              subtitle: t.memory_core_long_short,
              color: context.buddy.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MemoryBrowserScreen()),
              ),
            ),
            ProactivityTile(),
          ])),

          // ── Werkzeuge ──
          SliverToBoxAdapter(child: SectionHeader(t.settings_tab_tools,
            icon: Icons.build_rounded,
            expanded: _secTools,
            onTap: () => setState(() => _secTools = !_secTools),
          )),
          if (_secTools) SliverToBoxAdapter(child: Column(children: [
            SettingsButton(nested: true,
              icon: Icons.accessibility_new_rounded,
              title: 'App-Steuerung & WhatsApp senden',
              subtitle: 'Einmalig Android-Bedienungshilfe aktivieren',
              color: context.buddy.accent,
              onTap: () async {
                final successColor = context.buddy.success;
                final errorColor = context.buddy.error;
                final result = await ControlScreenTool().execute(
                  {'action': 'enable'},
                );
                if (mounted) {
                  _showSnack(
                    result.isError ? result.result : 'Android-Einstellung geöffnet',
                    result.isError ? errorColor : successColor,
                  );
                }
              },
            ),
            SettingsButton(nested: true,
              icon: Icons.map_rounded,
              title: t.buddy_offline_maps,
              subtitle: t.buddy_offline_maps_desc,
              color: context.buddy.accent,
              trailing: FutureBuilder<bool>(
                future: _offlineTilesFuture,
                builder: (_, snap) => snap.hasData && snap.data == true
                  ? Icon(Icons.check_circle, color: context.buddy.success, size: 22)
                  : Icon(Icons.download_for_offline, color: context.buddy.t3, size: 22),
              ),
              onTap: () async {
                await showDialog(context: context, builder: (_) => const OfflineMapDialog());
                // Refresh the cached status so a fresh download shows its check.
                if (mounted) {
                  setState(() => _offlineTilesFuture = TileDownloadService.hasOfflineTiles());
                }
              },
            ),
            SettingsButton(nested: true,
              icon: Icons.notes_rounded,
              title: t.buddy_notes,
              subtitle: t.tools_desc,
              color: context.buddy.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuddyNotesScreen()),
              ),
            ),
            SettingsButton(nested: true,
              icon: Icons.auto_fix_high_rounded,
              title: t.buddy_capabilities,
              subtitle: t.buddy_capabilities_desc,
              color: context.buddy.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuddyCapabilitiesScreen()),
              ),
            ),
          ])),

          // ── Konfiguration ──
          SliverToBoxAdapter(child: SectionHeader(t.settings_tab_config,
            icon: Icons.tune_rounded,
            expanded: _secConfig,
            onTap: () => setState(() => _secConfig = !_secConfig),
          )),
          if (_secConfig) ...[

          // ── Buddy-Name ──
          SliverToBoxAdapter(child: ExpandableSection(
            title: t.buddy_name,
            icon: Icons.person_rounded,
            color: context.buddy.accent,
            expanded: _buddyNameExpanded,
            onToggle: () => setState(() => _buddyNameExpanded = !_buddyNameExpanded),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: GlassTextField(
                  label: t.buddy_name_hint,
                  icon: Icons.edit_rounded,
                  controller: _buddyNameController,
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: GradientButton(
                  icon: Icons.save_rounded,
                  label: t.common_save,
                  onTap: _saveBuddyName,
                )),
              ]),
            ],
          )),

          // ── E-Mail (IMAP) ──
          SliverToBoxAdapter(child: ExpandableSection(
            title: t.config_email,
            icon: Icons.email_rounded,
            color: context.buddy.accent,
            expanded: _emailExpanded,
            onToggle: () => setState(() => _emailExpanded = !_emailExpanded),
            children: [
              GlassTextField(
                label: t.config_email_address,
                icon: Icons.email_rounded,
                controller: _emailAddressController,
              ),
              GlassTextField(
                label: t.config_email_password,
                icon: Icons.lock_rounded,
                controller: _emailPasswordController,
                obscure: true,
              ),
              GlassTextField(
                label: t.config_email_server,
                icon: Icons.dns_rounded,
                controller: _imapServerController,
              ),
              GlassTextField(
                label: t.config_email_port,
                icon: Icons.pin_rounded,
                controller: _imapPortController,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: GradientButton(
                  icon: Icons.save_rounded,
                  label: t.common_save,
                  onTap: _saveEmailConfig,
                )),
              ]),
            ],
          )),

          // ── Embedding (Memory-Suche) ──
          SliverToBoxAdapter(child: ExpandableSection(
            title: t.config_embedding,
            icon: Icons.memory_rounded,
            color: context.buddy.accent,
            expanded: _embeddingExpanded,
            onToggle: () => setState(() => _embeddingExpanded = !_embeddingExpanded),
            children: [
              // Provider Switch — 3 tabs
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.buddy.card.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.buddy.border),
                ),
                child: Row(
                  children: [
                    _embeddingTab('Ollama', 'ollama'),
                    _embeddingTab('OpenRouter', 'openrouter'),
                    _embeddingTab('OpenAI', 'openai'),
                  ],
                ),
              ),
              GlassTextField(
                label: _embeddingProvider == 'ollama'
                    ? t.config_base_url_ollama
                    : _embeddingProvider == 'openrouter'
                        ? t.config_base_url_openrouter
                        : t.config_base_url_openai,
                icon: Icons.link_rounded,
                controller: _embeddingBaseUrlController,
              ),
              GlassTextField(
                label: t.config_api_key,
                icon: Icons.key_rounded,
                controller: _embeddingApiKeyController,
                obscure: true,
              ),
              GlassTextField(
                label: _embeddingProvider == 'ollama'
                    ? t.config_embedding_model_ollama
                    : _embeddingProvider == 'openrouter'
                        ? t.config_embedding_model_openrouter
                        : t.config_embedding_model_openai,
                icon: Icons.memory_rounded,
                controller: _embeddingModelController,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: GradientButton(
                  icon: Icons.save_rounded,
                  label: t.common_save,
                  onTap: _saveEmbeddingConfig,
                )),
                const SizedBox(width: 8),
                Expanded(child: OutlineButton(
                  icon: _isTestingEmbedding ? Icons.hourglass_empty_rounded : Icons.check_circle_rounded,
                  label: _isTestingEmbedding ? t.config_embedding_testing : t.common_test,
                  onTap: _isTestingEmbedding ? null : _testEmbedding,
                )),
              ]),
              if (_embeddingTestResult != null)
                ResultBox(text: _embeddingTestResult!),
            ],
          )),

          // ── KI-Modell ──
          SliverToBoxAdapter(child: ExpandableSection(
            title: t.config_provider,
            icon: Icons.auto_awesome_rounded,
            color: context.buddy.accent,
            expanded: _ollamaExpanded,
            onToggle: () => setState(() => _ollamaExpanded = !_ollamaExpanded),
            children: [
              // Provider Switch — 4 tabs (2x2 grid)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.buddy.card.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.buddy.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _providerTab('Ollama', 'ollama'),
                        _providerTab('OpenRouter', 'openrouter'),
                      ],
                    ),
                    Row(
                      children: [
                        _providerTab('OpenAI', 'openai'),
                        _providerTab('Anthropic', 'anthropic'),
                      ],
                    ),
                    Row(
                      children: [
                        _providerTab('OpenCode Go', 'opencode-go'),
                        const Spacer(),
                      ],
                    ),
                  ],
                ),
              ),

              if (_llmProvider == 'ollama') ...[
                GlassTextField(
                  label: t.config_base_url,
                  icon: Icons.link_rounded,
                  controller: _ollamaBaseUrlController,
                ),
                GlassTextField(
                  label: t.config_api_key,
                  icon: Icons.key_rounded,
                  controller: _ollamaKeyController,
                  obscure: true,
                ),
                _buildModelDropdown(
                  label: t.config_model,
                  icon: Icons.smart_toy_rounded,
                  models: _ollamaModels,
                  controller: _ollamaModelController,
                ),
                GlassTextField(
                  label: t.config_fallback,
                  icon: Icons.backup_rounded,
                  controller: _ollamaFallbackController,
                ),
              ] else if (_llmProvider == 'openrouter') ...[
                GlassTextField(
                  label: t.config_openrouter_api_key,
                  icon: Icons.key_rounded,
                  controller: _openRouterKeyController,
                  obscure: true,
                ),
                _buildModelDropdown(
                  label: t.config_model,
                  icon: Icons.smart_toy_rounded,
                  models: _openRouterModels,
                  controller: _openRouterModelController,
                ),
                GlassTextField(
                  label: t.config_fallback,
                  icon: Icons.backup_rounded,
                  controller: _openRouterFallbackController,
                ),
              ] else if (_llmProvider == 'openai') ...[
                GlassTextField(
                  label: t.config_api_key,
                  icon: Icons.key_rounded,
                  controller: _openAIKeyController,
                  obscure: true,
                ),
                _buildModelDropdown(
                  label: t.config_model,
                  icon: Icons.smart_toy_rounded,
                  models: _openAIModels,
                  controller: _openAIModelController,
                ),
                GlassTextField(
                  label: t.config_fallback,
                  icon: Icons.backup_rounded,
                  controller: _openAIFallbackController,
                ),
              ] else if (_llmProvider == 'anthropic') ...[
                GlassTextField(
                  label: t.config_api_key,
                  icon: Icons.key_rounded,
                  controller: _anthropicKeyController,
                  obscure: true,
                ),
                _buildModelDropdown(
                  label: t.config_model,
                  icon: Icons.smart_toy_rounded,
                  models: _anthropicModels,
                  controller: _anthropicModelController,
                ),
                GlassTextField(
                  label: t.config_fallback,
                  icon: Icons.backup_rounded,
                  controller: _anthropicFallbackController,
                ),
              ] else if (_llmProvider == 'opencode-go') ...[
                GlassTextField(
                  label: t.config_api_key,
                  icon: Icons.key_rounded,
                  controller: _openCodeGoKeyController,
                  obscure: true,
                ),
                _buildModelDropdown(
                  label: t.config_model,
                  icon: Icons.smart_toy_rounded,
                  models: _openCodeGoModels,
                  controller: _openCodeGoModelController,
                ),
                GlassTextField(
                  label: t.config_fallback,
                  icon: Icons.backup_rounded,
                  controller: _openCodeGoFallbackController,
                ),
              ],

              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: GradientButton(
                  icon: Icons.save_rounded,
                  label: t.common_save,
                  onTap: _saveOllamaConfig,
                )),
                const SizedBox(width: 8),
                Expanded(child: OutlineButton(
                  icon: _isTestingOllama ? Icons.hourglass_empty_rounded : Icons.check_circle_rounded,
                  label: _isTestingOllama ? t.config_embedding_testing : t.common_test,
                  onTap: _isTestingOllama ? null : _testOllama,
                )),
              ]),
              if (_ollamaTestResult != null)
                ResultBox(text: _ollamaTestResult!),
            ],
          )),

          // ── Sprache ──
          SliverToBoxAdapter(child: ExpandableSection(
            title: t.config_tts,
            icon: Icons.record_voice_over_rounded,
            color: context.buddy.accent,
            expanded: _elevenExpanded,
            onToggle: () => setState(() => _elevenExpanded = !_elevenExpanded),
            children: [
              // TTS Engine Selector — chips wrap so three engines never
              // overflow the row on narrow screens.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.config_tts_engine, style: TextStyle(color: context.buddy.t2, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...TtsEngine.values.map((e) => GestureDetector(
                        onTap: () => setState(() => _ttsEngine = e),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _ttsEngine == e ? context.buddy.accent : context.buddy.card.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _ttsEngine == e ? Colors.transparent : context.buddy.border,
                            ),
                          ),
                          child: Text(e.label, style: TextStyle(
                            fontSize: 13,
                            fontWeight: _ttsEngine == e ? FontWeight.w700 : FontWeight.w500,
                            color: _ttsEngine == e ? Colors.white : context.buddy.t2,
                          )),
                        ),
                      )),
                    ],
                    ),
                  ],
                ),
              ),
              SettingsDivider(),

              // Piper voice management (shown when Piper selected)
              if (_ttsEngine == TtsEngine.piper) ...[
                Builder(builder: (context) {
                  final piper = context.watch<PiperTtsService>();
                  return Column(children: [
                    // Voice download selection — grouped by language
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Align(alignment: Alignment.centerLeft,
                        child: Text(t.config_piper_voices, style: TextStyle(color: context.buddy.t2, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    // Language dropdown
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Text(t.config_piper_language, style: TextStyle(color: context.buddy.t2, fontSize: 13)),
                          Expanded(
                            child: DropdownButton<String>(
                              value: _piperLangFilter,
                              isExpanded: true,
                              underline: Container(height: 1, color: context.buddy.border),
                              items: [
                                DropdownMenuItem(value: 'all', child: Text(t.config_piper_all_languages)),
                                ...PiperVoice.supportedLanguages.map((code) =>
                                  DropdownMenuItem(value: code, child: Text(PiperVoice.languageNameFor(code)))),
                              ],
                              onChanged: (v) => setState(() => _piperLangFilter = v ?? 'all'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._filteredPiperVoices.map((voice) => PiperVoiceTile(
                      voice: voice,
                      piper: piper,
                      isCurrent: piper.currentVoice == voice,
                      onLoad: () async {
                        // Capture context-dependent services BEFORE await
                        final config = context.read<SecureConfigService>();
                        final tts = context.read<TtsPlaybackService>();
                        await piper.loadVoice(voice);
                        await config.setPiperVoice(voice.id);
                        tts.engine = TtsEngine.piper;
                        if (mounted) setState(() {});
                      },
                      onDelete: () async {
                        await piper.deleteVoice(voice);
                        if (mounted) setState(() {});
                      },
                      onDownload: () async {
                        await piper.downloadVoice(voice, onProgress: (p) {
                          if (mounted) setState(() {});
                        });
                        if (mounted) setState(() {});
                      },
                    )),
                    const SizedBox(height: 8),
                    // ── Piper Speed Slider ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(t.config_tts_speed, style: TextStyle(color: context.buddy.t2, fontSize: 13, fontWeight: FontWeight.w600)),
                              Builder(builder: (context) {
                                final tts = context.select<TtsPlaybackService, double>((s) => s.piperSpeed);
                                return Text('${tts.toStringAsFixed(1)}x', style: TextStyle(color: context.buddy.accent, fontSize: 13, fontWeight: FontWeight.w600));
                              }),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Builder(builder: (context) {
                            final speed = context.select<TtsPlaybackService, double>((s) => s.piperSpeed);
                            return SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: context.buddy.accent,
                                inactiveTrackColor: context.buddy.t3.withValues(alpha: 0.3),
                                thumbColor: context.buddy.accent,
                                overlayColor: context.buddy.accent.withValues(alpha: 0.2),
                                trackHeight: 3,
                              ),
                              child: Slider(
                                value: speed,
                                min: 0.1,
                                max: 1.5,
                                divisions: 14,
                                onChanged: (value) {
                                  context.read<TtsPlaybackService>().piperSpeed = value;
                                },
                                onChangeEnd: (value) {
                                  final config = context.read<SecureConfigService>();
                                  config.setPiperSpeed(value);
                                },
                              ),
                            );
                          }),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(t.speed_slow, style: TextStyle(color: context.buddy.t3, fontSize: 11)),
                              Text(t.speed_fast, style: TextStyle(color: context.buddy.t3, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: GradientButton(
                        icon: Icons.save_rounded,
                        label: t.common_save,
                        onTap: _saveTtsConfig,
                      )),
                    ]),
                  ]);
                }),
              ],

              // Cloud TTS (shown when cloud selected)
              if (_ttsEngine == TtsEngine.cloud) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.buddy.card.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.buddy.border),
                  ),
                  child: Row(children: [
                    _cloudTtsTab('OpenAI', 'openai'),
                    _cloudTtsTab('ElevenLabs', 'elevenlabs'),
                  ]),
                ),
                if (_ttsCloudProvider == 'openai') ...[
                  GlassTextField(
                    label: 'OpenAI API-Key (leer = LLM-Key)',
                    icon: Icons.key_rounded,
                    controller: _openAiTtsKeyController,
                    obscure: true,
                  ),
                  GlassTextField(
                    label: 'Stimme (alloy, nova, shimmer, echo, fable, onyx)',
                    icon: Icons.record_voice_over_rounded,
                    controller: _openAiTtsVoiceController,
                  ),
                ] else ...[
                  GlassTextField(
                    label: 'ElevenLabs API-Key',
                    icon: Icons.key_rounded,
                    controller: _elevenLabsKeyController,
                    obscure: true,
                  ),
                  GlassTextField(
                    label: 'Voice ID',
                    icon: Icons.record_voice_over_rounded,
                    controller: _elevenLabsVoiceController,
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Cloud-Stimmen klingen natürlicher und starten schneller als Piper. '
                    'Der Antworttext wird an den Anbieter gesendet (kostenpflichtig, braucht Internet).',
                    style: TextStyle(color: context.buddy.t3, fontSize: 12, height: 1.4)),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: GradientButton(
                    icon: Icons.save_rounded,
                    label: t.common_save,
                    onTap: _saveTtsConfig,
                  )),
                ]),
              ],

              // Device TTS (shown when device selected)
              if (_ttsEngine == TtsEngine.device) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(t.config_tts_device_desc,
                    style: TextStyle(color: context.buddy.t2, fontSize: 13, height: 1.5)),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: GradientButton(
                    icon: Icons.save_rounded,
                    label: t.common_save,
                    onTap: _saveTtsConfig,
                  )),
                ]),
              ],
            ],
          )),

          ],


          // ── Daten ──
          SliverToBoxAdapter(child: SectionHeader(t.settings_tab_data,
            icon: Icons.folder_rounded,
            expanded: _secData,
            onTap: () => setState(() => _secData = !_secData),
          )),
          if (_secData) ...[
          SliverToBoxAdapter(child: Column(children: [
            SettingsButton(nested: true,
              icon: Icons.backup_outlined,
              title: t.data_backup_create,
              color: context.buddy.success,
              onTap: _createBackup,
            ),
            SettingsButton(nested: true,
              icon: Icons.restore_outlined,
              title: t.common_restore,
              color: context.buddy.accent,
              onTap: _restoreBackup,
            ),
            SettingsButton(nested: true,
              icon: Icons.delete_forever_outlined,
              title: t.data_chat_delete,
              color: context.buddy.error,
              onTap: _clearChatHistory,
            ),
            SettingsButton(nested: true,
              icon: Icons.memory_outlined,
              title: t.data_memories_delete,
              color: context.buddy.error,
              onTap: _clearMemories,
            ),
            SettingsButton(nested: true,
              icon: Icons.restart_alt_rounded,
              title: t.data_reset,
              subtitle: t.data_reset_desc,
              color: context.buddy.error,
              onTap: _resetApp,
            ),
          ])),
          ],

          // ── Hintergrund-Tasks ──
          SliverToBoxAdapter(child: SectionHeader(t.bg_tasks_title,
            icon: Icons.schedule_rounded,
            expanded: _secScheduler,
            onTap: () => setState(() => _secScheduler = !_secScheduler),
          )),
          if (_secScheduler) SliverToBoxAdapter(child: SchedulerSection()),

          // ── Über ──
          SliverToBoxAdapter(child: SectionHeader(t.about_title,
            icon: Icons.info_rounded,
            expanded: _secAbout,
            onTap: () => setState(() => _secAbout = !_secAbout),
          )),
          if (_secAbout) SliverToBoxAdapter(
            child: FutureBuilder<PackageInfo>(
              future: _packageInfoFuture,
              builder: (context, snap) => SettingsButton(nested: true,
                icon: Icons.favorite_rounded,
                title: 'AI-Buddy',
                // Echte Laufzeit-Version aus dem Build — die Konstante in
                // version.dart driftet, weil sie manuell gepflegt wird.
                subtitle: snap.hasData
                    ? 'Version ${snap.data!.version}+${snap.data!.buildNumber}'
                    : 'Version $appVersion',
                color: context.buddy.accent,
                trailing: const SizedBox.shrink(),
                onTap: () {},
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
          // Bottom SafeArea padding
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
          ),
        ],
      ),
      ),
    );
  }

  /// Filtered Piper voices based on language selection.
  List<PiperVoice> get _filteredPiperVoices {
    if (_piperLangFilter == 'all') return PiperVoice.values;
    return PiperVoice.forLanguage(_piperLangFilter);
  }

  /// Provider tab button for the 4-provider switch grid.
  Widget _providerTab(String label, String id) {
    final selected = _llmProvider == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _llmProvider = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? context.buddy.accent : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              color: selected ? Colors.white : context.buddy.t2,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  /// Cloud-TTS provider tab (OpenAI / ElevenLabs).
  Widget _cloudTtsTab(String label, String id) {
    final selected = _ttsCloudProvider == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _ttsCloudProvider = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? context.buddy.accent : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              color: selected ? Colors.white : context.buddy.t2,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  /// Embedding provider tab button for the 3-provider switch.
  Widget _embeddingTab(String label, String id) {
    final selected = _embeddingProvider == id;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _embeddingProvider = id;
            // Auto-fill default base URL when switching provider
            final defaults = {
              'ollama': 'https://ollama.com/api',
              'openrouter': 'https://openrouter.ai/api/v1',
              'openai': 'https://api.openai.com',
            };
            final current = _embeddingBaseUrlController.text.trim();
            final isDefault = ['https://ollama.com/api', 'https://openrouter.ai/api/v1', 'https://openrouter.ai/api', 'https://api.openai.com', ''].contains(current);
            if (isDefault) {
              _embeddingBaseUrlController.text = defaults[id] ?? '';
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? context.buddy.accent : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              color: selected ? Colors.white : context.buddy.t2,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass-styled model dropdown for cloud provider presets.
Widget _buildModelDropdown({
  required String label,
  required IconData icon,
  required List<Map<String, String>> models,
  required TextEditingController controller,
}) {
  return ModelDropdown(
    label: label,
    icon: icon,
    models: models,
    controller: controller,
    onCustomModelTap: _showCustomModelDialog,
  );
}

Future<String?> _showCustomModelDialog(BuildContext context, String current) async {
    final t = AppLocalizations.of(context);
    final controller = TextEditingController(text: current);
    try {
      return await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.buddy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.config_model_id, style: TextStyle(color: context.buddy.t1, fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: context.buddy.t1, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'z.B. kimi-k2.6:cloud',
            hintStyle: TextStyle(color: context.buddy.t3),
            filled: true,
            fillColor: context.buddy.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.buddy.accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(t.common_cancel, style: TextStyle(color: context.buddy.t2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(t.common_save, style: TextStyle(color: context.buddy.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      );
    } finally {
      controller.dispose();
    }
  }
