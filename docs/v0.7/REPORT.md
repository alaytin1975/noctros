# Noctros v0.7 Completion Report

## New features
- Premium dark-first glassmorphism UI (Material 3 + Space Fonts)
- Animated AI Orb with idle / listening / thinking / speaking states
- Silent always-listening wake sessions (30-minute mic sessions, backoff recovery)
- Persistent “Noctros is ready.” notification
- ChatGPT-style chat with avatars, copy, regenerate, delete
- History tab with search, rename, favorites, export, delete
- Redesigned Settings + Voice Settings entry points
- Home / Chat / History / Settings bottom navigation

## Voice improvements
- Removed rapid mic open/close duty cycling that caused beeps/loops
- Long confirmation sessions with exponential restart backoff
- Detection cooldown to prevent duplicate wake triggers
- Silent wake acknowledgment (no “Yes?” chime)
- Auto-return to idle wake mode after pipeline completion

## Bug fixes
- Microphone restart loop mitigation
- Lifecycle pause/resume respects battery-optimized always-listening
- Emergency route moved out of bottom nav (full-screen push)
- Missing launcher icons restored
- Release build desugaring for notifications plugin

## Performance / battery
- Fewer recognition session restarts
- Low-importance ongoing notification (no sound/vibration)
- Orb animations use shared controllers; glass blur kept lightweight
- Dark theme default for OLED-friendly UI

## Tests
- `flutter analyze` — no issues
- `flutter test` — 19/19 passed

## Artifacts
- Release APK: `build/app/outputs/flutter-apk/app-release.apk`
- Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`
- UI previews: `docs/v0.7/home.png`, `docs/v0.7/chat.png`

## Branch
`cursor/v0.7-professional-ui`
