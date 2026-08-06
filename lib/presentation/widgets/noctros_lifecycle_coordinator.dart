import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/service_locator.dart';
import '../../app/router/app_router.dart';
import '../../domain/entities/permission_entities.dart';
import '../../engines/voice/voice_ai_orchestrator.dart';
import '../../engines/voice/voice_engine.dart';
import '../../engines/voice/voice_notification_service.dart';
import '../features/chat/chat_screen.dart';
import '../features/emergency/emergency_screen.dart';
import '../providers/assistant_ui_provider.dart';
import '../providers/noctros_providers.dart';
import '../providers/permission_providers.dart';
import '../providers/voice_providers.dart';
import 'permission_prompt_sheet.dart';

/// Initializes permissions, silent wake listening, and the voice pipeline.
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
  bool _pipelineRunning = false;

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
      final prepared = ref
              .read(settingsControllerProvider)
              .settings
              ?.alwaysListeningPrepared ??
          false;
      if (!prepared) {
        voiceController.stop();
        unawaitedHideNotification();
      }
    }
  }

  Future<void> unawaitedHideNotification() async {
    await ServiceLocator.get<VoiceNotificationService>().hide();
  }

  Future<void> _bootstrap() async {
    await ref.read(settingsControllerProvider.notifier).load();
    await ref.read(permissionsControllerProvider.notifier).refresh();
    final settings = ref.read(settingsControllerProvider).settings;
    final voice = ServiceLocator.get<VoiceEngine>();
    final notifications = ServiceLocator.get<VoiceNotificationService>();
    await notifications.initialize(
      onTap: () => ref.read(appRouterProvider).go(ChatScreen.routePath),
    );
    await ref.read(voiceActivationProvider.notifier).initialize(
          wakeWords: settings?.derivedWakeWords ?? const ['Noctros', 'Hey Noctros'],
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
      await ServiceLocator.get<VoiceNotificationService>().hide();
      return;
    }
    final voiceController = ref.read(voiceActivationProvider.notifier);
    final voiceState = ref.read(voiceActivationProvider);
    if (voiceState.isActive || _pipelineRunning) {
      return;
    }

    await voiceController.start(
      onWakeWordDetected: (wakeWord) async {
        if (!mounted || _pipelineRunning) {
          return;
        }
        _pipelineRunning = true;
        ref.read(assistantUiProvider.notifier).setListening('Wake word');
        try {
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
          ref.read(assistantUiProvider.notifier).setListening();
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
        } finally {
          _pipelineRunning = false;
          ref.read(assistantUiProvider.notifier).setIdle();
          await _startVoiceIfAllowed();
        }
      },
    );
    await ServiceLocator.get<VoiceNotificationService>().showReady();
    ref.read(assistantUiProvider.notifier).setIdle('Ready');
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
