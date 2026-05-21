import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../services/secure_config_service.dart';
import '../services/ollama_cloud_service.dart';
import '../services/tts_playback_service.dart';
import '../services/piper_tts_service.dart';
import '../services/backup_service.dart';
import '../services/chat_history_service.dart';
import '../services/memory_service.dart';
import '../services/persona_service.dart';
import '../services/persona_evolution_service.dart';
import '../services/self_identity_service.dart';
import '../services/tile_download_service.dart';
import '../widgets/offline_map_dialog.dart';
import 'persona_editor_screen.dart';
import 'self_identity_screen.dart';
import 'buddy_notes_screen.dart';
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
  String _llmProvider = 'ollama'; // 'ollama' or 'openrouter'
  TtsEngine _ttsEngine = TtsEngine.piper;

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
    final ollama = context.read<OllamaCloudService>();
    await config.setOllamaApiKey(_ollamaKeyController.text);
    await config.setOllamaBaseUrl(_ollamaBaseUrlController.text);
    await config.setOllamaModel(_ollamaModelController.text);
    await config.setOllamaFallbackModel(_ollamaFallbackController.text);
    await config.setOpenRouterApiKey(_openRouterKeyController.text);
    await config.setOpenRouterModel(_openRouterModelController.text);
    await config.setOpenRouterFallbackModel(_openRouterFallbackController.text);
    await config.setLlmProvider(_llmProvider);
    ollama.updateConfig(
      baseUrl: config.activeBaseUrl,
      apiKey: config.activeApiKey,
      defaultModel: config.activeModel,
      fallbackModel: config.activeFallbackModel,
    );
    if (mounted) _showSnack('KI-Modell gespeichert ✅', AppColors.success);
  }

  Future<void> _saveTtsConfig() async {
    final config = context.read<SecureConfigService>();
    final tts = context.read<TtsPlaybackService>();
    await config.setTtsEngine(_ttsEngine.name);
    tts.engine = _ttsEngine;
    if (_ttsEngine == TtsEngine.device) {
      await tts.initDeviceTts();
    }
    if (mounted) _showSnack('Sprachausgabe gespeichert ✅', AppColors.success);
  }

  Future<void> _testOllama() async {
    setState(() { _isTestingOllama = true; _ollamaTestResult = null; });
    try {
      final ollama = context.read<OllamaCloudService>();
      final reply = await ollama.chatWithTools(
        systemPrompt: 'Du bist ein Test. Antworte kurz: OK',
        messages: [{'role': 'user', 'content': 'Hallo, Test!'}],
        temperature: 0.1,
      );
      final text = reply.content.length > 60
          ? '${reply.content.substring(0, 60)}...'
          : reply.content;
      setState(() => _ollamaTestResult = 'Verbindung OK — $text');
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
                            style: TextStyle(
                              color: _llmProvider == 'openrouter' ? Colors.white : AppColors.textSecondary,
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
                _GlassTextField(
                  label: 'Modell',
                  icon: Icons.smart_toy_rounded,
                  controller: _ollamaModelController,
                ),
                _GlassTextField(
                  label: 'Fallback',
                  icon: Icons.backup_rounded,
                  controller: _ollamaFallbackController,
                ),
              ] else ...[
                _GlassTextField(
                  label: 'OpenRouter API Key',
                  icon: Icons.key_rounded,
                  controller: _openRouterKeyController,
                  obscure: true,
                ),
                _GlassTextField(
                  label: 'Modell (z.B. anthropic/claude-3.5-sonnet)',
                  icon: Icons.smart_toy_rounded,
                  controller: _openRouterModelController,
                ),
                _GlassTextField(
                  label: 'Fallback',
                  icon: Icons.backup_rounded,
                  controller: _openRouterFallbackController,
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
                  label: _isTestingOllama ? 'Teste...' : 'Verbindung testen',
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
              subtitle: 'v0.93.3',
              color: AppColors.secondary,
              trailing: _Badge('v0.93.3', color: AppColors.secondary),
              onTap: () {},
            ),
          ])),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
                Text(widget.expanded ? 'Angeklappt zur Bearbeitung' : 'Zum Bearbeiten aufklappen',
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
          secondChild: Column(children: [...widget.children, const SizedBox(height: 8)]),
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
                  maxLines: 1, overflow: TextOverflow.ellipsis),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        margin: const EdgeInsets.fromLTRB(16, 8, 0, 16),
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
        margin: const EdgeInsets.fromLTRB(0, 8, 16, 16),
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
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
