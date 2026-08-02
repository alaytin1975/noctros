import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/app_router.dart';
import '../../core/constants/noctros_constants.dart';
import '../../domain/entities/permission_entities.dart';
import '../features/chat/chat_screen.dart';
import '../features/emergency/emergency_screen.dart';
import '../providers/noctros_providers.dart';
import '../providers/permission_providers.dart';
import '../providers/voice_providers.dart';
import 'permission_prompt_sheet.dart';

/// Initializes permissions, voice wake-word listening, and handles detections.
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
      voiceController.stop();
    }
  }

  Future<void> _bootstrap() async {
    await ref.read(settingsControllerProvider.notifier).load();
    await ref.read(permissionsControllerProvider.notifier).refresh();
    final settings = ref.read(settingsControllerProvider).settings;
    await ref.read(voiceActivationProvider.notifier).initialize(
          wakeWords: settings?.wakeWords,
        );
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

    final voiceController = ref.read(voiceActivationProvider.notifier);
    final voiceState = ref.read(voiceActivationProvider);
    if (voiceState.isActive) {
      return;
    }

    await voiceController.start(
      onWakeWordDetected: (wakeWord) {
        if (!mounted) {
          return;
        }
        final isEmergency = NoctrosConstants.emergencyPhrases
            .any((phrase) => wakeWord.toLowerCase().contains(phrase));
        if (isEmergency) {
          ref.read(appRouterProvider).go(EmergencyScreen.routePath);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Emergency phrase detected: $wakeWord')),
          );
          return;
        }
        ref.read(appRouterProvider).go(ChatScreen.routePath);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wake word detected: $wakeWord')),
        );
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
