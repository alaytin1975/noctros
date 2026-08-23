# Noctros

Noctros is a premium voice-first AI device assistant for smartphones.

## v0.9 highlights

- Voice-first Home: living AI orb, energy waves, equalizer
- Chatbot conversation: speak or type, same history
- Settings via Chat (Home stays conversation-only)
- Wake word: “Noctros” / “Hey Noctros”

## v0.8 highlights

- Voice-first Home: living AI orb, energy waves, equalizer
- No bottom navigation — Settings + SOS only (Chat/History via menu)
- Fully automatic wake → listen → think → speak → return
- Silent always-listening with stable mic sessions
- Persistent “Noctros is ready” notification

## v0.7 highlights

- Commercial dark UI with glassmorphism and Material 3
- ChatGPT-style conversation experience
- History search / rename / favorites

## Setup

```bash
git clone https://github.com/alaytin1975/noctros.git
cd noctros
copy .env.example .env
flutter pub get
flutter run
```

## Architecture

```
Wake word → Speech Recognition → Voice ID → Intent Parser
         → AI Orchestrator → Device Action → Voice Response
```

```
lib/
├── app/                 # Bootstrap, routing, DI
├── core/                # Config, prompts, errors
├── domain/              # Entities, repositories, use cases
├── data/                # SQLite, secure storage
├── presentation/        # Premium UI + Riverpod
└── engines/             # AI, Voice, Security, Automation, Emergency
```

## Voice behavior

1. Microphone stays in a long silent wake session  
2. Detect “Noctros” (or your custom name)  
3. Full speech recognition activates  
4. Assistant thinks and speaks  
5. Automatically returns to silent idle wake mode  

No intentional beep sounds. Restarts use backoff to avoid mic loops.

## Build

```bash
flutter analyze
flutter test
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`
