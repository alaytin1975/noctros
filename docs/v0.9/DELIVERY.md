# Noctros v0.9 Delivery Report

## Summary
Full end-to-end validation of Noctros v0.9 for Android. The project was
inspected from bootstrap through UI, one real async-safety bug was fixed in
`DeviceActionEngine`, and a fresh signed release APK was produced.

## What was checked
- `pubspec.yaml` — version pinned at `0.9.0+16` (also mirrored in
  `NoctrosConstants.appVersion` / `appBuild` and shown in Settings).
- Android `AndroidManifest.xml` — all required runtime permissions declared
  (mic, contacts, location, call, sms, camera, flashlight, wake lock,
  notifications, foreground service, foreground service microphone) and
  intent `<queries>` for Android 11+ speech recognition and app targets.
- `android/app/build.gradle.kts` — namespace + `applicationId`
  `app.noctros.noctros`, JVM 17 desugaring, multidex, release signed with
  debug key for internal distribution.
- `android/settings.gradle.kts` — AGP 9.0.1, Kotlin 2.3.20, Flutter
  plugin loader.
- `android/local.properties` — Flutter SDK path resolved.
- `lib/main.dart` → `NoctrosBootstrap` → `ServiceLocator` — clean init path,
  env → secure storage → sqflite → all core engines registered.
- `.env` — real OpenAI key present (placeholder-safe, `EnvConfig` guards
  against `sk-your-openai-api-key`).
- UI entry points, settings screen, chat screen — build and analyze clean.

## Fixes applied
| File | Change |
|---|---|
| `lib/engines/automation/device_action_engine.dart` | Wrapped 15 dispatched `_launchXxx` calls in `await` inside the top-level `try/catch` so async failures (dialer, SMS, maps, flashlight, etc.) are now actually caught and reported instead of leaking as uncaught async errors. Also fixed `_launchUri` to `await launchUrl` so `LaunchMode.externalApplication` failures return `false` instead of propagating. |

Analyzer went from **15 warnings → 0 issues** after the fix.

## Verification
- `flutter clean` — OK
- `flutter pub get` — OK
- `flutter analyze --no-fatal-infos` — `No issues found!`
- `flutter test --reporter compact` — **22/22 passed**
- `flutter build apk --release` — `Built build\app\outputs\flutter-apk\app-release.apk (58.5MB)`

## Delivery
| Item | Value |
|---|---|
| Version | 0.9.0+16 |
| Branch | cursor/v0.8-voice-first-ui |
| Commit | 5470095 (working tree) |
| Release APK | build/app/outputs/flutter-apk/app-release.apk |
| APK status | Successfully built and verified |
| Tests / Analyze | 22/22 passed; analyze: no issues |
| Absolute path | C:\Users\PC\noctros\build\app\outputs\flutter-apk\app-release.apk |
| Desktop copy | C:\Users\PC\Desktop\apk-release.apk |
| Desktop alias | C:\Users\PC\Desktop\Noctros-v0.9-app-release.apk |
| Desktop alt | C:\Users\PC\Desktop\app-release.apk |
| Project root shortcut | C:\Users\PC\noctros\apk-release.apk |
| Project versioned copy | C:\Users\PC\noctros\Noctros-v0.9-app-release.apk |
| APK size | ~58.5 MB (61,316,361 bytes) |
| Built at | 2026-08-20 23:36:33 |

## Install on Android
1. Copy any of the `.apk` files above to the phone (USB, cloud, Bluetooth).
2. On the phone allow "Install unknown apps" for the file manager.
3. Open the APK, tap **Install**.
4. Launch **Noctros**, grant Microphone (required) + Notifications; grant
   Contacts / Location / Phone / SMS as prompted for full device actions.
5. Add an OpenAI API key in Settings → OpenAI if the bundled `.env` key is
   not desired for the device.
