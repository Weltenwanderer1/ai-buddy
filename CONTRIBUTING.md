# Contributing to AI-Buddy

Thanks for your interest! AI-Buddy is a Flutter/Dart Android app — on-device AI assistant with memory, tools, voice, and proactive features.

## Getting Started

```bash
git clone https://github.com/Weltenwanderer1/ai-buddy.git
cd ai-buddy
flutter pub get
flutter run
```

**Requirements:** Flutter 3.44+, Dart 3.10+, Android SDK (minSdk 23).

## Development Workflow

1. Fork the repo, create a feature branch (`feature/your-thing` or `fix/your-bugfix`)
2. Run `flutter analyze` — must be zero issues before commit
3. Run `flutter test` — all tests must pass
4. Write clear commit messages (conventional commits preferred: `feat:`, `fix:`, `docs:`, etc.)
5. Open a Pull Request against `master`

## Code Style

- Follow `flutter analyze` recommendations
- Use `const` constructors where possible
- Keep tool descriptions short (one sentence) — every token costs context on every API call
- New tools: follow the single-tool-multi-action pattern (enum `action`), not separate tools per CRUD operation
- See the repo's existing patterns for services, tools, and UI widgets

## Reporting Bugs / Feature Requests

Use GitHub Issues. Include:
- Android version + device
- AI-Buddy version (Settings → About)
- Steps to reproduce
- Expected vs. actual behavior
- Logs if available

## Releases

APKs are built automatically via GitHub Actions when a `vX.Y.Z` tag is pushed. No manual build needed.

## Security

- **Never commit** API keys, `google-services.json`, `key.properties`, or `upload-keystore.jks`
- These are in `.gitignore` and provided at runtime via app settings or GitHub Secrets
- If you accidentally commit a secret: `git rm --cached` immediately, rotate the key

## Questions?

Open a GitHub Discussion — happy to help.