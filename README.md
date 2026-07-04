# AI-Buddy

> Persönlicher AI Companion als Flutter/Dart-Android-App — Chat, Voice, Memory, Persona, Backup/Restore.

## Kurzfassung für neue KIs

AI-Buddy ist Günthers persönlicher AI-Begleiter. Die App funktioniert wie ein kleiner, wachsender Companion: anschreibbar per Chat, sprachfähig per TTS/STT, mit eigenem Gedächtnis und einer Persönlichkeit, die sich beim ersten Start formt und weiterentwickelt.

**Arbeitsordner:**

```bash
/home/gsus/GoogleDrive/_Programmieren/AI-Buddy
```

**Wichtig:** Arbeite direkt in diesem Ordner. Keine echten API-Keys committen oder in Markdown schreiben.

## Aktueller Status

Stand: 2026-04-30

- ✅ **Phase 1 abgeschlossen** — Core Fixes (Memory-Injektion, Persistenz, API-Robustheit)
- ✅ **Phase 2 abgeschlossen** — UI & Config (Settings, Secure Storage, Memory-Browser, Persona-Editor, Backup)
- ✅ **Phase 3 abgeschlossen** — Voice (TTS Playback, STT Mikrofon, ElevenLabs Integration)
- ✅ **Phase 4 abgeschlossen** — Smart Features (Persona Evolution, Style Analysis)
- ✅ **Phase 6 abgeschlossen** — Live Voice Mode (kontinuierliches Sprachgespräch)
- ✅ **Phase 5 teilweise** — Release Config (ProGuard, minSdk 23), Tests stehen aus
- ✅ **Bugfix-Review** durchgeführt, alle P0-P3 Issues behoben
- ✅ **Phase 9 abgeschlossen** — Live Voice komplett inline in Chat (kein separater Screen)
- ✅ **Phase 10 abgeschlossen** — Tool-System (LLM Tool-Use, Tool-Call-Loop)
- ✅ **Phase 12 abgeschlossen** — Android App-Start + Navigation per natürlicher Sprache
- ✅ **Phase 11 abgeschlossen** — Streaming LLM Responses + Embedding-basiertes Memory + device_calendar
- ✅ `flutter analyze` = **0 issues**
- ✅ `flutter test` = **147 tests passed**
- ✅ **Debug-APK baut erfolgreich**
- ✅ **Release-APK baut erfolgreich**

Schnellcheck:

```bash
cd /home/gsus/GoogleDrive/_Programmieren/AI-Buddy
flutter pub get
flutter analyze

# Build (GoogleDrive-Mount kann gradlew blockieren — in lokalen Ordner kopieren):
mkdir -p /home/gsus/.openclaw/workspace/tmp/ai-buddy-build
rsync -a --exclude='.dart_tool' --exclude='build' --exclude='.gradle' --ignore-errors /home/gsus/GoogleDrive/_Programmieren/AI-Buddy/ /home/gsus/.openclaw/workspace/tmp/ai-buddy-build/
chmod +x /home/gsus/.openclaw/workspace/tmp/ai-buddy-build/android/gradlew
cd /home/gsus/.openclaw/workspace/tmp/ai-buddy-build
TMPDIR=/home/gsus/.openclaw/workspace/tmp flutter build apk --debug
```

## Architektur

