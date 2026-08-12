# Noctros

Noctros is an iPhone-ready Flutter communication app — messages, calls, contacts, and a voice-first AI assistant in one place.

## Features

- **Messages** — inbox, threaded chat, compose new conversations
- **Calls** — audio/video call UI with call history
- **Contacts** — favorites, search, quick message/call actions
- **Assistant** — talk to Noctros (local-first AI) and emergency tools
- **Privacy** — encrypted local storage, opt-in memory, cloud only when permitted

## Requirements

- Flutter SDK 3.24+
- Dart 3.5+
- Xcode for iPhone builds

## Setup

```bash
git clone <repo-url> noctros
cd noctros
flutter pub get
flutter run -d ios
```

## Architecture

Clean Architecture with independent engines:

```
lib/
├── app/           # Bootstrap, routing, dependency injection
├── core/          # Shared utilities, errors, network, security
├── domain/        # Entities, repository contracts, use cases
├── data/          # Data sources, models, repository implementations
├── presentation/  # UI, themes, feature screens
└── engines/       # AI, Voice, Memory, Emergency, Automation
```

## iPhone notes

Privacy usage strings for microphone, camera, speech, contacts, and location are configured in `ios/Runner/Info.plist`. Portrait is the primary phone orientation.

## Wake Words

- "Hey Noctros"
- "Noctros"
- Custom wake words (user-configurable)
