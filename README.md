# Noctros

Noctros is a voice-first AI operating system for smartphones — a trusted digital partner that controls your phone, manages your life, and protects you in emergencies.

## Requirements

- Flutter SDK 3.24+
- Dart 3.5+
- Android Studio / Xcode for device builds

## Setup

```bash
git clone <repo-url> noctros
cd noctros
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
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

## Privacy

- Local processing by default
- Encrypted SQLite database
- Cloud AI only when required and permitted
- Memory is opt-in and fully deletable

## Wake Words

- "Hey Noctros"
- "Noctros"
- Custom wake words (user-configurable)
