import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/buddy_colors.dart';
import '../services/settings_service.dart';
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
import '../services/buddy_scheduler.dart';
import '../tools/tool_registry.dart';
import '../tools/read_email_tool.dart';

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

  bool _isTestingOllama = false;
  String? _ollamaTestResult;
  bool _isTestingEmbedding = false;
  String? _embeddingTestResult;

  bool _ollamaExpanded = true;
  bool _elevenExpanded = true;
  bool _buddyNameExpanded = true;
  bool _emailExpanded = false;
  bool _secEmbedding = false;
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
  static const List<Map<String, String>> _ollamaModels = [
    {'id': 'kimi-k2.6:cloud', 'name': 'Kimi K2.6 (Kontext: 262k)'},
    {'id': 'deepseek-chat-v4:cloud', 'name': 'DeepSeek Chat V4 (Kontext: 128k)'},
    {'id': 'deepseek-v4-flash:cloud', 'name': 'DeepSeek Flash V4 (Schnell)'},
  ];
  static const List<Map<String, String>> _openRouterModels = [
    {'id': 'openrouter/moonshotai/kimi-k2.6', 'name': 'Kimi K2.6 (262k Kontext)'},
    {'id': 'openrouter/deepseek/deepseek-chat-v4', 'name': 'DeepSeek V4 Pro (128k)'},
    {'id': 'anthropic/claude-3.5-sonnet', 'name': 'Claude 3.5 Sonnet (ausgewogen)'},
    {'id': 'google/gemini-2.0-flash-001', 'name': 'Gemini 2.0 Flash (schnell)'},
  ];
  static const List<Map<String, String>> _openAIModels = [
    {'id': 'gpt-4o', 'name': 'GPT-4o (ausgewogen)'},
    {'id': 'gpt-4o-mini', 'name': 'GPT-4o mini (schnell)'},
    {'id': 'gpt-4.1', 'name': 'GPT-4.1 (kreativ)'},
    {'id': 'o4-mini', 'name': 'o4-mini (reasoning)'},
  ];
  static const List<Map<String, String>> _anthropicModels = [
    {'id': 'claude-sonnet-4-20250514', 'name': 'Claude Sonnet 4 (ausgewogen)'},
    {'id': 'claude-opus-4-20250514', 'name': 'Claude Opus 4 (stärkster)'},
    {'id': 'claude-3-5-haiku-20241022', 'name': 'Claude 3.5 Haiku (schnell)'},
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
    _buddyNameController.text = config.buddyName;
    _emailAddressController.text = config.emailAddress;
    _emailPasswordController.text = config.emailPassword;
    _imapServerController.text = config.imapServer;
    _imapPortController.text = config.imapPort.toString();
    _embeddingBaseUrlController.text = config.embeddingBaseUrl;
    _embeddingApiKeyController.text = config.embeddingApiKey;
    _embeddingModelController.text = config.embeddingModel;
    _embeddingProvider = config.embeddingProvider;
    _llmProvider = config.llmProvider;
    _ttsEngine = switch (config.ttsEngine) {
      'device' => TtsEngine.device,
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
    _buddyNameController.dispose();
    _emailAddressController.dispose();
    _emailPasswordController.dispose();
    _imapServerController.dispose();
    _imapPortController.dispose();
    _embeddingBaseUrlController.dispose();
    _embeddingApiKeyController.dispose();
    _embeddingModelController.dispose();
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

    final providerLabel = switch (_llmProvider) {
      'openrouter' => 'OpenRouter',
      'openai' => 'OpenAI',
      'anthropic' => 'Anthropic',
      _ => 'Ollama',
    };
    if (mounted) _showSnack('$providerLabel gespeichert ✅', context.buddy.success);
  }

  Future<void> _saveEmbeddingConfig() async {
    final config = context.read<SecureConfigService>();
    await config.setEmbeddingProvider(_embeddingProvider);
    await config.setEmbeddingBaseUrl(_embeddingBaseUrlController.text.trim());
    await config.setEmbeddingApiKey(_embeddingApiKeyController.text.trim());
    await config.setEmbeddingModel(_embeddingModelController.text.trim());
    if (mounted) _showSnack('Embedding-Konfiguration gespeichert ✅', context.buddy.success);
  }

  Future<void> _saveTtsConfig() async {
    final config = context.read<SecureConfigService>();
    final tts = context.read<TtsPlaybackService>();
    await config.setTtsEngine(_ttsEngine.name);
    tts.engine = _ttsEngine;
    await config.setPiperSpeed(tts.piperSpeed);
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
          _ => config.ollamaBaseUrl,
        };
        final apiKey = switch (_llmProvider) {
          'openrouter' => (_openRouterKeyController.text.trim().isNotEmpty ? _openRouterKeyController.text.trim() : config.openRouterApiKey),
          'openai' => (_openAIKeyController.text.trim().isNotEmpty ? _openAIKeyController.text.trim() : config.openAIApiKey),
          _ => (_ollamaKeyController.text.trim().isNotEmpty ? _ollamaKeyController.text.trim() : config.ollamaApiKey),
        };
        final model = switch (_llmProvider) {
          'openrouter' => (_openRouterModelController.text.trim().isNotEmpty ? _openRouterModelController.text.trim() : config.openRouterModel),
          'openai' => (_openAIModelController.text.trim().isNotEmpty ? _openAIModelController.text.trim() : config.openAIModel),
          _ => (_ollamaModelController.text.trim().isNotEmpty ? _ollamaModelController.text.trim() : config.ollamaModel),
        };
        final fallback = switch (_llmProvider) {
          'openrouter' => (_openRouterFallbackController.text.trim().isNotEmpty ? _openRouterFallbackController.text.trim() : config.openRouterFallbackModel),
          'openai' => (_openAIFallbackController.text.trim().isNotEmpty ? _openAIFallbackController.text.trim() : config.openAIFallbackModel),
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
          setState(() => _embeddingTestResult = 'Embedding OK — Vektor: ${result.length} Dimensionen');
        } else {
          setState(() => _embeddingTestResult = 'Fehler: Kein Embedding erhalten');
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
    final chatHistory = context.read<ChatHistoryService>();
    final confirmed = await _confirm('Chat-Verlauf löschen?',
        'Alle Nachrichten werden unwiderruflich gelöscht.');
    if (confirmed) {
      await chatHistory.clear();
      if (mounted) {
        _showSnack('Chat-Verlauf gelöscht', context.buddy.error);
      }
    }
  }

  Future<void> _clearMemories() async {
    final memoryService = context.read<MemoryService>();
    final confirmed = await _confirm('Erinnerungen löschen?',
        'Alle gespeicherten Erinnerungen werden gelöscht.');
    if (confirmed) {
      await memoryService.clearAll();
      if (mounted) {
        _showSnack('Erinnerungen gelöscht', context.buddy.error);
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
    final backupService = context.read<BackupService>();
    final confirmed = await _confirm('Backup wiederherstellen?',
        'Aktuelle Daten werden überschrieben.');
    if (!confirmed) {
      return;
    }
    try {
      final path = await backupService.importBackupWithPicker();
      if (path != null) {
        await backupService.importBackup(path);
        if (mounted) {
          _showSnack('Backup eingespielt ✅', context.buddy.success);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Fehler: ${_trunc(e.toString(), 80)}', context.buddy.error);
      }
    }
  }

  Future<void> _resetApp() async {
    final chatHistory = context.read<ChatHistoryService>();
    final memoryService = context.read<MemoryService>();
    final selfIdentity = context.read<SelfIdentityService>();
    final persona = context.read<PersonaService>();
    final personaEvolution = context.read<PersonaEvolutionService>();

    final confirmed = await _confirm('App komplett zurücksetzen?',
        'Alles wird gelöscht: Chat, Erinnerungen, Selbstbild, Persona, KI-Entwicklung. Das kann nicht rückgängig gemacht werden.');
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
        _showSnack('App zurückgesetzt — neu starten empfohlen', context.buddy.error);
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

  Future<bool> _confirm(String title, String body) async =>
      (await showDialog<bool>(
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
              child: Text('Abbrechen', style: TextStyle(
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
              child: const Text('Bestätigen', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      )) == true;

  static String _trunc(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}...' : s;

  void _showKIEntwicklung() {
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
                Text('${traits.length} gelernte Merkmale',
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
                    Text('Noch keine Merkmale gelernt',
                      style: TextStyle(color: context.buddy.t2, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('Dein Agent lernt mit jedem Gespräch mehr über dich.',
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
    final persona = context.watch<PersonaService>();
    final evolution = context.watch<PersonaEvolutionService>();

    return Scaffold(
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
                  Text('Einstellungen',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                      color: context.buddy.t1, letterSpacing: -0.5)),
                ],
              ),
            ),
          ),

          // ── Erscheinungsbild ──
          SliverToBoxAdapter(child: _SectionHeader('Erscheinungsbild',
            expanded: _secAppearance,
            onTap: () => setState(() => _secAppearance = !_secAppearance),
          )),
          if (_secAppearance) const SliverToBoxAdapter(child: _AppearanceSection()),

          // ── Buddy ──
          SliverToBoxAdapter(child: _SectionHeader('Buddy',
            expanded: _secBuddy,
            onTap: () => setState(() => _secBuddy = !_secBuddy),
          )),
          if (_secBuddy) SliverToBoxAdapter(child: _GlassCard(children: [
            _ListTile(
              icon: Icons.face_5_rounded,
              title: 'Persona bearbeiten',
              subtitle: persona.name.isEmpty ? 'Standard' : persona.name,
              color: context.buddy.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PersonaEditorScreen()),
              ),
            ),
            _Divider(),
            _ListTile(
              icon: Icons.self_improvement_rounded,
              title: 'Mein Selbst',
              subtitle: 'Wesen, Regeln, Ziele',
              color: context.buddy.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SelfIdentityScreen()),
              ),
            ),
            _Divider(),
            _ListTile(
              icon: Icons.psychology_rounded,
              title: 'KI-Entwicklung',
              subtitle: '${evolution.learnedTraits.length} Merkmale gelernt',
              color: context.buddy.accent,
              trailing: _Badge('${evolution.learnedTraits.length}'),
              onTap: _showKIEntwicklung,
            ),
            _Divider(),
            _ListTile(
              icon: Icons.memory_rounded,
              title: 'Erinnerungen',
              subtitle: 'Core, Langzeit, Kurzzeit',
              color: context.buddy.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MemoryBrowserScreen()),
              ),
            ),
            _Divider(),
            _ProactivityTile(),
          ])),

          // ── Werkzeuge ──
          SliverToBoxAdapter(child: _SectionHeader('Werkzeuge',
            expanded: _secTools,
            onTap: () => setState(() => _secTools = !_secTools),
          )),
          if (_secTools) SliverToBoxAdapter(child: _GlassCard(children: [
            _ListTile(
              icon: Icons.map_rounded,
              title: 'Offline-Karten',
              subtitle: 'Kacheln fuer Navigation ohne Netz',
              color: context.buddy.accent,
              trailing: FutureBuilder<bool>(
                future: TileDownloadService.hasOfflineTiles(),
                builder: (_, snap) => snap.hasData && snap.data == true
                  ? Icon(Icons.check_circle, color: context.buddy.success, size: 20)
                  : Icon(Icons.download_for_offline, color: context.buddy.t3, size: 20),
              ),
              onTap: () => showDialog(context: context, builder: (_) => const OfflineMapDialog()),
            ),
            _Divider(),
            _ListTile(
              icon: Icons.notes_rounded,
              title: 'Agent Notizen',
              subtitle: 'Werkzeuge, Skills, Passwörter',
              color: context.buddy.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuddyNotesScreen()),
              ),
            ),
            _Divider(),
            _ListTile(
              icon: Icons.auto_fix_high_rounded,
              title: 'Meine Fähigkeiten',
              subtitle: 'Was die KI alles kann — editierbar',
              color: context.buddy.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuddyCapabilitiesScreen()),
              ),
            ),
          ])),

          // ── Embedding (Memory-Suche) ──
          SliverToBoxAdapter(child: _SectionHeader('Embedding (Memory-Suche)',
            expanded: _secEmbedding,
            onTap: () => setState(() => _secEmbedding = !_secEmbedding),
          )),
          if (_secEmbedding) ...[
          SliverToBoxAdapter(child: _GlassCard(children: [
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
            _GlassTextField(
              label: _embeddingProvider == 'ollama'
                  ? 'Base URL (z.B. https://ollama.com/api)'
                  : _embeddingProvider == 'openrouter'
                      ? 'Base URL (Standard: https://openrouter.ai/api)'
                      : 'Base URL (Standard: https://api.openai.com)',
              icon: Icons.link_rounded,
              controller: _embeddingBaseUrlController,
            ),
            _GlassTextField(
              label: 'API Key',
              icon: Icons.key_rounded,
              controller: _embeddingApiKeyController,
              obscure: true,
            ),
            _GlassTextField(
              label: _embeddingProvider == 'ollama'
                  ? 'Modell (z.B. nomic-embed-text)'
                  : _embeddingProvider == 'openrouter'
                      ? 'Modell (z.B. qwen/qwen3-embedding-8b)'
                      : 'Modell (z.B. text-embedding-3-small)',
              icon: Icons.memory_rounded,
              controller: _embeddingModelController,
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _GradientButton(
                icon: Icons.save_rounded,
                label: 'Speichern',
                onTap: _saveEmbeddingConfig,
              )),
              const SizedBox(width: 8),
              Expanded(child: _OutlineButton(
                icon: _isTestingEmbedding ? Icons.hourglass_empty_rounded : Icons.check_circle_rounded,
                label: _isTestingEmbedding ? 'Teste…' : 'Testen',
                onTap: _isTestingEmbedding ? null : _testEmbedding,
              )),
            ]),
            if (_embeddingTestResult != null)
              _ResultBox(text: _embeddingTestResult!),
          ])),
          ],

          // ── Konfiguration ──
          SliverToBoxAdapter(child: _SectionHeader('Konfiguration',
            expanded: _secConfig,
            onTap: () => setState(() => _secConfig = !_secConfig),
          )),
          if (_secConfig) ...[

          // ── Buddy-Name ──
          SliverToBoxAdapter(child: _ExpandableSection(
            title: 'Buddy-Name',
            icon: Icons.person_rounded,
            color: context.buddy.accent,
            expanded: _buddyNameExpanded,
            onToggle: () => setState(() => _buddyNameExpanded = !_buddyNameExpanded),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: _GlassTextField(
                  label: 'Wie soll dein Buddy heißen?',
                  icon: Icons.edit_rounded,
                  controller: _buddyNameController,
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _GradientButton(
                  icon: Icons.save_rounded,
                  label: 'Speichern',
                  onTap: _saveBuddyName,
                )),
              ]),
            ],
          )),

          // ── E-Mail (IMAP) ──
          SliverToBoxAdapter(child: _ExpandableSection(
            title: 'E-Mail (IMAP)',
            icon: Icons.email_rounded,
            color: context.buddy.accent,
            expanded: _emailExpanded,
            onToggle: () => setState(() => _emailExpanded = !_emailExpanded),
            children: [
              _GlassTextField(
                label: 'E-Mail-Adresse',
                icon: Icons.email_rounded,
                controller: _emailAddressController,
              ),
              _GlassTextField(
                label: 'Passwort / App-Passwort',
                icon: Icons.lock_rounded,
                controller: _emailPasswordController,
                obscure: true,
              ),
              _GlassTextField(
                label: 'IMAP-Server (z.B. imap.gmail.com)',
                icon: Icons.dns_rounded,
                controller: _imapServerController,
              ),
              _GlassTextField(
                label: 'IMAP-Port (Standard: 993)',
                icon: Icons.pin_rounded,
                controller: _imapPortController,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _GradientButton(
                  icon: Icons.save_rounded,
                  label: 'Speichern',
                  onTap: _saveEmailConfig,
                )),
              ]),
            ],
          )),

          // ── KI-Modell ──
          SliverToBoxAdapter(child: _ExpandableSection(
            title: 'KI-Modell',
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
                  ],
                ),
              ),

              if (_llmProvider == 'ollama') ...[
                _GlassTextField(
                  label: 'Base URL',
                  icon: Icons.link_rounded,
                  controller: _ollamaBaseUrlController,
                ),
                _GlassTextField(
                  label: 'API Key',
                  icon: Icons.key_rounded,
                  controller: _ollamaKeyController,
                  obscure: true,
                ),
                _buildModelDropdown(
                  label: 'Modell',
                  icon: Icons.smart_toy_rounded,
                  models: _ollamaModels,
                  controller: _ollamaModelController,
                ),
                _GlassTextField(
                  label: 'Fallback',
                  icon: Icons.backup_rounded,
                  controller: _ollamaFallbackController,
                ),
              ] else if (_llmProvider == 'openrouter') ...[
                _GlassTextField(
                  label: 'OpenRouter API Key',
                  icon: Icons.key_rounded,
                  controller: _openRouterKeyController,
                  obscure: true,
                ),
                _buildModelDropdown(
                  label: 'Modell',
                  icon: Icons.smart_toy_rounded,
                  models: _openRouterModels,
                  controller: _openRouterModelController,
                ),
                _GlassTextField(
                  label: 'Fallback',
                  icon: Icons.backup_rounded,
                  controller: _openRouterFallbackController,
                ),
              ] else if (_llmProvider == 'openai') ...[
                _GlassTextField(
                  label: 'API Key',
                  icon: Icons.key_rounded,
                  controller: _openAIKeyController,
                  obscure: true,
                ),
                _buildModelDropdown(
                  label: 'Modell',
                  icon: Icons.smart_toy_rounded,
                  models: _openAIModels,
                  controller: _openAIModelController,
                ),
                _GlassTextField(
                  label: 'Fallback',
                  icon: Icons.backup_rounded,
                  controller: _openAIFallbackController,
                ),
              ] else if (_llmProvider == 'anthropic') ...[
                _GlassTextField(
                  label: 'API Key',
                  icon: Icons.key_rounded,
                  controller: _anthropicKeyController,
                  obscure: true,
                ),
                _buildModelDropdown(
                  label: 'Modell',
                  icon: Icons.smart_toy_rounded,
                  models: _anthropicModels,
                  controller: _anthropicModelController,
                ),
                _GlassTextField(
                  label: 'Fallback',
                  icon: Icons.backup_rounded,
                  controller: _anthropicFallbackController,
                ),
              ],

              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _GradientButton(
                  icon: Icons.save_rounded,
                  label: 'Speichern',
                  onTap: _saveOllamaConfig,
                )),
                const SizedBox(width: 8),
                Expanded(child: _OutlineButton(
                  icon: _isTestingOllama ? Icons.hourglass_empty_rounded : Icons.check_circle_rounded,
                  label: _isTestingOllama ? 'Teste…' : 'Testen',
                  onTap: _isTestingOllama ? null : _testOllama,
                )),
              ]),
              if (_ollamaTestResult != null)
                _ResultBox(text: _ollamaTestResult!),
            ],
          )),

          // ── Sprache ──
          SliverToBoxAdapter(child: _ExpandableSection(
            title: 'Sprachausgabe',
            icon: Icons.record_voice_over_rounded,
            color: context.buddy.accent,
            expanded: _elevenExpanded,
            onToggle: () => setState(() => _elevenExpanded = !_elevenExpanded),
            children: [
              // TTS Engine Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text('TTS Engine', style: TextStyle(color: context.buddy.t2, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    ...TtsEngine.values.map((e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
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
                      ),
                    )),
                  ],
                ),
              ),
              _Divider(),

              // Piper voice management (shown when Piper selected)
              if (_ttsEngine == TtsEngine.piper) ...[
                Builder(builder: (context) {
                  final piper = context.watch<PiperTtsService>();
                  return Column(children: [
                    // Voice download selection — grouped by language
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Align(alignment: Alignment.centerLeft,
                        child: Text('Piper Stimmen (offline)', style: TextStyle(color: context.buddy.t2, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    // Language dropdown
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Text('Sprache: ', style: TextStyle(color: context.buddy.t2, fontSize: 13)),
                          Expanded(
                            child: DropdownButton<String>(
                              value: _piperLangFilter,
                              isExpanded: true,
                              underline: Container(height: 1, color: context.buddy.border),
                              items: [
                                const DropdownMenuItem(value: 'all', child: Text('Alle Sprachen')),
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
                    ..._filteredPiperVoices.map((voice) => _PiperVoiceTile(
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
                              Text('Sprechgeschwindigkeit', style: TextStyle(color: context.buddy.t2, fontSize: 13, fontWeight: FontWeight.w600)),
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
                              Text('langsam', style: TextStyle(color: context.buddy.t3, fontSize: 11)),
                              Text('schnell', style: TextStyle(color: context.buddy.t3, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _GradientButton(
                        icon: Icons.save_rounded,
                        label: 'Speichern',
                        onTap: _saveTtsConfig,
                      )),
                    ]),
                  ]);
                }),
              ],

              // Device TTS (shown when device selected)
              if (_ttsEngine == TtsEngine.device) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text('Verwendet die System-Sprachausgabe des Geräts. Kein Download nötig, aber Qualität variiert je nach Gerät.',
                    style: TextStyle(color: context.buddy.t2, fontSize: 13, height: 1.5)),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _GradientButton(
                    icon: Icons.save_rounded,
                    label: 'Speichern',
                    onTap: _saveTtsConfig,
                  )),
                ]),
              ],
            ],
          )),

          ],


          // ── Daten ──
          SliverToBoxAdapter(child: _SectionHeader('Daten',
            expanded: _secData,
            onTap: () => setState(() => _secData = !_secData),
          )),
          if (_secData) ...[
          SliverToBoxAdapter(child: _GlassCard(children: [
            _ListTile(
              icon: Icons.backup_outlined,
              title: 'Backup erstellen',
              color: context.buddy.success,
              onTap: _createBackup,
            ),
            _Divider(),
            _ListTile(
              icon: Icons.restore_outlined,
              title: 'Wiederherstellen',
              color: context.buddy.accent,
              onTap: _restoreBackup,
            ),
            _Divider(),
            _Divider(),
            _ListTile(
              icon: Icons.delete_forever_outlined,
              title: 'Chat löschen',
              color: context.buddy.error,
              onTap: _clearChatHistory,
            ),
            _Divider(),
            _ListTile(
              icon: Icons.memory_outlined,
              title: 'Erinnerungen löschen',
              color: context.buddy.error,
              onTap: _clearMemories,
            ),
            _Divider(),
            _ListTile(
              icon: Icons.restart_alt_rounded,
              title: 'App zurücksetzen',
              subtitle: 'Alles löschen — wie neu installiert',
              color: context.buddy.error,
              onTap: _resetApp,
            ),
          ])),
          ],

          // ── Hintergrund-Tasks ──
          SliverToBoxAdapter(child: _SectionHeader('Hintergrund-Tasks',
            expanded: _secScheduler,
            onTap: () => setState(() => _secScheduler = !_secScheduler),
          )),
          if (_secScheduler) SliverToBoxAdapter(child: _SchedulerSection()),

          // ── Über ──
          SliverToBoxAdapter(child: _SectionHeader('Über',
            expanded: _secAbout,
            onTap: () => setState(() => _secAbout = !_secAbout),
          )),
          if (_secAbout) SliverToBoxAdapter(child: _GlassCard(children: [
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snap) => _ListTile(
                icon: Icons.favorite_rounded,
                title: 'AI-Buddy',
                // Echte Laufzeit-Version aus dem Build — die Konstante in
                // version.dart driftet, weil sie manuell gepflegt wird.
                subtitle: snap.hasData
                    ? 'Version ${snap.data!.version}+${snap.data!.buildNumber}'
                    : 'Version $appVersion',
                color: context.buddy.accent,
                onTap: () {},
              ),
            ),
          ])),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
          // Bottom SafeArea padding
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
          ),
        ],
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

  /// Embedding provider tab button for the 3-provider switch.
  Widget _embeddingTab(String label, String id) {
    final selected = _embeddingProvider == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _embeddingProvider = id),
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
  return _ModelDropdown(
    label: label,
    icon: icon,
    models: models,
    controller: controller,
  );
}

