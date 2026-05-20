import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'screens/home_screen.dart';
import 'services/memory_service.dart';
import 'services/persona_service.dart';
import 'services/settings_service.dart';
import 'services/chat_history_service.dart';
import 'services/secure_config_service.dart';
import 'services/ollama_cloud_service.dart';
import 'services/elevenlabs_service.dart';
import 'services/tts_playback_service.dart';
import 'services/openrouter_tts_service.dart';
import 'services/persona_evolution_service.dart';
import 'services/self_identity_service.dart';
import 'services/buddy_notes_service.dart';
import 'services/notification_service.dart';
import 'services/backup_service.dart';
import 'services/location_service.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:share_plus/share_plus.dart' as share_plus;
import 'tools/tool_registry.dart';
import 'tools/set_reminder_tool.dart';
import 'tools/open_url_tool.dart';
import 'tools/share_text_tool.dart';
import 'tools/read_config_tool.dart';
import 'tools/update_config_tool.dart';
import 'tools/get_calendar_events_tool.dart';
import 'tools/add_calendar_event_tool.dart';
import 'tools/get_clipboard_tool.dart';
import 'services/embedding_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AIBuddyApp());
}

class AIBuddyApp extends StatefulWidget {
  const AIBuddyApp({super.key});
  @override
  State<AIBuddyApp> createState() => _AIBuddyAppState();
}

class _AIBuddyAppState extends State<AIBuddyApp> {
  bool _initialized = false;
  String? _error;
  late SettingsService _settings;
  late MemoryService _memory;
  late PersonaService _persona;
  late SelfIdentityService _selfIdentity;
  late ChatHistoryService _chatHistory;
  late SecureConfigService _secureConfig;
  late OllamaCloudService _ollamaService;
  late ElevenLabsService _elevenLabsService;
  late TtsPlaybackService _ttsPlaybackService;
  late PersonaEvolutionService _personaEvolution;
  late BuddyNotesService _buddyNotes;
  late ToolRegistry _toolRegistry;
  late NotificationService _notificationService;
  late BackupService _backupService;
  late LocationService _locationService;

  @override
  void initState() { super.initState(); _initServices(); }

  @override
  void dispose() {
    if (_initialized) {
      _persona.removeListener(_onPersonaChanged);
      _ttsPlaybackService.dispose(); _ollamaService.dispose();
      _settings.dispose(); _memory.dispose(); _persona.dispose();
      _chatHistory.dispose(); _personaEvolution.dispose();
      _selfIdentity.dispose(); _buddyNotes.dispose();
      _notificationService.dispose();
    }
    super.dispose();
  }

  void _onPersonaChanged() => setState(() {});

