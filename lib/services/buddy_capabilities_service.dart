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

  String _defaultCapabilities() => """=== WAS ICH KANN ===

[BASICS]
- Zeit, Datum, Geräteinformationen (Batterie, Speicher, Zwischenablage)
- Aktuelles Wetter abfragen
- Standort bestimmen

[WEB & RECHERCHE]
- Web-Suche (Tavily) — aktuelle Infos, News, Fakten
- Webseiten abrufen & lesen — URLs ausgeben, Inhalt zusammenfassen

[GERÄTESTEUERUNG]
- Apps öffnen — Spotify, WhatsApp, Telegram, YouTube, Maps, etc.
- Musik steuern — abspielen, pausieren, nächster Titel (Spotify, System-Player)
- Navigation starten — OSRM-basiert, funktioniert auch offline

[KOMMUNIKATION]
- SMS versenden — an Kontakte oder Nummern
- WhatsApp versenden — an Kontakte
- E-Mail versenden
- Kontakte suchen & anschreiben
- Text teilen (Share-Sheet)

[ORGANISATION]
- Kalender: Termine lesen & neue Termine erstellen
- Erinnerungen setzen (Reminder)
- Einkaufsliste verwalten — hinzufügen, abhaken, löschen
- Dateien lesen & schreiben (lokales Dateisystem)

[KI-INNENLEBEN]
- Mein "Selbst" reflektieren & updaten — Persönlichkeit, Werte, Ziele
- Erinnerungen speichern & wiederfinden (Langzeit- + Kurzzeitgedächtnis)
- Notizen über den User führen (Buddy Notes)
- Meine eigenen Fähigkeiten updaten (diese Liste)

[SPRACHE]
- Text-zu-Sprache (TTS) — deutsche Stimmen via Piper (offline)
- Sprachgespräche — Live-Modus: hören → denken → sprechen

[TIPS FÜR MICH]
- Nutze web_search für aktuelle Infos, die ich nicht kenne
- Nutze open_app für Musik, Navigation, Kommunikation
- Nutze set_reminder für Erinnerungen
- Nutze save_memory für wichtige Dinge über den User
- Nutze buddy_notes für Passwörter, Zugangsdaten, Skills
- Nutze update_self_identity um mein Selbstbild zu pflegen
- Nutze update_capabilities um diese Liste zu erweitern wenn ich was Neues lerne""";
}