```text
lib/
├── main.dart                          # Entry, Provider-Setup, .env-Loading
├── models/
│   └── chat_message.dart              # ChatMessage mit UUID, MessageType, JSON
├── screens/
│   ├── chat_screen.dart               # Haupt-Chat-UI mit History + Auto-Scroll
│   ├── (live_voice_screen.dart removed)  # Live-Modus jetzt inline in ChatScreen
│   ├── onboarding_screen.dart         # Ersteinrichtung: Name + Persönlichkeit
│   ├── settings_screen.dart           # API-Keys, Model, Memory, Backup, Data
│   ├── memory_browser_screen.dart      # Kurz-/Langzeit-Gedächtnis durchsuchen
│   └── persona_editor_screen.dart      # Persona bearbeiten mit Live-Preview
├── services/
│   ├── live_voice_service.dart       # Kontinuierlicher Listen→Think→Speak-Loop (in ChatScreen eingebettet)
│   ├── notification_service.dart       # Lokale Benachrichtigungen (flutter_local_notifications)
│   ├── ollama_cloud_service.dart       # LLM-API: Timeout, Retry, Fallback-Model, Tool-Use, Streaming
│   ├── elevenlabs_service.dart         # TTS: ElevenLabs API, echte Implementierung
│   ├── tts_playback_service.dart       # Audio Playback + Caching für TTS
│   ├── stt_service.dart               # Speech-to-Text über speech_to_text
│   ├── chat_service.dart              # Orchestriert System-Prompt + Memory + LLM (streaming + tool-loop)
│   ├── chat_history_service.dart       # Persistenter Chat-Verlauf (max 200)
│   ├── memory_service.dart            # Short-/Long-Term Memory + Promotion + Query (Embedding-enhanced)
│   ├── embedding_service.dart         # Text-Embeddings via Ollama API + Cosine Similarity
│   ├── calendar_service.dart          # device_calendar Integration: Permissions, Events lesen/erstellen
│   ├── persona_service.dart           # Persona + System-Prompt + Evolution-Context
│   ├── persona_evolution_service.dart  # Lernt User-Stil, passt Persona an
│   ├── settings_service.dart          # Key-Value Settings + Debounced Save
│   ├── secure_config_service.dart      # API-Keys in flutter_secure_storage
│   └── backup_service.dart            # Export/Import als ZIP + Validierung
├── tools/
│   ├── tool_interface.dart             # Basis-Interface für alle Tools
│   ├── tool_definition.dart            # Name, Beschreibung, Parameter-Schema (JSON Schema)
│   ├── tool_result.dart                # Ergebnis eines Tool-Aufrufs (Text, Error, Display)
│   ├── tool_registry.dart              # Zentrale Registry: registriert, sucht, führt Tools aus
│   ├── tools.dart                      # Barrel-File für Tool-Imports
│   ├── get_current_time_tool.dart       # Aktuelle Zeit/Datum/Wochentag/Zeitzone
│   ├── get_device_info_tool.dart        # Gerätename, OS, Speicher
│   ├── web_search_tool.dart            # Tavily API Websuche
│   ├── get_webpage_tool.dart            # URL fetchen + Text extrahieren
│   ├── set_reminder_tool.dart           # Lokale Benachrichtigung setzen
│   ├── open_url_tool.dart              # URL im Browser öffnen
│   ├── share_text_tool.dart            # Android Share-Sheet
│   ├── read_config_tool.dart           # AI-Buddy Config lesen
│   ├── update_config_tool.dart         # Config-Werte ändern
│   ├── get_calendar_events_tool.dart   # Nächste Kalendereinträge
│   └── add_calendar_event_tool.dart     # Termin zum Kalender hinzufügen
└── widgets/
    ├── message_bubble.dart            # Chat-Blasen (User, AI, System, Error, TTS-Button)
    ├── message_input.dart             # Texteingabe + Mikrofon-Button
    └── typing_indicator.dart           # Animierte Typing/Thinking-Anzeige (Messenger-Stil)
```

## Services im Detail

### `OllamaCloudService`
- HTTP Client persistent (Connection Reuse)
- Timeout: 120s, Retry: 2x mit Backoff
- Primary: glm-5.1:cloud, Fallback: deepseek-v4-flash:cloud
- Konfigurierbar über SecureConfigService
- **Streaming**: `chatStream()` — token-weise SSE-Streaming für OpenAI- & Ollama-kompatible Endpunkte
- **Tool-Use**: `chatWithTools()` — sendet Tool-Definitionen, parsed Tool-Call-Responses

