import 'tool_interface.dart';
import 'tool_result.dart';
import 'get_current_time_tool.dart';
import 'get_device_info_tool.dart';
import 'web_search_tool.dart';
import 'get_webpage_tool.dart';
import 'open_url_tool.dart';
import 'share_text_tool.dart';
import 'read_config_tool.dart';
import 'update_config_tool.dart';
import 'get_calendar_events_tool.dart';
import 'add_calendar_event_tool.dart';
import 'list_files_tool.dart';
import 'read_file_tool.dart';
import 'write_file_tool.dart';
import 'open_app_tool.dart';
import 'get_battery_info_tool.dart';
import 'get_clipboard_tool.dart';
import 'get_weather_tool.dart';
import 'navigate_to_tool.dart'; // New navigation tool (OSRM, offline-ready)
import 'music_intent_tool.dart';
import 'send_sms_tool.dart';
import 'send_whatsapp_tool.dart';
import 'search_contacts_tool.dart';
import 'send_message_to_contact_tool.dart';
import 'manage_contacts_tool.dart';
import 'phone_call_tool.dart';
import 'search_memories_tool.dart';
import '../services/memory_service.dart';
import 'update_self_identity_tool.dart';
import '../services/self_identity_service.dart';
import 'save_memory_tool.dart';

import 'buddy_notes_tool.dart';
import '../services/buddy_notes_service.dart';
import 'update_capabilities_tool.dart';
import '../services/buddy_capabilities_service.dart';
import 'get_location_tool.dart';
import '../services/location_service.dart';
import 'send_email_tool.dart';
import 'read_email_tool.dart';
import 'manage_shopping_list_tool.dart';
import 'set_reminder_tool.dart';
import 'set_timer_tool.dart';
import 'send_proactive_notification_tool.dart';
import 'delete_file_tool.dart';
import 'rename_file_tool.dart';
import 'analyze_image_tool.dart';
import 'set_volume_tool.dart';
import 'toggle_wifi_tool.dart';
import 'toggle_bluetooth_tool.dart';
import 'update_calendar_event_tool.dart';
import 'delete_calendar_event_tool.dart';
import 'record_voice_memo_tool.dart';
import 'automation_rule_tool.dart';
import '../services/tool_learning_service.dart';
import 'offline_stt_tool.dart';
import 'device_settings_tool.dart';
import 'open_file_tool.dart';
import 'manage_password_tool.dart';
import 'check_update_tool.dart';
import 'manage_apps_tool.dart';

class ToolRegistry {
  final Map<String, ToolInterface> _tools = {};
  void register(ToolInterface tool) {
    _tools[tool.definition.name] = tool;
  }

  ToolInterface? getTool(String name) => _tools[name];
  List<Map<String, dynamic>> getToolDefinitions() =>
      _tools.values.map((t) => t.definition.toApiJson()).toList();
  List<String> get toolNames => _tools.keys.toList();
  bool hasTool(String name) => _tools.containsKey(name);

  ToolLearningService? _learningService;

  void registerLearningService(ToolLearningService service) {
    _learningService = service;
  }

  /// Build a system-prompt extension that gives the LLM hints about
  /// tools it should avoid misusing. Returns empty string if nothing to say.
  String getToolHints() {
    final toolNames = _tools.keys.toList();
    return _learningService?.buildHintSection(toolNames) ?? '';
  }

  Future<ToolResult> execute(
      String name, Map<String, dynamic> parameters) async {
    final tool = _tools[name];
    if (tool == null) {
      final result = ToolResult(
          toolName: name,
          parameters: parameters,
          result: 'Unbekanntes Tool: $name',
          isError: true);
      _learningService?.recordFailure(name, 'unbekanntes Tool');
      return result;
    }
    try {
      final result = await tool.execute(parameters);
      if (result.isError) {
        _learningService?.recordFailure(
            name, result.result, usedParameters: parameters);
      } else {
        _learningService?.recordSuccess(name);
      }
      return result;
    } catch (e) {
      _learningService?.recordFailure(name, e.toString(), usedParameters: parameters);
      return ToolResult(
          toolName: name,
          parameters: parameters,
          result: 'Fehler bei Ausfuehrung von $name: $e',
          isError: true);
    }
  }

