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
copy .env.example .env   # Windows
# Fill OPENAI_API_KEY in .env, or enter the key later in Settings
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
├── core/          # Config, errors, utilities
├── domain/        # Entities, repository contracts, use cases
├── data/          # SQLite, secure storage, repositories
├── presentation/  # UI, themes, feature screens
└── engines/       # AI (OpenAI + local), Voice, Memory, Emergency
```

## Features

- Voice wake words: "Hey Noctros", "Noctros"
- Speech-to-text and text-to-speech
- OpenAI chat with local SQLite history
- Permissions, bottom navigation, dark/light themes
- Emergency assistant and permission-based memory

## Privacy

- Local processing by default when cloud is unavailable
- Encrypted secure storage for API keys
- Cloud AI only when configured
- Memory is opt-in and fully deletable
