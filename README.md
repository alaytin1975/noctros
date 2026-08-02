# Noctros

Noctros is a voice-first AI operating system for smartphones — a trusted digital partner that controls your phone, manages your life, and protects you in emergencies.

## Requirements

- Flutter SDK 3.24+
- Dart 3.5+
- Android Studio / Xcode for device builds
- OpenAI API key (for cloud AI chat)

## Setup

```bash
git clone https://github.com/alaytin1975/noctros.git
cd noctros
copy .env.example .env
flutter pub get
flutter run
```

### OpenAI `.env`

```env
OPENAI_API_KEY=sk-your-openai-api-key
OPENAI_MODEL=gpt-4o-mini
OPENAI_BASE_URL=https://api.openai.com/v1
```

`.env` is gitignored. You can also store the API key securely in **Settings → OpenAI**.

## Architecture

Clean Architecture with independent engines:

```
lib/
├── app/           # Bootstrap, routing, dependency injection
├── core/          # Config, prompts, errors, utilities
├── domain/        # Entities, repository contracts, use cases
├── data/          # SQLite, secure storage, repositories
├── presentation/  # UI, themes, feature screens, Riverpod
└── engines/       # AI, Voice, Memory, Emergency, Automation
```

### Device assistant flow (v0.5)

1. User text/voice enters Chat  
2. `IntentParser` matches structured device intents  
3. `AiOrchestrator` routes to `DeviceActionEngine` or AI chat fallback  
4. Sensitive actions (call / SMS / navigation) require confirmation  
5. Safe action logs + optional memory (user-approved)

## v0.5 highlights

- Open apps, dialer, SMS, email, Maps, contacts, calendar, clock, camera, gallery, browser, system settings
- Natural voice/text commands (“Call John”, “Open WhatsApp”, “Navigate to home”)
- Extensible intent parser + central AI orchestrator
- Home dashboard: quick actions, shortcuts, recent AI actions, device status
- Memory for favorite apps/destinations/commands (contacts only with approval)
- Privacy controls: confirmations, export/delete local data, permissions overview

## v0.4 highlights (preserved)

- Streaming OpenAI responses with offline fallback
- Continuous voice conversation + interruption
- Chat search, favorites, pins, export
- Markdown chat bubbles and Quick SOS