  /// Register the search_memories tool after registry creation
  /// (requires MemoryService which isn't available at createDefault time).
  void registerSearchMemories(MemoryService memory) {
    register(SearchMemoriesTool(memory));
  }

  /// Register the update_self_identity tool (requires SelfIdentityService).
  void registerSelfIdentity(SelfIdentityService selfIdentity) {
    register(UpdateSelfIdentityTool(selfIdentity));
  }

  /// Register the buddy_notes tool (requires BuddyNotesService).
  void registerBuddyNotes(BuddyNotesService notes) {
    register(BuddyNotesTool(notes));
  }

  /// Register the update_capabilities tool (requires BuddyCapabilitiesService).
  void registerBuddyCapabilities(BuddyCapabilitiesService capabilities) {
    register(UpdateCapabilitiesTool(capabilities));
  }

  /// Register the save_memory tool (requires MemoryService).
  void registerSaveMemory(MemoryService memory) {
    register(SaveMemoryTool(memory));
  }

  /// Register the get_location tool (requires LocationService).
  void registerLocation(LocationService location) {
    register(GetLocationTool(location));
  }

  static ToolRegistry createDefault(
      {String? Function()? rootPathProvider,
      String imapServer = 'imap.gmail.com',
      int imapPort = 993,
      String emailAddress = '',
      String emailPassword = '',
      bool imapUseSsl = true}) {
    final r = ToolRegistry();
    r.register(GetCurrentTimeTool());
    r.register(GetDeviceInfoTool());
    r.register(WebSearchTool());
    r.register(GetWebpageTool());
    r.register(OpenUrlTool());
    r.register(ShareTextTool());
    r.register(ReadConfigTool());
    r.register(UpdateConfigTool());
    r.register(GetCalendarEventsTool());
    r.register(AddCalendarEventTool());
    r.register(ListFilesTool(getRootPath: rootPathProvider));
    r.register(ReadFileTool(getRootPath: rootPathProvider));
    r.register(WriteFileTool(getRootPath: rootPathProvider));
    r.register(OpenAppTool());
    r.register(GetBatteryInfoTool());
    r.register(GetClipboardTool());
    r.register(GetWeatherTool());
    r.register(NavigateToTool()); // OSRM-based open-source navigation
    r.register(MusicIntentTool());
    r.register(SendSmsTool());
    r.register(SendWhatsAppTool());
    r.register(SearchContactsTool());
    r.register(SendMessageToContactTool());
    r.register(ManageContactsTool());
    r.register(PhoneCallTool());
    r.register(SendEmailTool());
    r.register(ReadEmailTool(
      server: imapServer,
      port: imapPort,
      email: emailAddress,
      password: emailPassword,
      useSsl: imapUseSsl,
    ));
    r.register(ManageShoppingListTool());
    // War nie registriert — main.dart setzte nur den Callback, das LLM
    // konnte set_reminder daher nicht aufrufen.
    r.register(SetReminderTool());
    r.register(SetTimerTool());
    r.register(SendProactiveNotificationTool());
    r.register(DeleteFileTool(getRootPath: rootPathProvider));
    r.register(RenameFileTool(getRootPath: rootPathProvider));
    r.register(AnalyzeImageTool(getRootPath: rootPathProvider));
    r.register(SetVolumeTool());
    r.register(ToggleWifiTool());
    r.register(ToggleBluetoothTool());
    r.register(UpdateCalendarEventTool());
    r.register(DeleteCalendarEventTool());
    r.register(RecordVoiceMemoTool());
    r.register(AutomationRuleTool());
    r.register(OfflineSttTool());
    r.register(DeviceSettingsTool());
    r.register(OpenFileTool());
    r.register(ManagePasswordTool());
    r.register(CheckUpdateTool());
    r.register(ManageAppsTool());
    return r;
  }
}