### `ChatService`
- Orchestriert: System-Prompt + Memory-Kontext + Evolution-Kontext + History-Windowing (letzte 20) → LLM → Memory speichern
- **Streaming**: `streamResponse()` — token-weise UI-Ausgabe + vollständige Antwort in Memory/History
- Filtert System/Error-Nachrichten aus dem LLM-Kontext
- Triggert PersonaEvolution alle 10 Nachrichten (nicht-blockierend)

### `MemoryService`
- Short-Term: TTL (konfigurierbar, default 60min) + Repeat-Promotion (konfigurierbar, default 3)
- Long-Term: persistiert, abfragbar über `getRelevantMemories(query, limit)`
- **Embedding-basierte Similarity**: wenn EmbeddingService gesetzt, werden semantische Ähnlichkeiten (Cosine Similarity) statt reiner Token-Overlap verwendet
- `deleteById()` zum Löschen einzelner Erinnerungen
- Safe JSON Parsing, UUID-IDs
- Fallback auf Token-Overlap wenn Embedding-Service nicht verfügbar

### `EmbeddingService`
- Generiert Text-Embeddings via lokale Ollama-API (`nomic-embed-text`)
- Embedding-Cache: Text → Vektor, vermeidet redundante API-Calls
- `getEmbedding(text)` — einzelnes Embedding abrufen (mit Cache)
- `getEmbeddings(texts)` — Batch-Embedding für mehrere Texte
- `cosineSimilarity(a, b)` — statische Methode für Vektor-Vergleich
- Null-Safe: gibt `null` zurück bei Fehlern (API nicht verfügbar etc.)

### `CalendarService`
- `device_calendar` Integration für Kalenderzugriff
- `init()` — Berechtigungen anfragen
- `getEvents(daysAhead)` — Termine der nächsten N Tage lesen
- `addEvent(title, start, end, ...)` — Neuen Termin erstellen
- `formatEvent()` — statische Formatierung für Tool-Display
- Schreibgeschützte Kalender werden übersprungen
- Null-Safe: gibt leere Liste / false zurück bei Fehlern

### `PersonaEvolutionService`
- Analysiert User-Nachrichten via LLM
- `analyzeConversation()`: Leichtgewichtige Analyse, getriggert von ChatService alle 10 Nachrichten
- `evolve()`: Volle Analyse mit User-Namen und Personality-Kontext
- Extrahiert: Traits, bevorzugter Stil, zu vermeidende Themen
- Begrenzt auf 20 Traits, 10 Avoid, 10 Style-Einträge
- Kontext wird in System-Prompt injiziert

### `SecureConfigService`
- API-Keys in `flutter_secure_storage` statt plaintext .env
- Automatische Migration von .env-Werten beim ersten Start
- Cache für schnellen Zugriff
- `tavilyApiKey` Getter/Setter für Web-Suche

### Tool-System (Phase 10)

AI-Buddy kann jetzt **Tools** nutzen — der LLM entscheidet autonom, ob er ein Tool aufrufen muss, und der Tool-Call-Loop orchestriert die Ausführung.

**Architektur:**
```text
User-Nachricht → ChatService
  ↓
ChatService baut Kontext (System-Prompt + Memory + History)
  ↓
OllamaCloudService.chatWithTools(tools: [...])
  ↓
LLM antwortet mit tool_calls?
  → Ja: ToolRegistry.execute(tool_name, params)
     → ToolResult (Erfolg/Fehler)
     → Ergebnis als Tool-Message zurück ans LLM
     → Wiederholen (max 5 Runden)
  → Nein: Normale Text-Antwort → ChatBubble
```

**Verfügbare Tools (21):**

