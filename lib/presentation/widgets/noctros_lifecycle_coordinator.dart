import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/service_locator.dart';
import '../../app/router/app_router.dart';
import '../../domain/entities/permission_entities.dart';
import '../../engines/voice/voice_ai_orchestrator.dart';
import '../../engines/voice/voice_engine.dart';
import '../../engines/voice/voice_notification_service.dart';
import '../features/emergency/emergency_screen.dart';
import '../features/home/home_screen.dart';
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
  void Function(String wakeWord, String transcript)? _wakeHandler;

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
    if (state == AppLifecycleState.resumed) {
      _startVoiceIfAllowed();
      return;
    }
    // Do not stop on inactive — system UI / dialogs would break wake loop.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final settings = ref.read(settingsControllerProvider).settings;
      final keepAlive = settings?.alwaysListeningPrepared ?? true;
      if (!keepAlive && !_pipelineRunning) {
        ref.read(voiceActivationProvider.notifier).stop();
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
      onTap: () => ref.read(appRouterProvider).go(HomeScreen.routePath),
    );
    await ref.read(voiceActivationProvider.notifier).initialize(
          wakeWords:
              settings?.derivedWakeWords ?? const ['Noctros', 'Hey Noctros'],
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
      // Keep always-listening prepared so pause does not kill wake by default.
      if (settings.wakeWordEnabled) {
        await voice.prepareAlwaysListeningBackgroundService();
        if (!settings.alwaysListeningPrepared) {
          await ref.read(settingsControllerProvider.notifier).save(
                settings.copyWith(alwaysListeningPrepared: true),
              );
        }
      }
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
    if (_pipelineRunning) {
      return;
    }

    final voiceController = ref.read(voiceActivationProvider.notifier);

    _wakeHandler ??= (wakeWord, transcript) async {
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
        ref.read(appRouterProvider).go(HomeScreen.routePath);
        ref.read(assistantUiProvider.notifier).setListening('Listening');
        final eventsSub = pipeline.events.listen((event) {
          final ui = ref.read(assistantUiProvider.notifier);
          switch (event.stage) {
            case 'listening':
              ui.setListening('Listening');
            case 'thinking':
            case 'orchestrating':
              ui.setThinking('Thinking');
            case 'response':
              ui.setSpeaking('Speaking');
            case 'emergency':
              ui.setListening('Emergency');
            case 'denied':
            case 'cancelled':
            case 'error':
              ui.setListening('Listening');
          }
          if (event.transcript != null && event.transcript!.isNotEmpty) {
            ui.setPartial(event.transcript!);
          }
        });
        await pipeline.onWakeWord(
          wakeWord: wakeWord,
          wakeTranscript: transcript,
          conversationId: conversationId,
          navigate: (route) {
            if (route == EmergencyScreen.routePath) {
              ref.read(appRouterProvider).go(EmergencyScreen.routePath);
            }
          },
          confirmAction: (message) async {
            if (!mounted) {
              return false;
            }
            // Last-resort UI confirm if voice yes/no was unclear.
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
        await eventsSub.cancel();
      } finally {
        _pipelineRunning = false;
        ref.read(assistantUiProvider.notifier).setListening('Listening');
        // Critical: clear activation state then restart always-listening.
        await voiceController.stop();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await _startVoiceIfAllowed();
      }
    };

    await voiceController.start(onWakeWordDetected: _wakeHandler!);
    await ServiceLocator.get<VoiceNotificationService>().showReady();
    ref.read(assistantUiProvider.notifier).setListening('Listening');
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
