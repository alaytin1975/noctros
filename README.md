# Noctros

Noctros is a voice-first AI device assistant for smartphones — wake it by name, control the phone with confirmed actions, and keep emergencies available to anyone.

## Requirements

- Flutter SDK 3.24+
- Dart 3.5+
- Android Studio / Xcode for device builds
- OpenAI API key (cloud AI chat + optional Whisper STT fallback)

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
lib/
├── app/                 # Bootstrap, routing, DI
├── core/                # Config, prompts, errors
├── domain/              # Entities, repositories, use cases
├── data/                # SQLite, secure storage, repos
├── presentation/        # UI + Riverpod
├── engines/
│   ├── ai/              # Hybrid AI router
│   ├── automation/      # Intent parser + device actions
│   ├── emergency/       # SOS call/SMS/GPS/flashlight
│   ├── security/        # Voice ID (print/enroll/verify)
│   └── voice/           # Modular Voice Core
```

### Voice pipeline

```
Wake word → Speech Recognition → Voice ID → Intent Parser
        → AI Orchestrator → Device Action → Voice Response
```

### Security model

| Speaker | Access |
|---|---|
| Owner (Voice ID match or Voice ID off) | Full assistant + device actions |
| Unknown / guest (Voice ID on) | Emergency commands only |
| Any speaker | Help / Emergency / Call 112 / Save me |

Voice prints are stored encrypted in secure storage and never uploaded.

### Permission flow

1. App bootstrap refreshes permission snapshots  
2. Microphone prompt for wake listening  
3. Voice Settings / Settings overview for Phone, SMS, Location, Notifications, Battery optimization, Overlay  
4. Denied permissions fail gracefully; sensitive actions still require user confirmation  

## v0.6 Voice Core

- Modular Voice Engine: WakeWord, STT, TTS, Session, NoiseFilter, PermissionManager
- Configurable assistant name / wake word (Noctros, Nova, Friday, Jarvis, …)
- On-device Voice ID enrollment + verification
- Emergency mode with dialer, contacts SMS, GPS, SOS flashlight
- Offline-first STT with Whisper cloud fallback
- TTS gender/speed/pitch/volume + interrupt + queue
- Voice AI orchestrator pipeline
- Flashlight + music device actions
- Dedicated Voice Settings page

## v0.5 preserved

Device actions, confirmations, home dashboard, memory, chat streaming, and privacy export/delete remain intact.