| Tool | Beschreibung |
|------|-------------|
| `get_current_time` | Aktuelle Uhrzeit, Datum, Wochentag, Zeitzone |
| `get_device_info` | Gerätename, OS-Version, Speicherinfo |
| `get_battery_info` | Akku-/Ladestatus |
| `get_clipboard` | Zwischenablage lesen |
| `web_search` | Tavily API Websuche |
| `get_webpage` | URL fetchen und Text extrahieren |
| `set_reminder` | Lokale Benachrichtigung/Erinnerung setzen |
| `open_url` | URL im Standard-Browser öffnen |
| `open_app` | Android-App per Name oder Package öffnen |
| `open_navigation` | Google-Maps-/Android-Navigation zu einem Ziel starten |
| `music_intent` | Best-effort Musik-App öffnen / Song-Künstler-Playlist suchen |
| `share_text` | Text über Android Share-Sheet teilen |
| `read_config` | Aktuelle Buddy-Config lesen |
| `update_config` | Config-Werte ändern (Persona, Modell, etc.) |
| `get_calendar_events` | Nächste Kalendereinträge lesen |
| `add_calendar_event` | Termin zum Kalender hinzufügen |
| `list_files` | Dateien im App-Bereich listen |
| `read_file` | Datei lesen |
| `write_file` | Datei schreiben |
| `send_sms` | SMS-App mit Empfänger/Text öffnen |
| `send_whatsapp` | WhatsApp-Chat/Share Intent öffnen |

**Semantische Geräte-Aktionen (2026-05-04):**
- App öffnen, Navigation, Reminder und Musik laufen model-first über strukturierte Tool-Spezifikationen (`tool_calls`).
- Falls ein Modell keine nativen Tool-Calls liefert, akzeptiert AI-Buddy robuste Inline-XML/JSON Toolcalls und nutzt Regex nur als letzte Fallback-Schicht nach dem Modellversuch.
- Android-App-Start nutzt `MethodChannel` + `PackageManager.getLaunchIntentForPackage()` und kann unbekannte App-Namen zusätzlich über Launcher-Labels suchen.
- Musik ist Best-Effort: Android erlaubt echte Wiedergabesteuerung ohne Accessibility/Notification-Listener/Provider-SDK nicht zuverlässig; das Tool öffnet/sucht deshalb in der Musik-App.

**Tool-Call-Loop:**
- Max 5 Runden pro User-Nachricht
- Jeder Tool-Aufruf wird als `MessageType.toolActivity` Bubble im Chat angezeigt
- Tool-Results werden dem Modell als `tool`-Rolle zurückgegeben
- Nach max Runden: finaler LLM-Call ohne Tools

**Plattform-Callbacks:**
- Tools, die Plattform-Zugriff brauchen (Notifications, URL-Launcher, Share, Config, Kalender), verwenden statische Callbacks, die in `main.dart` beim App-Start registriert werden
- Das hält die Tool-Implementierungen testbar und plattformunabhängig

### `TtsPlaybackService`
- ElevenLabs TTS mit Audio-Caching (MP3 in Temporary Directory)
- Play/Stop pro Nachricht über 🔊 Button
- Auto-Play optional in Settings

### `SttService`
- Speech-to-Text über `speech_to_text` Package
- Mikrofon-Button in MessageInput
- 30s Timeout, de_DE locale

### `LiveVoiceService`
- Kontinuierlicher Sprach-Loop: Zuhören → Transkribieren → LLM-Anfrage → TTS-Antwort → wieder Zuhören
- Echo-Vermeidung: Während TTS spricht, wird nicht zugehört
- Nachrichten werden in ChatHistory und Memory gespeichert (MessageType.voice)
- Zustände: idle, listening, thinking, speaking, error
- Stop beendet laufendes Listening/Playback
- Fehler werden angezeigt, Loop fährt fort wenn möglich
- Drosselung bei aufeinanderfolgenden leeren Erkennungen (max 10, dann 2s Pause)
- Fehler-Pause: 2s Wartezeit nach Fehlern bevor Retry
- **Direkt in ChatScreen eingebettet** — kein separater Vollbild-Screen mehr

## Secrets und Tokens

**Niemals echte Secrets ins Repo oder in README schreiben.**

```bash
cp .env.example .env
# Dann .env mit echten Keys befüllen
```

`.env` ist durch `.gitignore` ausgeschlossen. API-Keys werden beim ersten App-Start in `flutter_secure_storage` migriert.