class _ModelDropdown extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<Map<String, String>> models;
  final TextEditingController controller;
  const _ModelDropdown({
    required this.label,
    required this.icon,
    required this.models,
    required this.controller,
  });
  @override
  State<_ModelDropdown> createState() => _ModelDropdownState();
}

class _ModelDropdownState extends State<_ModelDropdown> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final currentId = widget.controller.text;
    final isCustom = !widget.models.any((m) => m['id'] == currentId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: DropdownButtonFormField<String>(
          initialValue: isCustom ? '__custom__' : currentId,
          icon: Icon(Icons.arrow_drop_down_rounded, color: context.buddy.t3),
          decoration: InputDecoration(
            hintText: widget.label,
            hintStyle: TextStyle(color: context.buddy.t3.withValues(alpha: 0.5), fontSize: 15),
            prefixIcon: Icon(widget.icon, size: 20, color: _focused
              ? context.buddy.accent
              : context.buddy.t3.withValues(alpha: 0.6)),
            filled: true,
            fillColor: _focused
              ? context.buddy.card.withValues(alpha: 0.5)
              : context.buddy.card.withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.buddy.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.buddy.accent.withValues(alpha: 0.6), width: 1.5),
            ),
            isDense: true,
          ),
          dropdownColor: context.buddy.card,
          style: TextStyle(color: context.buddy.t1, fontSize: 15, fontWeight: FontWeight.w500),
          items: [
            ...widget.models.map((model) => DropdownMenuItem(
              value: model['id'],
              child: Text(model['name']!, style: TextStyle(color: context.buddy.t1, fontSize: 14)),
            )),
            DropdownMenuItem(
              value: '__custom__',
              child: Row(children: [
                Icon(Icons.edit_rounded, size: 16, color: context.buddy.t3),
                const SizedBox(width: 8),
                Text(isCustom ? 'Eigene: ${currentId.length > 30 ? "${currentId.substring(0, 30)}…" : currentId}' : 'Eigene ID eingeben…',
                  style: TextStyle(color: isCustom ? context.buddy.accent : context.buddy.t2, fontSize: 14)),
              ]),
            ),
          ],
          onChanged: (value) async {
            if (value == '__custom__') {
              final custom = await _showCustomModelDialog(context, widget.controller.text);
              if (custom != null && custom.isNotEmpty) {
                setState(() => widget.controller.text = custom);
              }
            } else if (value != null) {
              setState(() => widget.controller.text = value);
            }
          },
        ),
      ),
    );
  }

  Future<String?> _showCustomModelDialog(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    try {
      return await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.buddy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Modell-ID', style: TextStyle(color: context.buddy.t1, fontSize: 18, fontWeight: FontWeight.w700)),
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
            child: Text('Abbrechen', style: TextStyle(color: context.buddy.t2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Speichern', style: TextStyle(color: context.buddy.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      );
    } finally {
      controller.dispose();
    }
  }
}

// ──── UI Widgets ────

/// Klickbares Abschnitts-Label mit Chevron (klappbar).
class _SectionHeader extends StatelessWidget {
  final String text;
  final bool expanded;
  final VoidCallback onTap;
  const _SectionHeader(this.text, {required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: context.buddy.t2,
                ),
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: context.buddy.t2,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kleines Abschnitts-Label über einer Karte (iOS-Settings-Stil).
class _GlassCard extends StatelessWidget {
  final List<Widget> children;
  const _GlassCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.buddy.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.buddy.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _ExpandableSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _ExpandableSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.buddy.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.buddy.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: widget.onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.buddy.t1)),
                const SizedBox(height: 2),
                Text(widget.expanded ? 'Einklappen zur Bearbeitung' : 'Aufklappen zur Bearbeitung',
                  style: TextStyle(fontSize: 12, color: context.buddy.t3)),
              ])),
              AnimatedRotation(
                turns: widget.expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: context.buddy.t2, size: 24),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          firstChild: Container(),
          secondChild: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [...widget.children, const SizedBox(height: 8)]),
          ),
          crossFadeState: widget.expanded
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ]),
    );
  }
}