  Future<void> _initServices() async {
    try {
      try { await dotenv.load(fileName: '.env', isOptional: true); } catch (_) {}
      _secureConfig = SecureConfigService(); await _secureConfig.init();
      _settings = SettingsService(); await _settings.init();
      _memory = MemoryService(
        promotionThreshold: _settings['memory_promotion_threshold'] as int? ?? 3,
        ttl: Duration(minutes: _settings['memory_ttl_minutes'] as int? ?? 60),
      );
      if (_secureConfig.ollamaBaseUrl.contains('127.0.0.1') || _secureConfig.ollamaBaseUrl.contains('localhost')) {
        _memory.setEmbeddingService(EmbeddingService(
          baseUrl: _secureConfig.ollamaBaseUrl.replaceAll(RegExp(r'/api$'), ''),
        ));
      }
      await _memory.init();
      _persona = PersonaService(); await _persona.init();
      _selfIdentity = SelfIdentityService(); await _selfIdentity.init();
      _buddyNotes = BuddyNotesService(); await _buddyNotes.init();
      _chatHistory = ChatHistoryService(); await _chatHistory.init();
      _ollamaService = OllamaCloudService(
        baseUrl: _secureConfig.activeBaseUrl,
        apiKey: _secureConfig.activeApiKey,
        defaultModel: _secureConfig.activeModel,
        fallbackModel: _secureConfig.activeFallbackModel,
      );
      // Warm up TCP/TLS connection before first user message
      _ollamaService.preconnect();
      _elevenLabsService = ElevenLabsService(
        apiKey: _secureConfig.elevenLabsApiKey, voiceId: _secureConfig.elevenLabsVoiceId,
        modelId: _secureConfig.elevenLabsModelId,
      );
      final openRouterTts = OpenRouterTtsService(
        apiKey: _secureConfig.openRouterApiKey,
        model: _secureConfig.openRouterTtsModel,
        voice: _secureConfig.openRouterTtsVoice,
      );
      _ttsPlaybackService = TtsPlaybackService(_elevenLabsService, openRouterTts);
      await _ttsPlaybackService.loadEnginePreference(_secureConfig);
      _personaEvolution = PersonaEvolutionService(_ollamaService);
      try { await _personaEvolution.init(); } catch (e) { debugPrint('Evolution init: $e'); }
      _notificationService = NotificationService();
      try { await _notificationService.init(); } catch (e) { debugPrint('Notify init: $e'); }

      _locationService = LocationService();

      final appDocDir = await getApplicationDocumentsDirectory();
      final rootPath = appDocDir.path;

      _toolRegistry = ToolRegistry.createDefault(
        tavilyApiKey: _secureConfig.tavilyApiKey.isNotEmpty ? _secureConfig.tavilyApiKey : null,
        rootPathProvider: () => rootPath,
      );
      _toolRegistry.registerLocation(_locationService);

      SetReminderTool.scheduleCallback = ({required title, required body, required scheduledTime}) {
        return _notificationService.scheduleNotification(title: title, body: body, scheduledTime: scheduledTime);
      };
      OpenUrlTool.launchCallback = (url) async {
        try { final uri = Uri.parse(url); return await url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication); }
        catch (e) { debugPrint('OpenUrl error: $e'); return false; }
      };
      ShareTextTool.shareCallback = (text, subject) async {
        try { await share_plus.Share.share(text, subject: subject); } catch (e) { debugPrint('Share error: $e'); }
      };
      GetClipboardTool.readClipboardCallback = () async { return null; };

      ReadConfigTool.readConfigCallback = () => {
        'persona_name': _persona.name, 'default_model': _ollamaService.defaultModel,
        'tts_engine': _secureConfig.ttsEngine, 'temperature': _settings['temperature'] ?? 0.7,
        'memory_ttl_minutes': _settings['memory_ttl_minutes'] ?? 60,
        'memory_promotion_threshold': _settings['memory_promotion_threshold'] ?? 3,
        'max_history': _settings['max_history'] ?? 20,
      };

      UpdateConfigTool.updateConfigCallback = (key, value) async {
        try {
          switch (key) {
            case 'persona_name': await _persona.save(name: value.toString(), personality: _persona.personality, greeting: _persona.greeting, backstory: _persona.backstory); return true;
            case 'default_model': await _secureConfig.setOllamaModel(value.toString()); _ollamaService.updateConfig(defaultModel: value.toString()); return true;
            case 'tts_engine': await _secureConfig.setTtsEngine(value.toString()); return true;
            case 'temperature': _settings['temperature'] = double.tryParse(value.toString()) ?? 0.7; return true;
            case 'memory_ttl_minutes': _settings['memory_ttl_minutes'] = int.tryParse(value.toString()) ?? 60; return true;
            case 'memory_promotion_threshold': _settings['memory_promotion_threshold'] = int.tryParse(value.toString()) ?? 3; return true;
            case 'max_history': _settings['max_history'] = int.tryParse(value.toString()) ?? 20; return true;
            default: return false;
          }
        } catch (e) { debugPrint('UpdateConfig error: $e'); return false; }
      };

      GetCalendarEventsTool.getEventsCallback = ({daysAhead = 7}) async {
        try { return await _getCalendarEvents(daysAhead); } catch (e) { debugPrint('Cal error: $e'); return []; }
      };
      AddCalendarEventTool.addEventCallback = ({required title, required start, required end, description, location}) async {
        try { return await _addCalendarEvent(title: title, start: start, end: end, description: description, location: location); }
        catch (e) { debugPrint('AddCal error: $e'); return false; }
      };

      _backupService = BackupService(
        memory: _memory,
        persona: _persona,
        settings: _settings,
        chatHistory: _chatHistory,
        personaEvolution: _personaEvolution,
        selfIdentity: _selfIdentity,
      );

      if (mounted) { _persona.addListener(_onPersonaChanged); setState(() => _initialized = true); }
    } catch (e, st) {
      debugPrint('Init failed: $e\n$st');
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<List<Map<String, dynamic>>> _getCalendarEvents(int daysAhead) async {
    try {
      final status = await Permission.calendarFullAccess.request();
      if (!status.isGranted && !status.isLimited) {
        debugPrint('Calendar permission denied: $status');
        return [];
      }
      final deviceCal = DeviceCalendarPlugin();
      final calendarsResult = await deviceCal.retrieveCalendars();
      if (!calendarsResult.isSuccess || calendarsResult.data == null || calendarsResult.data!.isEmpty) {
        debugPrint('No calendars found');
        return [];
      }
      final now = DateTime.now();
      final end = now.add(Duration(days: daysAhead));
      final events = <Map<String, dynamic>>[];
      // Query all available calendars
      for (final cal in calendarsResult.data!) {
        final eventsResult = await deviceCal.retrieveEvents(
          cal.id!,
          RetrieveEventsParams(startDate: now, endDate: end),
        );
        if (eventsResult.isSuccess && eventsResult.data != null) {
          for (final event in eventsResult.data!) {
            final start = event.start?.toLocal() ?? now;
            final endEvt = event.end?.toLocal() ?? start.add(const Duration(hours: 1));
            events.add({
              'title': event.title ?? '(Ohne Titel)',
              'start': _formatDateTime(start),
              'end': _formatDateTime(endEvt),
              'location': event.location,
              'calendar': cal.name,
            });
          }
        }
      }
      events.sort((a, b) => a['start'].toString().compareTo(b['start'].toString()));
      return events;
    } catch (e) {
      debugPrint('Calendar read error: $e');
      return [];
    }
  }

  Future<bool> _addCalendarEvent({required String title, required DateTime start, required DateTime end, String? description, String? location}) async {
    try {
      final status = await Permission.calendarFullAccess.request();
      if (!status.isGranted && !status.isLimited) {
        debugPrint('Calendar permission denied: $status');
        return false;
      }
      final deviceCal = DeviceCalendarPlugin();
      final calendarsResult = await deviceCal.retrieveCalendars();
      if (!calendarsResult.isSuccess || calendarsResult.data == null || calendarsResult.data!.isEmpty) {
        debugPrint('No calendars found');
        return false;
      }
      // Use the first writable calendar
      final cal = calendarsResult.data!.first;
      final tzStart = tz.TZDateTime.from(start, tz.local);
      final tzEnd = tz.TZDateTime.from(end, tz.local);
      final event = Event(
        cal.id,
        title: title,
        start: tzStart,
        end: tzEnd,
        description: description,
        location: location,
      );
      final result = await deviceCal.createOrUpdateEvent(event);
      return result?.isSuccess ?? false;
    } catch (e) {
      debugPrint('Calendar add error: $e');
      return false;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  ThemeData _theme() => AppTheme.dark();

  @override
  Widget build(BuildContext context) {
    if (_error != null) return MaterialApp(title: 'AI-Buddy', theme: _theme(), darkTheme: _theme(), home: _ErrorScreen(error: _error!, onRetry: () { setState(() => _error = null); _initServices(); }));
    if (!_initialized) return MaterialApp(title: 'AI-Buddy', theme: _theme(), darkTheme: _theme(), home: const _StartupScreen());
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _settings), ChangeNotifierProvider.value(value: _memory),
        ChangeNotifierProvider.value(value: _persona), ChangeNotifierProvider.value(value: _chatHistory),
        ChangeNotifierProvider.value(value: _ollamaService), ChangeNotifierProvider.value(value: _personaEvolution),
        ChangeNotifierProvider.value(value: _selfIdentity),
        ChangeNotifierProvider.value(value: _buddyNotes),
        Provider.value(value: _elevenLabsService), Provider.value(value: _secureConfig),
        ChangeNotifierProvider.value(value: _ttsPlaybackService), Provider.value(value: _toolRegistry),
        Provider.value(value: _backupService),
        ChangeNotifierProvider.value(value: _locationService),
      ],
      child: MaterialApp(title: 'AI-Buddy', theme: _theme(), darkTheme: _theme(),
        home: const HomeScreen(),
      ),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: AppColors.bgGradient),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Color(0x668B5CF6), blurRadius: 24, spreadRadius: -4),
            ],
          ),
          child: const Icon(Icons.auto_awesome, size: 36, color: Colors.white),
        ),
        const SizedBox(height: 24),
        const Text('AI-Buddy', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5)),
        const SizedBox(height: 8),
        Text('Dein KI-Companion', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 32),
        const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)),
      ])),
    ),
  );
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorScreen({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: AppColors.bgGradient),
      child: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(Icons.error_outline, size: 32, color: AppColors.error.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: 16),
        const Text('Start fehlgeschlagen', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        Text(error, style: TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.all(Radius.circular(16))),
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Erneut versuchen', style: TextStyle(color: Colors.white)),
            style: FilledButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
          ),
        ),
      ]))),
    ),
  );
}