Erwartete Keys:

```env
OLLAMA_CLOUD_BASE_URL=https://api.ohmyllama.com
OLLAMA_CLOUD_API_KEY=***
OLLAMA_CLOUD_MODEL=glm-5.1:cloud
OLLAMA_CLOUD_FALLBACK_MODEL=deepseek-v4-flash:cloud
ELEVENLABS_API_KEY=***
ELEVENLABS_VOICE_ID=***
ELEVENLABS_MODEL_ID=eleven_multilingual_v2
```

## Backup/Restore

- Export: ZIP mit `backup.json` (Version 3)
- Import: File-Picker, Schema-Validierung
- Inhalt: Memory + Persona + Settings + ChatHistory + PersonaEvolution
- Keine API-Keys im Export

## Changelog

### Phase 1 (2026-04-26)
- [FIX] Memory-Kontext wird in ChatService injiziert
- [FIX] Chat-Verlauf persistent (ChatHistoryService)
- [FIX] OllamaCloudService: Timeout, Retry, Fallback-Model
- [FIX] Safe JSON parsing — korrupte Dateien crashen nicht mehr
- [FIX] Settings: Debounced Save + Defaults
- [FIX] Memory: Safe JSON + UUID + getRelevantMemories
- [FIX] ChatService: System/Error messages nicht im LLM-Kontext
- [FIX] Error-Messages sanitized
- [NEW] ChatHistoryService, ElevenLabsService echt, TtsPlaybackService
- [NEW] Android INTERNET + RECORD_AUDIO Permissions

### Phase 2 (2026-04-26)
- [NEW] Settings Screen (API-Keys, Model, Memory, Data, Backup)
- [NEW] Memory Browser (Short/Long-Term Tabs, Suche, Delete)
- [NEW] Persona Editor (Name, Traits, Greeting, Backstory, Live-Preview)
- [NEW] SecureConfigService (flutter_secure_storage statt .env)
- [NEW] Backup/Restore UI mit Validierung
- [FIX] http.Client persistent statt per-request
- [FIX] SettingsService stream subscription leaked → jetzt properly disposed
- [FIX] PersonaService cast<String> → safe map toString
- [FIX] MemoryMessage metadata cast → safe _safeMetadataCast

### Phase 3 (2026-04-26)
- [NEW] TTS Playback: ElevenLabs Voice + Audio-Caching + Play/Stop pro Nachricht
- [NEW] STT: Mikrofon-Button in MessageInput (speech_to_text)
- [NEW] MessageBubble: Verschiedene Styles für text/system/error/voice
- [NEW] MessageBubble: Zeitstempel + 🔊 TTS-Button
- [NEW] Dark Mode als Standard-Theme

### Phase 4 (2026-04-26)
- [NEW] PersonaEvolutionService: Lernt User-Stil, extrahiert Traits/Avoid/Style
- [NEW] Persona Service: evolutionContext Parameter in buildSystemPrompt()
- [NEW] MemoryService.deleteById() funktioniert jetzt
- Memory-Settings aus SettingsService werden dynamisch gelesen

### Phase 6 (2026-04-27)
- [NEW] Live Voice Mode: Kontinuierliches Sprachgespräch
- [NEW] `LiveVoiceService`: Orchestriert Listen→Think→Speak Loop
  - SttService → ChatService → TtsPlaybackService in Dauerschleife
  - Echo-Vermeidung: Kein Zuhören während TTS spricht
  - User- und Assistant-Nachrichten in ChatHistory + Memory gespeichert
  - MessageType.voice für Sprach-Nachrichten
- [FIX] `flutter analyze` = 0 issues