class _ListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ListTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: context.buddy.border,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.buddy.border),
                    ),
                    child: Icon(icon, size: 20, color: context.buddy.t2),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.buddy.t1)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                        style: TextStyle(fontSize: 13, color: context.buddy.t2),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ])),
                ]),
              ),
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class _GlassTextField extends StatefulWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool obscure;
  const _GlassTextField({
    required this.label,
    required this.icon,
    required this.controller,
    this.obscure = false,
  });

  @override
  State<_GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<_GlassTextField> {
  bool _focused = false;
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final isObscure = widget.obscure && _obscureText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: TextField(
          controller: widget.controller,
          obscureText: isObscure,
          style: TextStyle(color: context.buddy.t1, fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: widget.label,
            hintStyle: TextStyle(color: context.buddy.t3.withValues(alpha: 0.5), fontSize: 15),
            prefixIcon: Icon(widget.icon, size: 20, color: _focused
              ? context.buddy.accent
              : context.buddy.t3.withValues(alpha: 0.6)),
            suffixIcon: widget.obscure
              ? IconButton(
                  icon: Icon(_obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 18, color: context.buddy.t3),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                )
              : null,
            filled: true,
            fillColor: _focused
              ? context.buddy.card.withValues(alpha: 0.5)
              : context.buddy.card.withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.buddy.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.buddy.accent.withValues(alpha: 0.6), width: 1.5),
            ),
            isDense: true,
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _GradientButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 8, 0, 16),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.buddy.accent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap != null ? [
            BoxShadow(
              color: context.buddy.accent.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _OutlineButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 8, 0, 16),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: onTap == null
              ? context.buddy.border
              : context.buddy.chipBorder),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: onTap == null
            ? context.buddy.t3
            : context.buddy.t1),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            color: onTap == null ? context.buddy.t3 : context.buddy.t1)),
        ]),
      ),
    );
  }
}

