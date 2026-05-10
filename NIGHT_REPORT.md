# AI-Buddy Night Report — 2026-04-29

## Aktueller Stand

- `flutter analyze`: sauber, keine Issues.
- `flutter test`: 68 Tests bestanden.
- Lokaler Debug-Build: wird auserhalb des GoogleDrive/rclone-Mounts gebaut.

## Umgesetzt

### Live Voice Inline Integration (Phase 9 finalisiert)
- **Live Voice Mode komplett inline in ChatScreen** — kein separater Vollbild-Screen.
- LIVE-Badge in AppBar (gruner Punkt + „LIVE"-Label) zeigt aktiven Modus.
- Voice-Nachrichten (MessageType.voice) bekommen eigenes Bubble-Design mit Mic-Icon.
- Transcript-Preview in der Statusleiste zeigt erkannten Text wahrend Thinking/Speaking.
- TypingIndicator wird jetzt auch wahrend Live-Modus Thinking angezeigt.
- ChatService ubergibt Voice-Nachrichten an LLM (vorher gefiltert).
- Live-Toggle in MessageInput mit `stream`-Icon (statt `record_voice_over`).

### Stabilitat & Tests
- Test-Suite fur Kernservices: 68 Tests bestanden.
- Memory-Similarity behandelt leere/Whitespace-Strings korrekt.
- Ollama-Statuscode-Erkennung robuster.

### Build-Doku
- README beschreibt den lokalen Build-Workaround fur GoogleDrive/rclone.
