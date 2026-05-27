import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
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
import '../services/local_model_service.dart';
import '../services/ollama_cloud_service.dart';
import '../widgets/offline_map_dialog.dart';
import 'persona_editor_screen.dart';
import 'self_identity_screen.dart';
import 'buddy_notes_screen.dart';
import 'buddy_capabilities_screen.dart';
import 'memory_browser_screen.dart';
import 'package:share_plus/share_plus.dart' as share_plus;

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

  bool _isTestingOllama = false;
  String? _ollamaTestResult;

  bool _ollamaExpanded = true;
  bool _elevenExpanded = true;
  String _llmProvider = 'ollama';
  TtsEngine _ttsEngine = TtsEngine.piper;

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
    super.dispose();
  }

  Future<void> _saveOllamaConfig() async {
    final config = context.read<SecureConfigService>();
    final localModel = context.read<LocalModelService>();

    // Fix 1: Persist the selected provider
    await config.setLlmProvider(_llmProvider);

    // Fix 2: Save all cloud config fields
    await config.setOllamaBaseUrl(_ollamaBaseUrlController.text.trim());
    await config.setOllamaApiKey(_ollamaKeyController.text.trim());
    await config.setOllamaModel(_ollamaModelController.text.trim());
    await config.setOllamaFallbackModel(_ollamaFallbackController.text.trim());
    await config.setOpenRouterApiKey(_openRouterKeyController.text.trim());
    await config.setOpenRouterModel(_openRouterModelController.text.trim());
    await config.setOpenRouterFallbackModel(_openRouterFallbackController.text.trim());

    if (_llmProvider == 'local') {
      if (localModel.isModelAvailable) {
        await localModel.setUseLocalModel(true);
        if (mounted) _showSnack('Lokales Modell aktiv ✅', AppColors.success);
      } else {
        if (mounted) _showSnack('Modell nicht installiert. Bitte zuerst herunterladen.', AppColors.warning);
      }
    } else {
      // Cloud provider: disable local model flag
      await localModel.setUseLocalModel(false);
      if (mounted) _showSnack('${_llmProvider == "ollama" ? "Ollama" : "OpenRouter"} gespeichert ✅', AppColors.success);
    }
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
    if (mounted) _showSnack('Sprachausgabe gespeichert ✅', AppColors.success);
  }

  Future<void> _testOllama() async {
    setState(() { _isTestingOllama = true; _ollamaTestResult = null; });
    try {
      final config = context.read<SecureConfigService>();
      if (_llmProvider == 'local') {
        // Test local model
        final localModel = context.read<LocalModelService>();
        final reply = await localModel.chat(
          [{'role': 'user', 'content': 'Hallo, Test!'}],
          systemPrompt: 'Du bist ein Test. Antworte kurz: OK',
          temperature: 0.1,
        );
        final text = reply.length > 60 ? '${reply.substring(0, 60)}...' : reply;
        setState(() => _ollamaTestResult = 'Lokal OK — $text');
      } else {
        // Test cloud provider
        final cloud = OllamaCloudService(
          baseUrl: _llmProvider == 'openrouter' ? config.openRouterBaseUrl : config.ollamaBaseUrl,
          apiKey: _llmProvider == 'openrouter' ? _openRouterKeyController.text.trim().isNotEmpty ? _openRouterKeyController.text.trim() : config.openRouterApiKey : _ollamaKeyController.text.trim().isNotEmpty ? _ollamaKeyController.text.trim() : config.ollamaApiKey,
          defaultModel: _llmProvider == 'openrouter' ? (_openRouterModelController.text.trim().isNotEmpty ? _openRouterModelController.text.trim() : config.openRouterModel) : (_ollamaModelController.text.trim().isNotEmpty ? _ollamaModelController.text.trim() : config.ollamaModel),
          fallbackModel: _llmProvider == 'openrouter' ? (_openRouterFallbackController.text.trim().isNotEmpty ? _openRouterFallbackController.text.trim() : config.openRouterFallbackModel) : (_ollamaFallbackController.text.trim().isNotEmpty ? _ollamaFallbackController.text.trim() : config.ollamaFallbackModel),
        );
        final reply = await cloud.chat(
          systemPrompt: 'Du bist ein Test. Antworte kurz: OK',
          messages: [{'role': 'user', 'content': 'Hallo, Test!'}],
          temperature: 0.1,
        );
        final text = reply.length > 60 ? '${reply.substring(0, 60)}...' : reply;
        setState(() => _ollamaTestResult = '${_llmProvider == "openrouter" ? "OpenRouter" : "Ollama"} OK — $text');
      }
    } catch (e) {
      setState(() => _ollamaTestResult = 'Fehler: ${_trunc(e.toString(), 120)}');
    } finally {
      if (mounted) setState(() => _isTestingOllama = false);
    }
  }

  Future<void> _clearChatHistory() async {
    final chatHistory = context.read<ChatHistoryService>();
    final confirmed = await _confirm('Chat-Verlauf löschen?',
        'Alle Nachrichten werden unwiderruflich gelöscht.');
    if (confirmed) {
      await chatHistory.clear();
      if (mounted) {
        _showSnack('Chat-Verlauf gelöscht', AppColors.error);
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
        _showSnack('Erinnerungen gelöscht', AppColors.error);
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
        _showSnack('Backup erstellt — speicher es sicher ab ✅', AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Fehler: ${_trunc(e.toString(), 80)}', AppColors.error);
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
          _showSnack('Backup eingespielt ✅', AppColors.success);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Fehler: ${_trunc(e.toString(), 80)}', AppColors.error);
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
        _showSnack('App zurückgesetzt — neu starten empfohlen', AppColors.error);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Fehler: ${_trunc(e.toString(), 80)}', AppColors.error);
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
          backgroundColor: AppColors.bgElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.warning_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
          ]),
          content: Text(body,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Abbrechen', style: TextStyle(
                color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error.withValues(alpha: 0.2),
                foregroundColor: AppColors.error,
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
          color: AppColors.bgElevated.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.3)),
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
                color: AppColors.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('KI-Entwicklung',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${traits.length} gelernte Merkmale',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ])),
            ]),
            const SizedBox(height: 20),
            Expanded(
              child: traits.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.psychology_alt_outlined,
                      size: 48, color: AppColors.textTertiary.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    Text('Noch keine Merkmale gelernt',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('Dein Agent lernt mit jedem Gespräch mehr über dich.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 13, height: 1.5)),
                  ]))
                : ListView.builder(
                    controller: scrollCtrl,
                    physics: const BouncingScrollPhysics(),
                    itemCount: traits.length,
                    itemBuilder: (_, i) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: Text((i + 1).toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Text(traits[i],
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 15))),
                        Icon(Icons.check_rounded, size: 18, color: AppColors.success),
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
      backgroundColor: AppColors.bgDarkest,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Sliver Header ──
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(children: const [
                SizedBox(height: 60),
                Text('Einstellungen',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary, letterSpacing: -0.5)),
                SizedBox(height: 6),
                Text('Konfiguriere deinen AI-Buddy',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                SizedBox(height: 16),
              ]),
            ),
          ),

          // ── Persona ──
          SliverToBoxAdapter(child: _GlassCard(children: [
            _ListTile(
              icon: Icons.face_5_rounded,
              title: 'Persona bearbeiten',
              subtitle: persona.name.isEmpty ? 'Standard' : persona.name,
              color: AppColors.primary,
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
              color: AppColors.accent,
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
              color: AppColors.secondary,
              trailing: _Badge('${evolution.learnedTraits.length}'),
              onTap: _showKIEntwicklung,
            ),
            _Divider(),
            _ListTile(
              icon: Icons.memory_rounded,
              title: 'Erinnerungen',
              subtitle: 'Core, Langzeit, Kurzzeit',
              color: AppColors.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MemoryBrowserScreen()),
              ),
            ),
            _Divider(),
            _ListTile(
              icon: Icons.map_rounded,
              title: 'Offline-Karten',
              subtitle: 'Kacheln fuer Navigation ohne Netz',
              color: AppColors.primary,
              trailing: FutureBuilder<bool>(
                future: TileDownloadService.hasOfflineTiles(),
                builder: (_, snap) => snap.hasData && snap.data == true
                  ? const Icon(Icons.check_circle, color: Color(0xFF34C759), size: 20)
                  : const Icon(Icons.download_for_offline, color: Color(0xFF5A5A60), size: 20),
              ),
              onTap: () => showDialog(context: context, builder: (_) => const OfflineMapDialog()),
            ),
            _Divider(),
            _ListTile(
              icon: Icons.notes_rounded,
              title: 'Agent Notizen',
              subtitle: 'Werkzeuge, Skills, Passwörter',
              color: AppColors.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuddyNotesScreen()),
              ),
            ),
            _Divider(),
            _ListTile(
              icon: Icons.psychology_rounded,
              title: 'Meine Fähigkeiten',
              subtitle: 'Was die KI alles kann — editierbar',
              color: AppColors.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuddyCapabilitiesScreen()),
              ),
            ),
          ])),

          // ── KI-Modell ──
          SliverToBoxAdapter(child: _ExpandableSection(
            title: 'KI-Modell',
            icon: Icons.auto_awesome_rounded,
            color: AppColors.primary,
            expanded: _ollamaExpanded,
            onToggle: () => setState(() => _ollamaExpanded = !_ollamaExpanded),
            children: [
              // Provider Switch
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.bgCard.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _llmProvider = 'ollama'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: _llmProvider == 'ollama' ? AppColors.primaryGradient : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Ollama',
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: _llmProvider == 'ollama' ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _llmProvider = 'openrouter'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: _llmProvider == 'openrouter' ? AppColors.secondaryGradient : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'OpenRouter',
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: _llmProvider == 'openrouter' ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _llmProvider = 'local'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: _llmProvider == 'local' ? AppColors.successGradient : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Lokal',
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: _llmProvider == 'local' ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
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
                // Modell-Dropdown statt Textfeld
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
                // Modell-Dropdown statt Textfeld
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
              ] else if (_llmProvider == 'local') ...[
                // Lokal: Gemma 4 E2B Panel
                _buildLocalModelContent(),
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
            color: AppColors.secondary,
            expanded: _elevenExpanded,
            onToggle: () => setState(() => _elevenExpanded = !_elevenExpanded),
            children: [
              // TTS Engine Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text('TTS Engine', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    ...TtsEngine.values.map((e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _ttsEngine = e),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: _ttsEngine == e ? AppColors.secondaryGradient : null,
                            color: _ttsEngine == e ? null : AppColors.bgCard.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _ttsEngine == e ? Colors.transparent : AppColors.glassBorder.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(e.label, style: TextStyle(
                            fontSize: 13,
                            fontWeight: _ttsEngine == e ? FontWeight.w700 : FontWeight.w500,
                            color: _ttsEngine == e ? Colors.white : AppColors.textSecondary,
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
                    // Voice download selection
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Align(alignment: Alignment.centerLeft,
                        child: Text('Piper Stimmen (offline)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...PiperVoice.values.map((voice) => _PiperVoiceTile(
                      voice: voice,
                      piper: piper,
                      isCurrent: piper.currentVoice == voice,
                      onLoad: () async {
                        await piper.loadVoice(voice);
                        final config = context.read<SecureConfigService>();
                        await config.setPiperVoice(voice.id);
                        final tts = context.read<TtsPlaybackService>();
                        tts.engine = TtsEngine.piper;
                        setState(() {});
                      },
                      onDelete: () async {
                        await piper.deleteVoice(voice);
                        setState(() {});
                      },
                      onDownload: () async {
                        await piper.downloadVoice(voice, onProgress: (p) => setState(() {}));
                        setState(() {});
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
                              Text('Sprechgeschwindigkeit', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                              Builder(builder: (context) {
                                final tts = context.select<TtsPlaybackService, double>((s) => s.piperSpeed);
                                return Text('${tts.toStringAsFixed(1)}x', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600));
                              }),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Builder(builder: (context) {
                            final speed = context.select<TtsPlaybackService, double>((s) => s.piperSpeed);
                            return SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: AppColors.primary,
                                inactiveTrackColor: AppColors.textTertiary.withValues(alpha: 0.3),
                                thumbColor: AppColors.primary,
                                overlayColor: AppColors.primary.withValues(alpha: 0.2),
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
                              Text('langsam', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                              Text('schnell', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
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
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
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

          // ── Daten ──
          SliverToBoxAdapter(child: _GlassCard(children: [
            _ListTile(
              icon: Icons.delete_forever_outlined,
              title: 'Chat löschen',
              color: AppColors.error,
              onTap: _clearChatHistory,
            ),
            _Divider(),
            _ListTile(
              icon: Icons.memory_outlined,
              title: 'Erinnerungen löschen',
              color: AppColors.error,
              onTap: _clearMemories,
            ),
            _Divider(),
            _ListTile(
              icon: Icons.backup_outlined,
              title: 'Backup erstellen',
              color: AppColors.success,
              onTap: _createBackup,
            ),
            _Divider(),
            _ListTile(
              icon: Icons.restore_outlined,
              title: 'Wiederherstellen',
              color: AppColors.primary,
              onTap: _restoreBackup,
            ),
            _Divider(),
            _ListTile(
              icon: Icons.restart_alt_rounded,
              title: 'App zurücksetzen',
              subtitle: 'Alles löschen — wie neu installiert',
              color: AppColors.error,
              onTap: _resetApp,
            ),
          ])),

          // ── Über ──
          SliverToBoxAdapter(child: _GlassCard(children: [
            _ListTile(
              icon: Icons.favorite_rounded,
              title: 'AI-Buddy',
              subtitle: 'v0.97.5',
              trailing: _Badge('v0.97.5', color: AppColors.secondary),
              onTap: () {},
            ),
          ])),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // Lokales KI-Modell Inhalt (für KI-Modell Tabs)
  // ═══════════════════════════════════════════════════
  Widget _buildLocalModelContent() {
    return ChangeNotifierProvider.value(
      value: context.read<LocalModelService>(),
      child: Consumer<LocalModelService>(
        builder: (context, localModel, _) {
          final isDownloading = localModel.isDownloading;
          final isDeleting = localModel.isDeleting;
          final isAvailable = localModel.isModelAvailable;
          final progress = localModel.downloadProgress;
          final error = localModel.error;
          final activeModel = localModel.activeModel;

          return Column(children: [
            // Modell-Auswahl Dropdown
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 0),
              padding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: AppColors.bgElevated.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.3)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<LocalModelConfig>(
                  isExpanded: true,
                  value: activeModel,
                  dropdownColor: AppColors.bgDark,
                  borderRadius: BorderRadius.circular(12),
                  icon: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary, size: 24),
                  ),
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                  onChanged: isDownloading
                      ? null
                      : (LocalModelConfig? newModel) {
                          if (newModel != null) {
                            localModel.setActiveModel(newModel);
                          }
                        },
                  items: localModel.availableModels.map((model) {
                    return DropdownMenuItem<LocalModelConfig>(
                      value: model,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(children: [
                          Icon(
                            model.id == activeModel.id
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: model.id == activeModel.id
                                ? AppColors.success
                                : AppColors.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(model.displayName,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: model.id == activeModel.id ? FontWeight.w600 : FontWeight.w400,
                                color: model.id == activeModel.id
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              )),
                          ),
                          Text(model.sizeDisplay,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Status Badge + Info
            Row(children: [
              Icon(Icons.memory_rounded, color: AppColors.success, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(activeModel.displayName,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ),
              if (isAvailable)
                _Badge('Bereit', color: AppColors.success)
              else if (isDownloading)
                _Badge('Download…', color: AppColors.warning)
              else
                _Badge('Nicht installiert', color: AppColors.textSecondary),
            ]),
            const SizedBox(height: 8),

            Text('${activeModel.sizeDisplay} · Offline via LiteRT-LM',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
            const SizedBox(height: 16),

            // Download / Delete / Progress
            if (!isAvailable && !isDownloading) ...[
              Row(children: [
                Expanded(child: _GradientButton(
                  icon: Icons.download_rounded,
                  label: 'Download',
                  onTap: () => localModel.downloadModel(),
                )),
              ]),
            ],

            if (isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.bgElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                InkWell(
                  onTap: () => localModel.cancelDownload(),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Abbrechen',
                      style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ],

            if (isDeleting) ...[
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error)),
                const SizedBox(width: 8),
                Text('Wird gelöscht…', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ]),
            ],

            if (isAvailable && !isDeleting) ...[
              Text('Modell ist bereit und wird verwendet, wenn „Lokal" aktiv ist.',
                style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: InkWell(
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppColors.bgDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('Modell löschen?', style: TextStyle(color: AppColors.textPrimary)),
                        content: Text('Das ${activeModel.sizeDisplay} große Modell wird vom Gerät entfernt. Du kannst es jederzeit neu herunterladen.',
                          style: TextStyle(color: AppColors.textSecondary)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('Abbrechen', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('Löschen', style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await localModel.deleteModel();
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.delete_forever_outlined, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Text('Modell löschen',
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 14)),
                    ]),
                  ),
                )),
              ]),
            ],

            if (error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(error, style: TextStyle(fontSize: 12, color: AppColors.error))),
                ]),
              ),
            ],
          ]);
        },
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
          value: isCustom ? '__custom__' : currentId,
          icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.textTertiary),
          decoration: InputDecoration(
            hintText: widget.label,
            hintStyle: TextStyle(color: AppColors.textTertiary.withValues(alpha: 0.5), fontSize: 15),
            prefixIcon: Icon(widget.icon, size: 20, color: _focused
              ? AppColors.primary
              : AppColors.textTertiary.withValues(alpha: 0.6)),
            filled: true,
            fillColor: _focused
              ? AppColors.textPrimary.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.02),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.glassBorder.withValues(alpha: 0.25), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5),
            ),
            isDense: true,
          ),
          dropdownColor: AppColors.bgCard,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
          items: [
            ...widget.models.map((model) => DropdownMenuItem(
              value: model['id'],
              child: Text(model['name']!, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            )),
            DropdownMenuItem(
              value: '__custom__',
              child: Row(children: [
                Icon(Icons.edit_rounded, size: 16, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                Text(isCustom ? 'Eigene: ${currentId.length > 30 ? "${currentId.substring(0, 30)}…" : currentId}' : 'Eigene ID eingeben…',
                  style: TextStyle(color: isCustom ? AppColors.primary : AppColors.textSecondary, fontSize: 14)),
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
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Modell-ID', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'z.B. kimi-k2.6:cloud',
            hintStyle: TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.bgDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Abbrechen', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Speichern', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ──── UI Widgets ────

class _GlassCard extends StatelessWidget {
  final List<Widget> children;
  const _GlassCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.3)),
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
        color: AppColors.bgCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.3)),
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text(widget.expanded ? 'Einklappen zur Bearbeitung' : 'Aufklappen zur Bearbeitung',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              ])),
              AnimatedRotation(
                turns: widget.expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary, size: 24),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Icon(icon, size: 20, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ])),
            if (trailing != null) trailing!,
          ]),
        ),
      ),
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
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: widget.label,
            hintStyle: TextStyle(color: AppColors.textTertiary.withValues(alpha: 0.5), fontSize: 15),
            prefixIcon: Icon(widget.icon, size: 20, color: _focused
              ? AppColors.primary
              : AppColors.textTertiary.withValues(alpha: 0.6)),
            suffixIcon: widget.obscure
              ? IconButton(
                  icon: Icon(_obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 18, color: AppColors.textTertiary),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                )
              : null,
            filled: true,
            fillColor: _focused
              ? AppColors.textPrimary.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.02),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.glassBorder.withValues(alpha: 0.25), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5),
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
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap != null ? [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
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
              ? AppColors.glassBorder.withValues(alpha: 0.2)
              : AppColors.glassBorder.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: onTap == null
            ? AppColors.textTertiary
            : AppColors.textPrimary),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            color: onTap == null ? AppColors.textTertiary : AppColors.textPrimary)),
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
        color: (ok ? AppColors.success : AppColors.error).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (ok ? AppColors.success : AppColors.error).withValues(alpha: 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
          size: 18, color: ok ? AppColors.success : AppColors.error),
        const SizedBox(width: 10),
        Expanded(child: Text(text,
          style: TextStyle(fontSize: 13, color: ok ? AppColors.success : AppColors.error, height: 1.4))),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color? color;
  const _Badge(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? AppColors.primary).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.primary,
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
        color: AppColors.glassBorder.withValues(alpha: 0.3),
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
              ? AppColors.secondary.withValues(alpha: 0.15)
              : AppColors.bgCard.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrent
                ? AppColors.secondary.withValues(alpha: 0.5)
                : AppColors.glassBorder.withValues(alpha: 0.3),
            ),
          ),
          child: Row(children: [
            Icon(
              isLoaded ? Icons.record_voice_over_rounded
                : isDownloaded ? Icons.download_done_rounded
                : Icons.download_rounded,
              size: 22,
              color: isCurrent ? AppColors.secondary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(voice.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                    color: isCurrent ? AppColors.secondary : AppColors.textPrimary,
                  )),
                Text(isThisDownloading
                    ? 'Wird heruntergeladen… ${(piper.downloadProgress * 100).toStringAsFixed(0)}%'
                    : isDownloaded ? 'Heruntergeladen'
                    : 'Nicht heruntergeladen',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                if (isCurrent) Text('✓ Aktiv',
                  style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
              ],
            )),
            if (isThisDownloading)
              SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.secondary,
                  backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                )),
            if (!isThisDownloading) ...[
              if (!isDownloaded)
                _SmallButton(
                  icon: Icons.download_rounded,
                  label: 'Download',
                  onTap: onDownload,
                  color: AppColors.primary,
                ),
              if (isDownloaded && !isCurrent)
                _SmallButton(
                  icon: Icons.play_arrow_rounded,
                  label: 'Laden',
                  onTap: onLoad,
                  color: AppColors.success,
                ),
              if (isDownloaded && !isCurrent)
                _SmallButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Löschen',
                  onTap: onDelete,
                  color: AppColors.error,
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
