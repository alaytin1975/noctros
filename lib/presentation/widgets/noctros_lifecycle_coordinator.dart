import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/service_locator.dart';
import '../../app/router/app_router.dart';
import '../../domain/entities/permission_entities.dart';
import '../../engines/voice/voice_ai_orchestrator.dart';
import '../../engines/voice/voice_engine.dart';
import '../features/chat/chat_screen.dart';
import '../features/emergency/emergency_screen.dart';
import '../providers/noctros_providers.dart';
import '../providers/permission_providers.dart';
import '../providers/voice_providers.dart';
import 'permission_prompt_sheet.dart';

/// Initializes permissions, voice wake-word listening, and voice pipeline.
class NoctrosLifecycleCoordinator extends ConsumerStatefulWidget {
  const NoctrosLifecycleCoordinator({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<NoctrosLifecycleCoordinator> createState() =>
      _NoctrosLifecycleCoordinatorState();
}

class _NoctrosLifecycleCoordinatorState
    extends ConsumerState<NoctrosLifecycleCoordinator>
    with WidgetsBindingObserver {
  bool _promptedForMicrophone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_bootstrap);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final voiceController = ref.read(voiceActivationProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      _startVoiceIfAllowed();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Pause wake cycles while backgrounded to save battery unless prepared.
      final prepared = ref
              .read(settingsControllerProvider)
              .settings
              ?.alwaysListeningPrepared ??
          false;
      if (!prepared) {
        voiceController.stop();
      }
    }
  }

  Future<void> _bootstrap() async {
    await ref.read(settingsControllerProvider.notifier).load();
    await ref.read(permissionsControllerProvider.notifier).refresh();
    final settings = ref.read(settingsControllerProvider).settings;
    final voice = ServiceLocator.get<VoiceEngine>();
    await ref.read(voiceActivationProvider.notifier).initialize(
          wakeWords: settings?.derivedWakeWords,
          speechRate: settings?.speechRate ?? 0.48,
          localeId: settings?.sttLocaleId ?? 'en_US',
        );
    if (settings != null) {
      await voice.configureVoice(
        speechRate: settings.speechRate,
        speechPitch: settings.speechPitch,
        speechVolume: settings.speechVolume,
        localeId: settings.sttLocaleId,
        wakeWords: settings.derivedWakeWords,
        voiceGender: settings.voiceGender,
        sttBackend: settings.sttBackend,
        cloudSttFallbackEnabled: settings.cloudSttFallbackEnabled,
      );
    }
    await _startVoiceIfAllowed();
    await _promptForMicrophoneIfNeeded();
  }

  Future<void> _promptForMicrophoneIfNeeded() async {
    if (_promptedForMicrophone || !mounted) {
      return;
    }

    final permissions = ref.read(permissionsControllerProvider);
    if (permissions.microphoneGranted) {
      return;
    }

    _promptedForMicrophone = true;
    await PermissionPromptSheet.show(
      context,
      permission: NoctrosPermission.microphone,
    );
  }

  Future<void> _startVoiceIfAllowed() async {
    final permissions = ref.read(permissionsControllerProvider);
    if (!permissions.microphoneGranted) {
      return;
    }

    final settings = ref.read(settingsControllerProvider).settings;
    if (settings != null && !settings.wakeWordEnabled) {
      return;
    }

    final voiceController = ref.read(voiceActivationProvider.notifier);
    final voiceState = ref.read(voiceActivationProvider);
    if (voiceState.isActive) {
      return;
    }

    await voiceController.start(
      onWakeWordDetected: (wakeWord) async {
        if (!mounted) {
          return;
        }
        final session = ref.read(chatSessionProvider);
        var conversationId = session.conversationId;
        if (conversationId == null) {
          await ref.read(chatSessionProvider.notifier).createConversation();
          conversationId = ref.read(chatSessionProvider).conversationId;
        }
        if (conversationId == null) {
          return;
        }

        final pipeline = ServiceLocator.get<VoiceAiOrchestrator>();
        await pipeline.onWakeWord(
          wakeWord: wakeWord,
          conversationId: conversationId,
          navigate: (route) {
            if (route == EmergencyScreen.routePath) {
              ref.read(appRouterProvider).go(EmergencyScreen.routePath);
            } else {
              ref.read(appRouterProvider).go(ChatScreen.routePath);
            }
          },
          confirmAction: (message) async {
            if (!mounted) {
              return false;
            }
            final result = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Confirm action'),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Allow'),
                  ),
                ],
              ),
            );
            return result ?? false;
          },
        );
        await ref.read(chatSessionProvider.notifier).reloadMessages();
        await _startVoiceIfAllowed();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PermissionsState>(permissionsControllerProvider,
        (previous, next) {
      if (previous?.microphoneGranted == false && next.microphoneGranted) {
        _startVoiceIfAllowed();
      }
    });

    return widget.child;
  }
}