class _ResultBox extends StatelessWidget {
  final String text;
  const _ResultBox({required this.text});

  @override
  Widget build(BuildContext context) {
    final ok = !text.startsWith('Fehler');
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (ok ? context.buddy.success : context.buddy.error).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (ok ? context.buddy.success : context.buddy.error).withValues(alpha: 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
          size: 18, color: ok ? context.buddy.success : context.buddy.error),
        const SizedBox(width: 10),
        Expanded(child: Text(text,
          style: TextStyle(fontSize: 13, color: ok ? context.buddy.success : context.buddy.error, height: 1.4))),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.buddy.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: context.buddy.accent,
      )),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        color: context.buddy.border,
        height: 1,
      ),
    );
  }
}

class _PiperVoiceTile extends StatelessWidget {
  final PiperVoice voice;
  final PiperTtsService piper;
  final bool isCurrent;
  final VoidCallback onLoad;
  final VoidCallback onDelete;
  final VoidCallback onDownload;

  const _PiperVoiceTile({
    required this.voice,
    required this.piper,
    required this.isCurrent,
    required this.onLoad,
    required this.onDelete,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: piper.isVoiceDownloaded(voice),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.data ?? false;
        final isThisDownloading = piper.isDownloadingVoice(voice);
        final isLoaded = piper.isLoaded && piper.currentVoice == voice;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isCurrent
              ? context.buddy.accent.withValues(alpha: 0.15)
              : context.buddy.card.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrent
                ? context.buddy.accent.withValues(alpha: 0.5)
                : context.buddy.border,
            ),
          ),
          child: Row(children: [
            Icon(
              isLoaded ? Icons.record_voice_over_rounded
                : isDownloaded ? Icons.download_done_rounded
                : Icons.download_rounded,
              size: 22,
              color: isCurrent ? context.buddy.accent : context.buddy.t2,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(voice.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                    color: isCurrent ? context.buddy.accent : context.buddy.t1,
                  )),
                Text(isThisDownloading
                    ? 'Wird heruntergeladen… ${(piper.downloadProgress * 100).toStringAsFixed(0)}%'
                    : isDownloaded ? 'Heruntergeladen'
                    : 'Nicht heruntergeladen',
                  style: TextStyle(fontSize: 12, color: context.buddy.t3)),
                if (isCurrent) Text('✓ Aktiv',
                  style: TextStyle(fontSize: 11, color: context.buddy.success, fontWeight: FontWeight.w600)),
              ],
            )),
            if (isThisDownloading)
              SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: context.buddy.accent,
                  backgroundColor: context.buddy.accent.withValues(alpha: 0.2),
                )),
            if (!isThisDownloading) ...[
              if (!isDownloaded)
                _SmallButton(
                  icon: Icons.download_rounded,
                  label: 'Download',
                  onTap: onDownload,
                  color: context.buddy.accent,
                ),
              if (isDownloaded && !isCurrent)
                _SmallButton(
                  icon: Icons.play_arrow_rounded,
                  label: 'Laden',
                  onTap: onLoad,
                  color: context.buddy.success,
                ),
              if (isDownloaded && !isCurrent)
                _SmallButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Löschen',
                  onTap: onDelete,
                  color: context.buddy.error,
                ),
            ],
          ]),
        );
      },
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _SmallButton({required this.icon, required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

/// Settings section for background tasks (BuddyScheduler).
class _SchedulerSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheduler = context.watch<BuddyScheduler>();
    if (!scheduler.isInitialized) return const SizedBox.shrink();

    return _GlassCard(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          Icon(Icons.schedule_outlined, size: 20, color: context.buddy.accent),
          const SizedBox(width: 8),
          Text('Hintergrund-Tasks',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.buddy.accent)),
        ]),
      ),
      const SizedBox(height: 4),
      for (final entry in scheduler.tasks.entries) ...[
        _SchedulerTaskTile(
          taskId: entry.key,
          config: entry.value,
          lastRun: scheduler.getLastRun(entry.key),
          onToggle: (enabled) => scheduler.setTaskEnabled(entry.key, enabled),
          onRunNow: () => scheduler.runTaskNow(entry.key),
        ),
        if (entry.key != scheduler.tasks.keys.last) const _Divider(),
      ],
    ]);
  }
}

