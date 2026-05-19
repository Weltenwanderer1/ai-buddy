import 'tool_interface.dart';
import 'tool_result.dart';
import 'get_current_time_tool.dart';
import 'get_device_info_tool.dart';
import 'web_search_tool.dart';
import 'get_webpage_tool.dart';
import 'set_reminder_tool.dart';
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
import 'search_memories_tool.dart';
import '../services/memory_service.dart';
import 'update_self_identity_tool.dart';
import '../services/self_identity_service.dart';
import 'save_memory_tool.dart';

import 'buddy_notes_tool.dart';
import '../services/buddy_notes_service.dart';
import 'get_location_tool.dart';
import '../services/location_service.dart';

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

  Future<ToolResult> execute(
      String name, Map<String, dynamic> parameters) async {
    final tool = _tools[name];
    if (tool == null) {
      return ToolResult(
          toolName: name,
          parameters: parameters,
          result: 'Unbekanntes Tool: $name',
          isError: true);
    }
    try {
      return await tool.execute(parameters);
    } catch (e) {
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

  /// Register the save_memory tool (requires MemoryService).
  void registerSaveMemory(MemoryService memory) {
    register(SaveMemoryTool(memory));
  }

  /// Register the get_location tool (requires LocationService).
  void registerLocation(LocationService location) {
    register(GetLocationTool(location));
  }

  static ToolRegistry createDefault(
      {String? tavilyApiKey, String? Function()? rootPathProvider}) {
    final r = ToolRegistry();
    r.register(GetCurrentTimeTool());
    r.register(GetDeviceInfoTool());
    r.register(WebSearchTool(apiKey: tavilyApiKey));
    r.register(GetWebpageTool());
    r.register(SetReminderTool());
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
    return r;
  }
}
