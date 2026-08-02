import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/service_locator.dart';
import '../../engines/voice/voice_engine.dart';
import 'noctros_providers.dart';

class VoiceActivationState {
  const VoiceActivationState({
    this.isActive = false,
    this.isInitializing = false,
    this.lastWakeWord,
    this.partialTranscript = '',
    this.sessionState = VoiceSessionState.idle,
    this.errorMessage,
  });

  final bool isActive;
  final bool isInitializing;
  final String? lastWakeWord;
  final String partialTranscript;
  final VoiceSessionState sessionState;
  final String? errorMessage;

  VoiceActivationState copyWith({
    bool? isActive,
    bool? isInitializing,
    String? lastWakeWord,
    String? partialTranscript,
    VoiceSessionState? sessionState,
    String? errorMessage,
  }) {
    return VoiceActivationState(
      isActive: isActive ?? this.isActive,
      isInitializing: isInitializing ?? this.isInitializing,
      lastWakeWord: lastWakeWord ?? this.lastWakeWord,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      sessionState: sessionState ?? this.sessionState,
      errorMessage: errorMessage,
    );
  }
}

class VoiceActivationController extends StateNotifier<VoiceActivationState> {
  VoiceActivationController(this._voiceEngine)
      : super(const VoiceActivationState());

  final VoiceEngine _voiceEngine;
  void Function(String wakeWord)? _onWakeWordDetected;

  Future<void> initialize({
    List<String>? wakeWords,
    double speechRate = 0.48,
    String localeId = 'en_US',
  }) async {
    if (state.isInitializing || state.isActive) {
      return;
    }
    state = state.copyWith(isInitializing: true, errorMessage: null);
    try {
      await _voiceEngine.initialize(
        wakeWords: wakeWords,
        speechRate: speechRate,
        localeId: localeId,
      );
      state = state.copyWith(isInitializing: false);
    } catch (error) {
      state = state.copyWith(
        isInitializing: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> start({
    required void Function(String wakeWord) onWakeWordDetected,
  }) async {
    if (state.isActive) {
      return;
    }
    _onWakeWordDetected = onWakeWordDetected;
    await _voiceEngine.startWakeWordListening(
      onWakeWordDetected: (wakeWord) {
        state = state.copyWith(
          lastWakeWord: wakeWord,
          sessionState: VoiceSessionState.processing,
        );
        _onWakeWordDetected?.call(wakeWord);
      },
    );
    state = state.copyWith(
      isActive: true,
      sessionState: VoiceSessionState.listening,
    );
  }

  Future<void> stop() async {
    await _voiceEngine.stopWakeWordListening();
    state = state.copyWith(
      isActive: false,
      sessionState: VoiceSessionState.idle,
      partialTranscript: '',
    );
  }

  void syncFromEngine() {
    final session = _voiceEngine.session;
    state = state.copyWith(
      partialTranscript: session.partialTranscript,
      sessionState: session.state,
      lastWakeWord: session.activeWakeWord ?? state.lastWakeWord,
    );
  }
}

final voiceEngineProvider = Provider<VoiceEngine>((ref) {
  return ServiceLocator.get<VoiceEngine>();
});

final voiceActivationProvider =
    StateNotifierProvider<VoiceActivationController, VoiceActivationState>(
        (ref) {
  return VoiceActivationController(ref.watch(voiceEngineProvider));
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  final settingsState = ref.watch(settingsControllerProvider);
  final darkModeEnabled = settingsState.settings?.darkModeEnabled ?? false;
  return darkModeEnabled ? ThemeMode.dark : ThemeMode.light;
});
