# AI-Buddy

**Your personal, on-device AI companion for Android** — chat, voice, memory, and 45+ tools that let the assistant actually *do* things on your phone: calendar, contacts, messages, navigation, timers, email, web search and more.

Built with Flutter. Works with the LLM provider of your choice (Ollama Cloud, OpenRouter, OpenAI, Anthropic) — **you bring your own API key**, nothing is routed through servers owned by this project.

## Features

- 💬 **Chat** — streaming responses, vision (send photos), Telegram-style UI in light & dark mode
- 🗣️ **Voice** — offline TTS via [Piper](https://github.com/rhasspy/piper) (German, English, Spanish, Mandarin voices; device TTS otherwise), dictation, hands-free live voice mode
- 🧠 **Memory** — short-term / long-term / core memory tiers with semantic (embedding-based) retrieval; the assistant learns facts, routines and preferences over time
- 🤖 **Persona & self-image** — configurable personality that evolves from your conversations
- 🛠️ **45+ tools** — calendar (read/create/update/delete), contacts, SMS/WhatsApp/e-mail (IMAP read + send), phone calls, timers & reminders, navigation with offline maps (OpenStreetMap), weather, web search (DuckDuckGo, no API key), file sandbox, clipboard, app launcher, device settings, shopping list (Bring! integration), automation rules, and more
- 🔔 **Proactive engine** — optional time/location/routine-based suggestions with feedback learning (adjustable, 0–3)
- 🌍 **5 languages** — English (default), German, Spanish, Japanese, Mandarin; first-launch setup wizard, and the assistant replies in your chosen language
- ☁️ **Backup** — local export/import; optional Firebase cloud backup (bring your own Firebase project)
- 🔒 **Privacy-first** — all data (memory, chat, persona) stays on the device; API keys live in Android secure storage

## Getting started

### Requirements

- Flutter ≥ 3.44 (Dart ≥ 3.10)
- Android SDK (minSdk 26, target 34), Java 17

### Build

```bash
git clone https://github.com/Weltenwanderer1/ai-buddy.git
cd ai-buddy
flutter pub get
flutter build apk --debug     # or --release
```

The project builds out of the box — no secrets required. Optional integrations:

| Optional file | Purpose |
|---|---|
| `.env` (see `.env.example`) | Pre-seed API keys for development. Normally you just enter keys in **Settings → AI Model** inside the app. |
| `android/app/google-services.json` | Enables Firebase cloud backup. Without it the app runs normally and cloud backup is simply disabled. |
| `android/key.properties` | Your release signing key. Without it, release builds are signed with the debug key. |

None of these files belong in git — they are covered by `.gitignore`.

### First launch

A setup wizard walks you through: app language → AI provider & API key (skippable) → buddy name, theme & accent color. Everything can be changed later in Settings.

## Architecture (short version)

```
lib/
├── core/         theme (Material 3, light/dark), i18n (5 languages)
├── models/       chat message model
├── screens/      chat, settings, memory browser, persona editor, self-image,
│                 notes, capabilities, navigation map, welcome wizard
├── services/     ~35 services: LLM providers, chat orchestration, memory +
│                 embeddings, TTS (Piper/device), STT, live voice loop,
│                 proactive engine, scheduler, backups, location, timers …
├── tools/        45+ LLM tools (JSON-schema based) + registry
└── widgets/      message bubbles, input pill, timer bar …
```

- **LLM layer** — `ChatService` builds the system prompt (persona + self-image + memories + tool hints + answer language) and routes to the selected provider. Streaming with tool-call accumulation is supported on OpenAI-compatible providers; Anthropic uses the Messages API.
- **Tool system** — every tool declares a JSON schema; the registry feeds definitions to the LLM and dispatches calls. Failed calls generate learned hints injected into future prompts.
- **Memory** — heuristic local extraction after each turn (no extra LLM call) plus an explicit `save_memory` tool; retrieval ranks by embedding similarity with a token-overlap fallback plus recency.

## CI

GitHub Actions runs `flutter analyze` and the test suite on every push. A debug APK can be built on demand via *Actions → CI → Run workflow*.

## Privacy

- No telemetry, no analytics, no project-owned backend.
- Conversations go directly from your device to the LLM provider **you** configure.
- Memory, chat history, persona and notes are stored locally (app documents dir).
- Optional Firebase backup writes to **your own** Firebase project, with secrets redacted.

## License

[MIT](LICENSE) — created by **Günther Schuch** ([@Weltenwanderer1](https://github.com/Weltenwanderer1)).

Contributions and forks welcome. This is a personal-assistant app: review the permissions it requests (calendar, contacts, SMS, location, microphone …) and grant only what you want to use.
