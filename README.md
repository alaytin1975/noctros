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
└── engines/       # AI (OpenAI streaming + local), Voice, Memory, Emergency
```

## v0.4 highlights

- Streaming OpenAI responses with offline fallback
- Smarter context window + prompt management
- Continuous voice conversation + interruption
- Chat search, favorites, pins, export
- Markdown chat bubbles and home dashboard
- Quick SOS emergency workflow