### Phase 9 (2026-04-29) — Live Voice Inline in Chat
- [CHANGED] Live Voice Mode ist **nicht mehr als separater Vollbild-Screen** erreichbar
- [CHANGED] `live_voice_screen.dart` entfernt — Live-Modus direkt in ChatScreen integriert
- [NEW] ChatScreen: Live-Toggle-Button in MessageInput (stream-Icon)
- [NEW] ChatScreen: LiveVoiceService Lifecycle direkt in ChatScreen-State
- [NEW] `_LiveStatusBar` Widget: zeigt aktuellen Zustand (Lauscht/Denkt/Spricht) + Stop-Button + Transcript-Preview
- [NEW] `_PulsingIcon`: Pulsierende Mic-Animation wihrend Listening
- [NEW] MessageInput: Dual-Mode — normal (Text+Diktat+Live-Toggle) vs. Live-aktiv (LIVE-Badge+Stop)
- [NEW] LIVE-Badge in AppBar wenn Live-Modus aktiv (gruener Punkt + „LIVE")
- [NEW] Voice-Nachrichten im Chat: eigenes Bubble-Design mit Mic-Icon (MessageType.voice)
- [NEW] TypingIndicator zeigt „KI denkt nach" auch wahrend Live-Modus Thinking
- [CHANGED] ChatService: Voice-Nachrichten (MessageType.voice) werden jetzt an LLM weitergegeben
- [CHANGED] AppBar: Mikrofon-Button entfernt (war Navigation zu separatem Screen)
- Transkribierte Sprache landet als normale User-Nachricht im Chat
- AI-Antwort nutzt bestehende TTS/Playback-Infrastruktur
- Keine parallele Conversation-Logik — LiveVoiceService schreibt direkt in ChatHistory
- [FIX] `flutter analyze` = 0 issues

### Phase 7 (2026-04-27)
- [NEW] `TypingIndicator` Widget: Animierte 3-Punkt-Bounce-Anzeige (Messenger-Stil)
- [NEW] Chat: CircularProgressIndicator ersetzt durch TypingIndicator ("KI denkt nach")
- [NEW] LiveVoice: Thinking-Zustand zeigt TypingIndicator statt CircularProgressIndicator
- [UX] App-Startup behält CircularProgressIndicator (nur Chat/Voice bekommen TypingIndicator)
- [FIX] `flutter analyze` = 0 issues

### Phase 5 (teilweise)
- [NEW] ProGuard Rules für Release Builds
- [NEW] minSdk auf 23 angehoben (für flutter_secure_storage)
- [NEW] Version Code/Name in build.gradle aktualisiert
- Tests: noch offen

### Phase 10 (2026-04-29) — Tool-System
- [NEW] **Tool-System**: LLM kann autonom Tools aufrufen — AI-Buddy wird zum echten Assistenten
- [NEW] **ToolRegistry**: Zentrale Registry für alle Tools, registriert 11 Standard-Tools
- [NEW] **OllamaCloudService.chatWithTools()**: Sendet Tool-Definitionen an LLM, parsed Tool-Call-Responses
- [NEW] **ChatService Tool-Call-Loop**: Orchestriert max 5 Runden (LLM → Tool → Result → LLM → ...)
- [NEW] **11 Tools implementiert**:
  - `get_current_time` — Aktuelle Uhrzeit/Datum/Wochentag/Zeitzone
  - `get_device_info` — Gerätename, OS, Speicher
  - `web_search` — Tavily API Websuche (API-Key aus SecureConfig)
  - `get_webpage` — URL fetchen + HTML-Text extrahieren
  - `set_reminder` — Lokale Benachrichtigung (flutter_local_notifications)
  - `open_url` — URL im Browser öffnen (url_launcher)
  - `share_text` — Text teilen (share_plus)
  - `read_config` — Aktuelle AI-Buddy-Config lesen
  - `update_config` — Config-Werte ändern (erlaubte Schlüssel allowlisted)
  - `get_calendar_events` — Nächste Kalendereinträge
  - `add_calendar_event` — Termin hinzufügen
- [NEW] **NotificationService**: flutter_local_notifications + timezone für Erinnerungen
- [NEW] **Tool Activity Bubbles**: `MessageType.toolActivity` — kleine, zentrierte, kursive Bubbles im Chat
- [NEW] **Plattform-Callbacks**: Statische Callbacks in main.dart registriert (url_launcher, share_plus, Config, Kalender)
- [NEW] **Android Permissions**: INTERNET, RECEIVE_BOOT_COMPLETED, SCHEDULE_EXACT_ALARM, POST_NOTIFICATIONS, READ/WRITE_CALENDAR
- [NEW] **Dependencies**: flutter_local_notifications, url_launcher, share_plus, device_info_plus, device_calendar, permission_handler, timezone
- [NEW] **Core Desugaring**: isCoreLibraryDesugaringEnabled in build.gradle.kts für flutter_local_notifications
- [NEW] **SecureConfigService**: tavilyApiKey Getter/Setter
- [NEW] **102 Unit Tests** (36 neue Tool-Tests)
- [CHANGED] `ChatMessage.MessageType` um `toolActivity` erweitert
- [CHANGED] `main.dart` registriert ToolRegistry + alle Plattform-Callbacks
- [CHANGED] App-Version: 0.3.0, versionCode: 3
- [FIX] `flutter analyze` = 0 errors/warnings (1 info-level only)
- [FIX] `flutter test` = 102 passed

### Phase 12 (2026-05-02) — App öffnen + Navigation
- [NEW] `open_navigation` Tool: startet Google Maps/Android Navigation zu Zielen wie „Stephansdom“, „Route zu …“, „fahr mich nach …“
- [CHANGED] `open_app` robuster: deutsche Befehle/Umlaute/oe-Varianten/Füllwörter werden normalisiert; mehr App-Aliase; Play-Store-Fallback bei fehlenden Apps
- [CHANGED] `ChatService` erkennt offensichtliche App- und Navigationsbefehle vor dem LLM und führt sie sofort aus
- [CHANGED] `PersonaService` kennt `open_navigation` in den Tool-Regeln
- [FIX] `flutter analyze` = 0 issues
- [FIX] `flutter test` = 144 passed

### Phase 11 (2026-04-30) — Streaming + Embedding Memory + Calendar
- [NEW] **Streaming LLM Responses**: `OllamaCloudService.chatStream()` — SSE-basiertes Token-Streaming (OpenAI- & Ollama-kompatibel)
- [NEW] **ChatService.streamResponse()**: Token-weise UI-Ausgabe mit vollständiger Antwort-Speicherung in Memory/History
- [NEW] **EmbeddingService**: Text-Embeddings via Ollama-API (`nomic-embed-text`), mit Cache und Cosine Similarity
- [NEW] **MemoryService Embedding-Integration**: Semantische Similarity-Suche statt reiner Token-Overlap wenn EmbeddingService gesetzt
- [NEW] **CalendarService**: `device_calendar` Integration — Permissions, Events lesen/erstellen, Formatierung
- [NEW] **151 Unit Tests** (49 neue: Embedding, Calendar, Streaming, Tool-Callbacks)
- [NEW] **ProGuard-Regeln**: Play Core Klassen hinzugefügt (`-keep` + `-dontwarn`)
- [FIX] **Calendar-Tool-Tests**: API-Mismatch behoben (Callback-basiert statt Service-basiert)
- [FIX] **ToolResult.isError**: Tests korrigiert (`isFalse` statt `isNull` für Erfolg)
- [CHANGED] `OllamaCloudService`: Streaming-Support (`_doStreamRequest`, `_streamResponse`, `_parseStreamChunk`)
- [CHANGED] `ChatService`: `streamResponse()` für Token-weise UI-Ausgabe
- [CHANGED] `MemoryService`: `setEmbeddingService()`, `embeddingService` Getter, Embedding-Cache, `getRelevantMemories()` mit Embedding-Fallback
- [CHANGED] `MemoryItem`: optionales `embedding`-Feld (List<double>)
- [FIX] `flutter analyze` = 0 issues
- [FIX] `flutter test` = 151 passed
- [FIX] **Release-APK baut erfolgreich** (minifyEnabled=false, shrinkResources=false)
- [NEW] **Unit Tests**: 66 Tests für MemoryService, ChatMessage, OllamaCloudService, PersonaService, PersonaEvolutionService, BackupService, ChatService
  - MemoryService: JSON roundtrip, similarity, promotion, export/import, persistence
  - ChatMessage: JSON roundtrip, defaults, equality, all MessageType enums
  - OllamaCloudService: config, endpoint detection, normalized URL, exceptions, extractStatus
  - PersonaService: buildSystemPrompt, evolutionContext, safeStringList
  - PersonaEvolutionService: buildEvolutionContext, export/import, parseEvolutionResponse, trait caps
  - BackupService: validation, zip roundtrip, corrupt data handling, no API key leaks
  - ChatService: evolutionInterval, prompt integration
- [NEW] **@visibleForTesting** accessors auf MemoryService, PersonaService, PersonaEvolutionService, OllamaCloudService
- [FIX] **MemoryService**: `_dataDir` nullable + `dataDirOverride` für in-memory Tests ohne path_provider
- [NEW] **PersonaEvolution → ChatService Integration**: ChatService übergibt Evolution-Kontext an System-Prompt und triggert Evolution alle 10 Nachrichten (nicht-blockierend)
- [NEW] **PersonaEvolutionService.analyzeConversation()**: Leichtgewichtige Analyse für ChatService-Trigger
- [FIX] **Backup/Restore vollständig**: BackupService exportiert/importiert jetzt ChatHistory und PersonaEvolution (v3), keine API-Keys
- [FIX] **Live Voice Robustheit**: Consecutive-empty-Recognition-Drossel (max 10, dann 2s Pause), Fehler-Pause (2s), Listener-Removal bei dispose, _NoopListenable statt ChangeNotifier-Leak
- [FIX] **ChatScreen**: PersonaEvolutionService wird an ChatService übergeben
- [FIX] PersonaService: `_safeStringList` → `safeStringList` (public für Tests)
- [FIX] `flutter analyze` = 0 issues, `flutter test` = 66 passed
- Build: Debug-APK baut erfolgreich im lokalen Klon

## Bekannte offene Punkte

- [x] ~~Unit Tests~~ → Phase 8: 66 Tests implementiert, Phase 10: 102 Tests, Phase 11: 151 Tests
- [x] ~~App-Integrationen (Calendar, Spotify, Weather)~~ → Phase 10: Tool-System mit 11 Tools (Calendar, Search, Device, etc.)
- [x] ~~Streaming LLM Responses~~ → Phase 11: `chatStream()` + `streamResponse()` implementiert
- [x] ~~Embedding-basierte Memory-Similarity~~ → Phase 11: EmbeddingService + MemoryService Integration
- [x] ~~device_calendar Integration~~ → Phase 11: CalendarService + Tool-Callbacks
- [ ] Release Signing (Keystore anlegen, CI/CD)
- [x] ~~Voice Call Screen (Live-Call-Modus)~~ → Phase 6 implementiert, Phase 9: inline in Chat
- [x] ~~device_calendar Integration für Kalender-Tools~~ → Phase 11: CalendarService
- [ ] Battery-Level in get_device_info (benötigt battery_plus Plugin)
- [ ] permission_handler Runtime-Requests für Kalender/Notifications

## Arbeitsregeln für neue KIs

1. **Immer erst README + Phasenplan lesen** — Source of Truth
2. **PHASE für PHASE bauen** — Nicht alles auf einmal
3. **Nach jeder Änderung:** `flutter analyze` laufen lassen
4. **Keine Secrets in Code/Repo** — `flutter_secure_storage` nutzen
5. **README aktuell halten** — Changelog ergänzen
6. **Keine destruktiven Änderungen** ohne vorheriges Backup
7. **User entscheidet** bei offenen Fragen

## Lizenz / Sichtbarkeit

Privates Projekt für Günther. Nicht öffentlich veröffentlichen, keine Keys oder privaten Daten ausleiten.