class _SchedulerTaskTile extends StatelessWidget {
  final String taskId;
  final BuddyTaskConfig config;
  final String? lastRun;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRunNow;

  const _SchedulerTaskTile({
    required this.taskId,
    required this.config,
    this.lastRun,
    required this.onToggle,
    required this.onRunNow,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        taskId == 'self_optimization' ? Icons.auto_fix_high_outlined : Icons.wb_sunny_outlined,
        color: config.enabled ? context.buddy.accent : context.buddy.t2,
        size: 22,
      ),
      title: Text(config.name, style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: config.enabled ? context.buddy.t1 : context.buddy.t2,
      )),
      subtitle: Text(
        '${config.description}\nAlle ${config.frequency.inMinutes} Min${lastRun != null ? " · Letztmals ${_formatLastRun(lastRun!)}" : ""}',
        style: TextStyle(fontSize: 12, color: context.buddy.t2),
      ),
      isThreeLine: true,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          icon: const Icon(Icons.play_circle_outline, size: 20),
          color: context.buddy.accent,
          onPressed: onRunNow,
          tooltip: 'Jetzt ausführen',
        ),
        Switch(
          value: config.enabled,
          onChanged: onToggle,
          activeThumbColor: context.buddy.accent,
        ),
      ]),
    );
  }

  String _formatLastRun(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'gerade eben';
      if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min';
      if (diff.inHours < 24) return 'vor ${diff.inHours}h';
      return 'vor ${diff.inDays}d';
    } catch (_) {
      return iso;
    }
  }
}


