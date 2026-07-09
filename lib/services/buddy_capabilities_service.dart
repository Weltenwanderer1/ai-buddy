import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Wissen darüber, was die KI alles kann.
/// Wird in jeden System-Prompt eingefügt.
/// KI kann lesen/schreiben. User kann in Settings editieren.
class BuddyCapabilitiesService extends ChangeNotifier {
  String _capabilities = '';
  File? _file;

  String get capabilities => _capabilities;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/ai_buddy/buddy_capabilities.txt');
    await _load();
    notifyListeners();
  }

  Future<void> _load() async {
    final file = _file;
    if (file == null || !await file.exists()) {
      _capabilities = _defaultCapabilities();
      await _save();
      return;
    }
    try {
      _capabilities = await file.readAsString();
    } catch (e) {
      debugPrint('BuddyCapabilitiesService: read error: $e');
      _capabilities = _defaultCapabilities();
    }
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) return;
    await file.parent.create(recursive: true);
    await file.writeAsString(_capabilities);
  }

  Future<void> updateCapabilities(String value) async {
    _capabilities = value;
    await _save();
    notifyListeners();
  }

  /// Called by the tool — replaces the whole capabilities text.
  Future<void> setCapabilities(String text) async {
    _capabilities = text.trim();
    await _save();
    notifyListeners();
  }

  String _defaultCapabilities() => """Verfuegbare Tools: open_app, open_navigation, get_location (liefert auch Adresse!), get_weather, get_current_time, get_device_info, get_battery_info, get_clipboard, web_search, get_webpage, set_reminder, set_timer, set_alarm, manage_apps, open_file, list_files, read_file, write_file, delete_file, rename_file, storage_access, open_url, share_text, read_config, update_config, add_calendar_event, get_calendar_events, update_calendar_event, delete_calendar_event, save_memory, search_memories, update_self_identity, buddy_notes, update_capabilities, send_sms, send_whatsapp, send_email, read_email, search_contacts, send_message_to_contact, manage_contacts, manage_shopping_list, music_intent, phone_call, record_voice_memo, search_photos, control_screen, toggle_wifi, toggle_bluetooth, set_volume, toggle_do_not_disturb, device_settings, check_update, analyze_image, automation_rules, offline_stt.

WICHTIG: get_location liefert Strasse+Bezirk+Stadt+Koordinaten — KEIN web_search fuer Adressen noetig!

GERAET TIEF BEDIENEN:
- set_alarm stellt einen ECHTEN Wecker/Timer in der Uhr-App (klingelt auch wenn AI-Buddy zu ist). set_reminder ist nur eine App-Benachrichtigung.
- search_photos durchsucht die Fotos des Nutzers (Name/Album/Zeit) und kann sie oeffnen.
- control_screen bedient JEDE andere App fuer den Nutzer (Bedienungshilfe): erst read_screen, dann tap/input_text/scroll, dann zur Kontrolle erneut read_screen. Nutze es wenn eine App keine eigene API hat (z.B. in einer Musik-App Play druecken, in einem Chat antworten). Bei "nicht aktiv": control_screen action=enable.
- read_file/write_file/list_files akzeptieren auch absolute Pfade (z.B. /storage/emulated/0/Download/...). Fehlt der Zugriff: storage_access action=request.""";
}
