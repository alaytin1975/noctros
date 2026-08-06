import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/service_locator.dart';
import '../../app/router/app_router.dart';
import '../../domain/entities/permission_entities.dart';
import '../../engines/voice/voice_ai_orchestrator.dart';
import '../../engines/voice/voice_engine.dart';
import '../../engines/voice/voice_notification_service.dart';
import '../../engines/voice/voice_pipeline_log.dart';
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
  bool _bootstrapped = false;
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
    VoicePipelineLog.stage('App lifecycle', state.name);
    if (state == AppLifecycleState.resumed) {
      _unawaited(_startVoiceIfAllowed());
      return;
    }
    // Keep wake alive across inactive (system UI). Only pause when fully
    // backgrounded AND always-listening is explicitly disabled.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final settings = ref.read(settingsControllerProvider).settings;
      final keepAlive = settings?.alwaysListeningPrepared ?? true;
      if (!keepAlive && !_pipelineRunning) {
        VoicePipelineLog.stage('Wake paused', 'app ${state.name}');
        ref.read(voiceActivationProvider.notifier).stop();
        _unawaited(unawaitedHideNotification());
      }
    }
  }

  Future<void> unawaitedHideNotification() async {
    await ServiceLocator.get<VoiceNotificationService>().hide();
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped) {
      return;
    }
    _bootstrapped = true;
    VoicePipelineLog.stage('Bootstrap started');

    await ref.read(settingsControllerProvider.notifier).load();
    await ref.read(permissionsControllerProvider.notifier).refresh();

    // Ensure a conversation exists before the first wake.
    final chat = ref.read(chatSessionProvider);
    if (chat.conversationId == null) {
      await ref.read(chatSessionProvider.notifier).createConversation();
    }

    final settings = ref.read(settingsControllerProvider).settings;
    final voice = ServiceLocator.get<VoiceEngine>();
    final notifications = ServiceLocator.get<VoiceNotificationService>();
    await notifications.initialize(
      onTap: () => ref.read(appRouterProvider).go(HomeScreen.routePath),
    );

    try {
      await ref.read(voiceActivationProvider.notifier).initialize(
            wakeWords:
                settings?.derivedWakeWords ?? const ['Noctros', 'Hey Noctros'],
            speechRate: settings?.speechRate ?? 0.48,
            localeId: settings?.sttLocaleId ?? 'en_US',
          );
    } catch (error) {
      VoicePipelineLog.fail('Voice initialize', error);
      ref.read(assistantUiProvider.notifier).setIdle('Mic unavailable');
    }

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
      if (settings.wakeWordEnabled) {
        await voice.prepareAlwaysListeningBackgroundService();
        if (!settings.alwaysListeningPrepared) {
          await ref.read(settingsControllerProvider.notifier).save(
                settings.copyWith(alwaysListeningPrepared: true),
              );
        }
      }
    }

    // Request mic BEFORE claiming we're listening.
    await _ensureMicrophonePermission();
    await _startVoiceIfAllowed();
    VoicePipelineLog.stage('Bootstrap finished');
  }

  Future<void> _ensureMicrophonePermission() async {
    await ref.read(permissionsControllerProvider.notifier).refresh();
    var permissions = ref.read(permissionsControllerProvider);
    if (permissions.microphoneGranted) {
      VoicePipelineLog.stage('Microphone permission', 'granted');
      return;
    }

    VoicePipelineLog.stage('Microphone permission', 'requesting');
    if (!_promptedForMicrophone && mounted) {
      _promptedForMicrophone = true;
      await PermissionPromptSheet.show(
        context,
        permission: NoctrosPermission.microphone,
      );
      await ref.read(permissionsControllerProvider.notifier).refresh();
    }

    // Also try a direct request in case the sheet was dismissed.
    permissions = ref.read(permissionsControllerProvider);
    if (!permissions.microphoneGranted) {
      await ref
          .read(permissionsControllerProvider.notifier)
          .request(NoctrosPermission.microphone);
      await ref.read(permissionsControllerProvider.notifier).refresh();
    }

    permissions = ref.read(permissionsControllerProvider);
    if (!permissions.microphoneGranted) {
      VoicePipelineLog.fail('Microphone permission', 'denied');
      ref.read(assistantUiProvider.notifier).setIdle('Allow microphone');
    } else {
      VoicePipelineLog.stage('Microphone permission', 'granted');
    }
  }

  Future<void> _startVoiceIfAllowed() async {
    final permissions = ref.read(permissionsControllerProvider);
    if (!permissions.microphoneGranted) {
      VoicePipelineLog.fail('Start wake', 'microphone not granted');
      ref.read(assistantUiProvider.notifier).setIdle('Allow microphone');
      return;
    }
    final settings = ref.read(settingsControllerProvider).settings;
    if (settings != null && !settings.wakeWordEnabled) {
      await ServiceLocator.get<VoiceNotificationService>().hide();
      ref.read(assistantUiProvider.notifier).setIdle('Wake word off');
      VoicePipelineLog.stage('Start wake', 'wake word disabled in settings');
      return;
    }
    if (_pipelineRunning) {
      VoicePipelineLog.stage('Start wake', 'skipped — pipeline running');
      return;
    }

    final voiceController = ref.read(voiceActivationProvider.notifier);
    final stt = ServiceLocator.get<VoiceEngine>().speechRecognition;
    final offlineReady = await stt.ensureInitialized();
    if (!offlineReady) {
      VoicePipelineLog.fail(
        'Start wake',
        'offline STT unavailable — install/update Google app speech services',
      );
      ref
          .read(assistantUiProvider.notifier)
          .setIdle('Speech service unavailable');
      return;
    }

    _wakeHandler ??= (wakeWord, transcript) async {
      if (!mounted || _pipelineRunning) {
        VoicePipelineLog.fail(
          'Wake handler',
          'dropped (mounted=$mounted busy=$_pipelineRunning)',
        );
        return;
      }
      _pipelineRunning = true;
      VoicePipelineLog.stage(
        'Wake Word detected',
        '"$wakeWord" transcript="$transcript"',
      );
      ref.read(assistantUiProvider.notifier).setListening('Wake word');
      try {
        var conversationId = ref.read(chatSessionProvider).conversationId;
        if (conversationId == null) {
          await ref.read(chatSessionProvider.notifier).createConversation();
          conversationId = ref.read(chatSessionProvider).conversationId;
        }
        if (conversationId == null) {
          VoicePipelineLog.fail('Wake handler', 'no conversationId');
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
            // Auto-confirm sensitive actions after spoken prompt failed —
            // voice-first: prefer allow for device opens; deny only on explicit no.
            VoicePipelineLog.stage('Confirm fallback', message);
            return true;
          },
        );
        await ref.read(chatSessionProvider.notifier).reloadMessages();
        await eventsSub.cancel();
        VoicePipelineLog.stage('Conversation finished');
      } catch (error) {
        VoicePipelineLog.fail('Pipeline', error);
      } finally {
        _pipelineRunning = false;
        ref.read(assistantUiProvider.notifier).setListening('Listening');
        await voiceController.stop();
        await Future<void>.delayed(const Duration(milliseconds: 450));
        VoicePipelineLog.stage('Returned to Wake Mode');
        await _startVoiceIfAllowed();
      }
    };

    try {
      await voiceController.start(onWakeWordDetected: _wakeHandler!);
      await ServiceLocator.get<VoiceNotificationService>().showReady();
      ref.read(assistantUiProvider.notifier).setListening('Listening');
      VoicePipelineLog.stage('Returned to Wake Mode', 'listening active');
    } catch (error) {
      VoicePipelineLog.fail('Start wake', error);
      ref.read(assistantUiProvider.notifier).setIdle('Voice start failed');
    }
  }

  void _unawaited(Future<void> future) {
    future.then(
      (_) {},
      onError: (Object error) {
        VoicePipelineLog.fail('Unawaited', error);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PermissionsState>(permissionsControllerProvider,
        (previous, next) {
      if (previous?.microphoneGranted == false && next.microphoneGranted) {
        VoicePipelineLog.stage('Microphone permission', 'granted (listener)');
        _startVoiceIfAllowed();
      }
    });

    return widget.child;
  }
}