// ── Proaktivitäts-Level Widget ──

class _ProactivityTile extends StatefulWidget {
  const _ProactivityTile();

  @override
  State<_ProactivityTile> createState() => _ProactivityTileState();
}

class _ProactivityTileState extends State<_ProactivityTile> {
  static const _labels = ['Aus', 'Niedrig', 'Normal', 'Hoch'];
  static const _hints = [
    'Keine proaktiven Nachrichten',
    'Nur dringende Erinnerungen',
    'Zeit, Ort + Routinen',
    'Alles + Lernen',
  ];

  @override
  Widget build(BuildContext context) {
    final config = context.read<SecureConfigService>();
    return _ListTile(
      icon: Icons.notifications_active_rounded,
      title: 'Proaktivität',
      subtitle: '${_labels[config.proactivityLevel]} · ${_hints[config.proactivityLevel]}',
      color: context.buddy.accent,
      trailing: DropdownButton<int>(
        value: config.proactivityLevel,
        underline: const SizedBox(),
        style: TextStyle(color: context.buddy.t1, fontSize: 13),
        items: const [
          DropdownMenuItem(value: 0, child: Text('Aus')),
          DropdownMenuItem(value: 1, child: Text('Niedrig')),
          DropdownMenuItem(value: 2, child: Text('Normal')),
          DropdownMenuItem(value: 3, child: Text('Hoch')),
        ],
        onChanged: (v) async {
          if (v == null) return;
          await config.setProactivityLevel(v);
          setState(() {});
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Proaktivität: ${_labels[v]}')),
            );
          }
        },
      ),
      onTap: () {}, // DropdownButton is the primary interaction here
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  static const _languages = <(String, String)>[
    ('en', '🇬🇧 English'),
    ('de', '🇩🇪 Deutsch'),
    ('es', '🇪🇸 Español'),
    ('ja', '🇯🇵 日本語'),
    ('zh', '🇨🇳 中文'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.buddy;
    final settings = context.watch<SettingsService>();
    final current = settings.themeMode;
    final appLang = settings.appLanguage;
    const options = <(ThemeMode, String, IconData)>[
      (ThemeMode.system, 'System', Icons.brightness_auto_rounded),
      (ThemeMode.light, 'Hell', Icons.light_mode_rounded),
      (ThemeMode.dark, 'Dunkel', Icons.dark_mode_rounded),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
        boxShadow: c.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App-Sprache
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
            child: Row(
              children: [
                Icon(Icons.language, size: 17, color: c.t2),
                const SizedBox(width: 8),
                Text('Sprache / Language',
                    style: TextStyle(color: c.t2, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (code, label) in _languages)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, left: 2),
                    child: GestureDetector(
                      onTap: () => context.read<SettingsService>().appLanguage = code,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: appLang == code
                              ? c.accent.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: appLang == code ? c.accent : c.border,
                            width: appLang == code ? 1.5 : 1,
                          ),
                        ),
                        child: Text(label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: appLang == code ? c.accent : c.t2,
                            )),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (value, label, icon) in options)
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.read<SettingsService>().themeMode = value,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: current == value ? context.buddy.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Icon(icon, size: 20, color: current == value ? Colors.white : c.t2),
                          const SizedBox(height: 4),
                          Text(label, style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: current == value ? Colors.white : c.t2,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Akzentfarbe Picker
          _AccentColorPicker(),
        ],
      ),
    );
  }
}

class _AccentColorPicker extends StatelessWidget {
  static const _presets = <Color>[
    Color(0xFF6B8DD6), // Periwinkle (default)
    Color(0xFF5B9BD5), // Blue
    Color(0xFF34C759), // Green
    Color(0xFFFF9500), // Orange
    Color(0xFFFF3B30), // Red
    Color(0xFFFF6B9D), // Pink
    Color(0xFFA855F7), // Purple
    Color(0xFF64D2FF), // Cyan
    Color(0xFFD4AF37), // Gold
    Color(0xFF9BA0A3), // Gray
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.buddy;
    final current = context.watch<SettingsService>().accentColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, size: 14, color: c.t3),
              const SizedBox(width: 6),
              Text('Akzentfarbe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.t2)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _presets.map((color) {
              final isSelected = current.toARGB32() == color.toARGB32();
              return GestureDetector(
                onTap: () => context.read<SettingsService>().accentColor = color,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? c.t1 : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
