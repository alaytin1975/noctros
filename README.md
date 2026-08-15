# Noctros

Noctros is a voice-first AI communication app (messages, calls, contacts, and an autonomous agent Hive). This branch is a **Windows-first clean reset**.

## Supported platforms

| Platform         | Status this branch                  | SQLite backend             |
| ---------------- | ----------------------------------- | -------------------------- |
| Windows desktop  | Primary target — build and verify.  | `sqflite_common_ffi`       |
| Linux desktop    | Working (used as CI proxy).         | `sqflite_common_ffi`       |
| macOS desktop    | Should work; not tested this reset. | native `sqflite` plugin    |
| iOS / Android    | Should work; not tested this reset. | native `sqflite` plugin    |
| Web / Chrome     | **Intentionally not supported.**    | `PlatformStorage` throws.  |

Web will be re-added later behind a proper storage abstraction. Do not run
`flutter run -d chrome` against this branch — it will `UnsupportedError` at
startup by design.

## Requirements

- Flutter SDK 3.24 or newer
- Dart 3.5 or newer
- For Windows: Visual Studio 2022 with the *"Desktop development with C++"* workload
- For Linux: `ninja-build`, `libgtk-3-dev`, `libepoxy-dev`, `pkg-config`

## Run on Windows

```powershell
git clone <repo-url> noctros
cd noctros
flutter clean
flutter pub get
flutter run -d windows
```

## Storage architecture

There is one entry point for storage init: `lib/app/platform/platform_storage.dart`.

```
main.dart
  → NoctrosBootstrap.initialize()
      → PlatformStorage.initializeAndResolvePath(...)
           - Windows/Linux : sqflite_common_ffi + path_provider
           - macOS/iOS/Android : sqflite plugin + path_provider
           - Web : throws UnsupportedError (never calls path_provider)
      → ServiceLocator.registerCoreServices(databasePath: ...)
      → SecureStorageService.warmUp()  // flutter_secure_storage
      → NoctrosDatabase.open()
      → CommunicationSeed.ensureSeeded(db)
      → AgentMesh.start()
```

No conditional imports. No dual `main_*.dart`. No `_web`/`_io`/`_stub` split.

## Code layout

```
lib/
├── app/
│   ├── bootstrap/       # initialize() startup pipeline
│   ├── di/              # ServiceLocator singletons
│   ├── platform/        # PlatformStorage (one place for platform switches)
│   └── router/          # go_router routes
├── core/                # constants, errors, utilities
├── data/                # sqflite database + repositories + seed
├── domain/              # entities, repositories, use cases
├── engines/             # AI, voice, memory, emergency, automation, agent Hive
└── presentation/        # UI, providers, theme, feature screens
```

## Verification commands

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run -d windows   # or `-d linux` for the same desktop code path
```
