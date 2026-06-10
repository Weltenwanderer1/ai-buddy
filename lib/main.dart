import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'screens/home_screen.dart';
import 'services/memory_service.dart';
import 'services/persona_service.dart';
import 'services/settings_service.dart';
import 'services/chat_history_service.dart';
import 'services/secure_config_service.dart';
import 'services/tts_playback_service.dart';
import 'services/piper_tts_service.dart';
import 'services/persona_evolution_service.dart';
import 'services/self_identity_service.dart';
import 'services/buddy_notes_service.dart';
import 'services/buddy_capabilities_service.dart';
import 'services/notification_service.dart';
import 'services/timer_service.dart';
import 'services/proactive_notification_service.dart';
import 'services/fcm_service.dart';
import 'services/volume_service.dart';
import 'services/voice_recorder_service.dart';
import 'services/automation_service.dart';
import 'services/offline_stt_service.dart';
import 'services/buddy_scheduler.dart';
import 'services/buddy_notifier.dart';
import 'services/backup_service.dart';
import 'services/location_service.dart';
import 'services/ollama_cloud_service.dart';
import 'services/clipboard_history_service.dart';
import 'services/password_service.dart';
import 'services/update_service.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:share_plus/share_plus.dart' as share_plus;
import 'package:image_picker/image_picker.dart';
import 'tools/tool_registry.dart';
import 'tools/set_reminder_tool.dart';
import 'tools/set_timer_tool.dart';
import 'tools/send_proactive_notification_tool.dart';
import 'tools/set_volume_tool.dart';
import 'tools/analyze_image_tool.dart';
import 'tools/update_calendar_event_tool.dart';
import 'tools/delete_calendar_event_tool.dart';
import 'tools/record_voice_memo_tool.dart';
import 'tools/automation_rule_tool.dart';
import 'tools/offline_stt_tool.dart';
import 'tools/manage_password_tool.dart';
import 'tools/check_update_tool.dart';
import 'tools/open_url_tool.dart';
import 'tools/share_text_tool.dart';
import 'tools/read_config_tool.dart';
import 'tools/update_config_tool.dart';
import 'services/tool_learning_service.dart';
import 'tools/get_calendar_events_tool.dart';
import 'tools/add_calendar_event_tool.dart';
import 'tools/get_clipboard_tool.dart';
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
  late PiperTtsService _piperTtsService;
  late TtsPlaybackService _ttsPlaybackService;
  late PersonaEvolutionService _personaEvolution;
  late BuddyNotesService _buddyNotes;
  late BuddyCapabilitiesService _buddyCapabilities;
  late ToolRegistry _toolRegistry;
  late NotificationService _notificationService;
  late TimerService _timerService;
  late ProactiveNotificationService _proactiveNotificationService;
  late FcmService _fcmService;
  late VolumeService _volumeService;
  late VoiceRecorderService _voiceRecorderService;
  late AutomationService _automationService;
  late OfflineSttService _offlineSttService;
  late BuddyScheduler _buddyScheduler;
  late BackupService _backupService;
  late LocationService _locationService;
  late OllamaCloudService _cloudService;
  late ToolLearningService _toolLearning;
  late ClipboardHistoryService _clipboardHistory;
  late PasswordService _passwordService;

  @override
  void initState() { super.initState(); _initServices(); }

  @override
  void dispose() {
    if (_initialized) {
      _persona.removeListener(_onPersonaChanged);
      _ttsPlaybackService.dispose();
      _settings.dispose(); _memory.dispose(); _persona.dispose();
      _chatHistory.dispose(); _personaEvolution.dispose();
      _selfIdentity.dispose(); _buddyNotes.dispose(); _buddyCapabilities.dispose();
      _notificationService.dispose();
      _timerService.dispose();
      _proactiveNotificationService.dispose();
      _automationService.dispose();
      _buddyScheduler.dispose();
      _cloudService.dispose();
      _toolLearning.dispose();
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
      await _memory.init();
      _persona = PersonaService(); await _persona.init();
      // Use buddy name from config if persona has no name
      if (_persona.name.isEmpty) {
        _persona.name = _secureConfig.buddyName;
      }
      _selfIdentity = SelfIdentityService(); await _selfIdentity.init();
      _buddyNotes = BuddyNotesService(); await _buddyNotes.init();
      _buddyCapabilities = BuddyCapabilitiesService(); await _buddyCapabilities.init();
      _chatHistory = ChatHistoryService(); await _chatHistory.init();
      _piperTtsService = PiperTtsService();
      _ttsPlaybackService = TtsPlaybackService(_piperTtsService);
      await _ttsPlaybackService.loadEnginePreference(_secureConfig);
      _personaEvolution = PersonaEvolutionService();
      try { await _personaEvolution.init(); } catch (e) { debugPrint('Evolution init: $e'); }
      _notificationService = NotificationService();
      try { await _notificationService.init(); } catch (e) { debugPrint('Notify init: $e'); }

      _timerService = TimerService();
      try { await _timerService.init(); } catch (e) { debugPrint('Timer init: $e'); }

      _proactiveNotificationService = ProactiveNotificationService();
      try { await _proactiveNotificationService.init(); } catch (e) { debugPrint('ProactiveNotify init: $e'); }

      _fcmService = FcmService();
      try { await _fcmService.init(); } catch (e) { debugPrint('FCM init: $e'); }

      _volumeService = VolumeService();

      _voiceRecorderService = VoiceRecorderService();

      _automationService = AutomationService();
      try { await _automationService.init(); } catch (e) { debugPrint('Automation init: $e'); }

      _offlineSttService = OfflineSttService();
      try { await _offlineSttService.checkOfflineAvailability(); } catch (e) { debugPrint('OfflineSTT init: $e'); }

      _toolLearning = ToolLearningService();
      try { await _toolLearning.init(); } catch (e) { debugPrint('ToolLearning init: $e'); }

      _clipboardHistory = ClipboardHistoryService();
      try { await _clipboardHistory.init(); } catch (e) { debugPrint('ClipboardHistory init: $e'); }
      try { await _clipboardHistory.capture(); } catch (e) { debugPrint('Clipboard capture: $e'); }

      _buddyScheduler = BuddyScheduler();
      try { await _buddyScheduler.init(); } catch (e) { debugPrint('Scheduler init: $e'); }

      BuddyNotifier.init();

      _locationService = LocationService();

      final appDocDir = await getApplicationDocumentsDirectory();
      final rootPath = appDocDir.path;

      // ToolRegistry FIRST (needed by ChatService)
      _toolRegistry = ToolRegistry.createDefault(
        tavilyApiKey: _secureConfig.tavilyApiKey.isNotEmpty ? _secureConfig.tavilyApiKey : null,
        rootPathProvider: () => rootPath,
      );
      _toolRegistry.registerLocation(_locationService);
      _toolRegistry.registerBuddyCapabilities(_buddyCapabilities);
      _toolRegistry.registerSearchMemories(_memory);
      _toolRegistry.registerSelfIdentity(_selfIdentity);
      _toolRegistry.registerBuddyNotes(_buddyNotes);
      _toolRegistry.registerSaveMemory(_memory);
      _toolRegistry.registerLearningService(_toolLearning);

      _cloudService = OllamaCloudService(
        baseUrl: _secureConfig.activeBaseUrl,
        apiKey: _secureConfig.activeApiKey,
        defaultModel: _secureConfig.activeModel,
        fallbackModel: _secureConfig.activeFallbackModel,
      );

      SetReminderTool.scheduleCallback = ({required title, required body, required scheduledTime}) {
        return _notificationService.scheduleNotification(title: title, body: body, scheduledTime: scheduledTime);
      };

      SetTimerTool.setTimerCallback = ({required label, required durationSeconds}) {
        return _timerService.startTimer(label: label, durationSeconds: durationSeconds);
      };
      SetTimerTool.listTimersCallback = () async {
        return _timerService.listTimers();
      };
      SetTimerTool.cancelTimerCallback = ({required timerId}) {
        return _timerService.cancelTimer(timerId);
      };

      _passwordService = PasswordService();
      ManagePasswordTool.passwordService = _passwordService;

      final updateService = UpdateService();
      CheckUpdateTool.updateService = updateService;

      SetVolumeTool.setVolumeCallback = ({required stream, required level}) {
        return _volumeService.setVolume(stream, level);
      };
      SetVolumeTool.getVolumeCallback = ({required stream}) {
        return _volumeService.getVolume(stream);
      };
      SetVolumeTool.muteCallback = ({required mute}) {
        return _volumeService.setMute(mute);
      };

      RecordVoiceMemoTool.startRecordingCallback = () {
        return _voiceRecorderService.startRecording();
      };
      RecordVoiceMemoTool.stopRecordingCallback = () {
        return _voiceRecorderService.stopRecording();
      };
      RecordVoiceMemoTool.listMemosCallback = () async {
        final files = await _voiceRecorderService.listMemos();
        return files.map((f) => {
          'path': f.path,
          'name': f.path.split('/').last,
          'sizeBytes': 0,
        }).toList();
      };
      RecordVoiceMemoTool.deleteMemoCallback = ({required path}) {
        return _voiceRecorderService.deleteMemo(path);
      };

      AutomationRuleTool.createRuleCallback = ({required name, required trigger, required actions}) async {
        try {
          final rule = AutomationRule(
            id: const Uuid().v4().substring(0, 8),
            name: name,
            trigger: AutomationTrigger(
              type: AutomationTriggerType.values.firstWhere(
                (t) => t.name == trigger['type'],
                orElse: () => AutomationTriggerType.timeOfDay,
              ),
              params: (trigger['params'] as Map<String, dynamic>?) ?? {},
            ),
            actions: actions.map((a) => AutomationAction(
              type: AutomationActionType.values.firstWhere(
                (t) => t.name == a['type'],
                orElse: () => AutomationActionType.custom,
              ),
              params: (a['params'] as Map<String, dynamic>?) ?? {},
            )).toList(),
          );
          await _automationService.addRule(rule);
          return true;
        } catch (e) {
          debugPrint('Automation create error: $e');
          return false;
        }
      };
      AutomationRuleTool.listRulesCallback = () async {
        return _automationService.rules.map((r) => {
          'id': r.id,
          'name': r.name,
          'enabled': r.enabled,
          'trigger_type': r.trigger.type.name,
        }).toList();
      };
      AutomationRuleTool.updateRuleCallback = ({required ruleId, name, trigger, actions}) async {
        try {
          final existing = _automationService.rules.where((r) => r.id == ruleId).firstOrNull;
          if (existing == null) return false;
          final updated = AutomationRule(
            id: existing.id,
            name: name ?? existing.name,
            enabled: existing.enabled,
            trigger: trigger != null
                ? AutomationTrigger(
                    type: AutomationTriggerType.values.firstWhere(
                      (t) => t.name == trigger['type'],
                      orElse: () => existing.trigger.type,
                    ),
                    params: (trigger['params'] as Map<String, dynamic>?) ?? existing.trigger.params,
                  )
                : existing.trigger,
            actions: actions != null
                ? actions.map((a) => AutomationAction(
                    type: AutomationActionType.values.firstWhere(
                      (t) => t.name == a['type'],
                      orElse: () => AutomationActionType.custom,
                    ),
                    params: (a['params'] as Map<String, dynamic>?) ?? {},
                  )).toList()
                : existing.actions,
            createdAt: existing.createdAt,
            lastFired: existing.lastFired,
          );
          await _automationService.updateRule(ruleId, updated);
          return true;
        } catch (e) {
          debugPrint('Automation update error: $e');
          return false;
        }
      };
      AutomationRuleTool.deleteRuleCallback = ({required ruleId}) async {
        try {
          await _automationService.deleteRule(ruleId);
          return true;
        } catch (e) {
          return false;
        }
      };
      AutomationRuleTool.toggleRuleCallback = ({required ruleId, required enabled}) async {
        try {
          await _automationService.toggleRule(ruleId, enabled);
          return true;
        } catch (e) {
          return false;
        }
      };

      OfflineSttTool.checkOfflineCallback = () {
        return _offlineSttService.checkOfflineAvailability();
      };
      OfflineSttTool.listenCallback = ({preferOffline = true, localeId = 'de_DE'}) {
        return _offlineSttService.startListening(
          preferOffline: preferOffline,
          localeId: localeId,
        );
      };
      OfflineSttTool.stopListeningCallback = () {
        return _offlineSttService.stop();
      };
      OfflineSttTool.promptDownloadCallback = () {
        return _offlineSttService.promptDownloadOfflineLanguage();
      };

      SendProactiveNotificationTool.sendCallback = ({required title, required body, priority, actions}) async {
        try {
          await _proactiveNotificationService.sendNotification(
            type: ProactiveNotificationType.custom,
            title: title,
            body: body,
            actions: (actions ?? []).map((a) => ProactiveAction(
              id: a['id'] ?? '',
              label: a['label'] ?? '',
            )).toList(),
          );
          return true;
        } catch (e) {
          debugPrint('ProactiveNotification error: $e');
          return false;
        }
      };
      OpenUrlTool.launchCallback = (url) async {
        try { final uri = Uri.parse(url); return await url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication); }
        catch (e) { debugPrint('OpenUrl error: $e'); return false; }
      };
      ShareTextTool.shareCallback = (text, subject) async {
        try { await share_plus.Share.share(text, subject: subject); } catch (e) { debugPrint('Share error: $e'); }
      };
      GetClipboardTool.readClipboardCallback = () async {
        return _clipboardHistory.readCurrent();
      };
      GetClipboardTool.getHistoryCallback = ({int limit = 10}) {
        return _clipboardHistory.getHistoryForLLM(limit: limit);
      };

      // Image picker callbacks for AnalyzeImageTool
      final imagePicker = ImagePicker();
      AnalyzeImageTool.pickFromCameraCallback = () async {
        try {
          final xfile = await imagePicker.pickImage(source: ImageSource.camera, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
          return xfile?.path;
        } catch (e) {
          debugPrint('Camera pick error: $e');
          return null;
        }
      };
      AnalyzeImageTool.pickFromGalleryCallback = () async {
        try {
          final xfile = await imagePicker.pickImage(source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
          return xfile?.path;
        } catch (e) {
          debugPrint('Gallery pick error: $e');
          return null;
        }
      };
      AnalyzeImageTool.analyzeCallback = ({required imagePath, question}) async {
        // Vision analysis via the cloud LLM service
        // For now, return a placeholder — the actual Vision API integration
        // depends on the LLM provider supporting image inputs.
        try {
          final file = File(imagePath);
          if (!await file.exists()) return 'Bild nicht gefunden: $imagePath';
          final bytes = await file.readAsBytes();
          final sizeKB = bytes.length ~/ 1024;
          return 'Bild analysiert: $imagePath (${sizeKB}KB). '
              'Frage: ${question ?? "Was ist auf dem Bild?"}. '
              'Hinweis: Vision-API-Integration erfordert LLM mit Bild-Unterstützung.';
        } catch (e) {
          return 'Fehler bei der Bildanalyse: $e';
        }
      };

      ReadConfigTool.readConfigCallback = () => {
        'persona_name': _persona.name,
        'default_model': _secureConfig.activeModel,
        'tts_engine': _secureConfig.ttsEngine,
        'temperature': _settings['temperature'] ?? 0.7,
        'memory_ttl_minutes': _settings['memory_ttl_minutes'] ?? 60,
        'memory_promotion_threshold': _settings['memory_promotion_threshold'] ?? 3,
        'max_history': _settings['max_history'] ?? 20,
      };

      UpdateConfigTool.updateConfigCallback = (key, value) async {
        try {
          switch (key) {
            case 'persona_name': await _persona.save(name: value.toString(), personality: _persona.personality, greeting: _persona.greeting, backstory: _persona.backstory); return true;
            case 'default_model': return true; // model selected in settings
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
      AddCalendarEventTool.addEventCallback = ({required String title, required DateTime start, required DateTime end, String? description, String? location, String? recurrence, int? recurrenceCount, DateTime? recurrenceEnd, List<DateTime>? excludedDates}) async {
        try { return await _addCalendarEvent(title: title, start: start, end: end, description: description, location: location, recurrence: recurrence, recurrenceCount: recurrenceCount, recurrenceEnd: recurrenceEnd, excludedDates: excludedDates); }
        catch (e) { debugPrint('AddCal error: $e'); return false; }
      };
      UpdateCalendarEventTool.updateEventCallback = ({required eventId, title, start, end, description, location}) async {
        try { return await _updateCalendarEvent(eventId: eventId, title: title, start: start, end: end, description: description, location: location); }
        catch (e) { debugPrint('UpdateCal error: $e'); return false; }
      };
      DeleteCalendarEventTool.deleteEventCallback = ({required eventId}) async {
        try { return await _deleteCalendarEvent(eventId: eventId); }
        catch (e) { debugPrint('DeleteCal error: $e'); return false; }
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
              'id': event.eventId ?? '',
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

  Future<bool> _addCalendarEvent({required String title, required DateTime start, required DateTime end, String? description, String? location, String? recurrence, int? recurrenceCount, DateTime? recurrenceEnd, List<DateTime>? excludedDates}) async {
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

      // Build recurrence rule if requested
      RecurrenceRule? rrule;
      if (recurrence != null && recurrence.isNotEmpty) {
        RecurrenceFrequency freq;
        int interval = 1;

        switch (recurrence) {
          case 'daily':
            freq = RecurrenceFrequency.Daily;
          case 'weekly':
            freq = RecurrenceFrequency.Weekly;
          case 'biweekly':
            freq = RecurrenceFrequency.Weekly;
            interval = 2;
          case 'weekday':
            freq = RecurrenceFrequency.Weekly;
          case 'monthly':
            freq = RecurrenceFrequency.Monthly;
          case 'yearly':
            freq = RecurrenceFrequency.Yearly;
          case 'every_2nd_monday':
            freq = RecurrenceFrequency.Weekly;
            interval = 2;
          default:
            freq = RecurrenceFrequency.Daily;
        }

        rrule = RecurrenceRule(
          freq,
          interval: interval,
          endDate: recurrenceEnd != null ? tz.TZDateTime.from(recurrenceEnd, tz.local) : null,
          totalOccurrences: recurrenceCount,
        );

        // For "weekday" only, only Mon-Fri
        if (recurrence == 'weekday') {
          rrule.daysOfWeek = [
            DayOfWeek.Monday,
            DayOfWeek.Tuesday,
            DayOfWeek.Wednesday,
            DayOfWeek.Thursday,
            DayOfWeek.Friday,
          ];
        }
      }

      final event = Event(
        cal.id,
        title: title,
        start: tzStart,
        end: tzEnd,
        description: description,
        location: location,
      );
      if (rrule != null) {
        event.recurrenceRule = rrule;
      }

      final result = await deviceCal.createOrUpdateEvent(event);
      return result?.isSuccess ?? false;
    } catch (e) {
      debugPrint('Calendar add error: $e');
      return false;
    }
  }

  Future<bool> _updateCalendarEvent({required String eventId, String? title, DateTime? start, DateTime? end, String? description, String? location}) async {
    try {
      final status = await Permission.calendarFullAccess.request();
      if (!status.isGranted && !status.isLimited) return false;
      final deviceCal = DeviceCalendarPlugin();
      final calendarsResult = await deviceCal.retrieveCalendars();
      if (!calendarsResult.isSuccess || calendarsResult.data == null || calendarsResult.data!.isEmpty) return false;

      // Find the event across all calendars
      for (final cal in calendarsResult.data!) {
        final eventsResult = await deviceCal.retrieveEvents(
          cal.id!,
          RetrieveEventsParams(startDate: DateTime(2020), endDate: DateTime(2030)),
        );
        if (eventsResult.isSuccess && eventsResult.data != null) {
          for (final event in eventsResult.data!) {
            if (event.eventId == eventId) {
              // Update fields
              final updatedEvent = Event(
                cal.id,
                eventId: eventId,
                title: title ?? event.title,
                start: start != null ? tz.TZDateTime.from(start, tz.local) : event.start,
                end: end != null ? tz.TZDateTime.from(end, tz.local) : event.end,
                description: description ?? event.description,
                location: location ?? event.location,
              );
              // Serien-Regel beibehalten — sonst macht ein Update aus einem
              // wiederkehrenden Termin einen Einzeltermin.
              updatedEvent.recurrenceRule = event.recurrenceRule;
              final result = await deviceCal.createOrUpdateEvent(updatedEvent);
              return result?.isSuccess ?? false;
            }
          }
        }
      }
      debugPrint('Calendar event not found: $eventId');
      return false;
    } catch (e) {
      debugPrint('Calendar update error: $e');
      return false;
    }
  }

  Future<bool> _deleteCalendarEvent({required String eventId}) async {
    try {
      final status = await Permission.calendarFullAccess.request();
      if (!status.isGranted && !status.isLimited) return false;
      final deviceCal = DeviceCalendarPlugin();
      final calendarsResult = await deviceCal.retrieveCalendars();
      if (!calendarsResult.isSuccess || calendarsResult.data == null || calendarsResult.data!.isEmpty) return false;

      // Find and delete the event across all calendars
      for (final cal in calendarsResult.data!) {
        final eventsResult = await deviceCal.retrieveEvents(
          cal.id!,
          RetrieveEventsParams(startDate: DateTime(2020), endDate: DateTime(2030)),
        );
        if (eventsResult.isSuccess && eventsResult.data != null) {
          for (final event in eventsResult.data!) {
            if (event.eventId == eventId) {
              final result = await deviceCal.deleteEvent(cal.id!, eventId);
              return result.isSuccess;
            }
          }
        }
      }
      debugPrint('Calendar event not found for delete: $eventId');
      return false;
    } catch (e) {
      debugPrint('Calendar delete error: $e');
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
        ChangeNotifierProvider.value(value: _personaEvolution),
        ChangeNotifierProvider.value(value: _selfIdentity),
        ChangeNotifierProvider.value(value: _buddyNotes),
        ChangeNotifierProvider.value(value: _buddyCapabilities),
        ChangeNotifierProvider.value(value: _piperTtsService), Provider.value(value: _secureConfig),
        ChangeNotifierProvider.value(value: _ttsPlaybackService),
        Provider.value(value: _cloudService),
        Provider.value(value: _toolRegistry),
        Provider.value(value: _backupService),
        ChangeNotifierProvider.value(value: _locationService),
        ChangeNotifierProvider.value(value: _buddyScheduler),
        ChangeNotifierProvider.value(value: _timerService),
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
