import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engines/voice/voice_session_manager.dart';

enum AssistantVisualState {
  idle,
  listening,
  thinking,
  speaking,
}

class AssistantUiState {
  const AssistantUiState({
    this.visual = AssistantVisualState.idle,
    this.statusLabel = 'Ready',
    this.partialTranscript = '',
  });

  final AssistantVisualState visual;
  final String statusLabel;
  final String partialTranscript;

  AssistantUiState copyWith({
    AssistantVisualState? visual,
    String? statusLabel,
    String? partialTranscript,
  }) {
    return AssistantUiState(
      visual: visual ?? this.visual,
      statusLabel: statusLabel ?? this.statusLabel,
      partialTranscript: partialTranscript ?? this.partialTranscript,
    );
  }
}

class AssistantUiController extends StateNotifier<AssistantUiState> {
  AssistantUiController() : super(const AssistantUiState());

  void setIdle([String label = 'Ready']) {
    state = AssistantUiState(visual: AssistantVisualState.idle, statusLabel: label);
  }

  void setListening([String label = 'Listening…']) {
    state = state.copyWith(
      visual: AssistantVisualState.listening,
      statusLabel: label,
    );
  }

  void setThinking([String label = 'Thinking…']) {
    state = state.copyWith(
      visual: AssistantVisualState.thinking,
      statusLabel: label,
      partialTranscript: '',
    );
  }

  void setSpeaking([String label = 'Speaking…']) {
    state = state.copyWith(
      visual: AssistantVisualState.speaking,
      statusLabel: label,
    );
  }

  void setPartial(String partial) {
    state = state.copyWith(partialTranscript: partial);
  }

  void syncFromVoiceSession(VoiceSession session) {
    switch (session.state) {
      case VoiceSessionState.listening:
      case VoiceSessionState.waking:
        setListening();
        setPartial(session.partialTranscript);
      case VoiceSessionState.processing:
      case VoiceSessionState.verifying:
        setThinking();
      case VoiceSessionState.speaking:
        setSpeaking();
      case VoiceSessionState.emergency:
        setListening('Emergency');
      case VoiceSessionState.idle:
        setIdle();
    }
  }
}

final assistantUiProvider =
    StateNotifierProvider<AssistantUiController, AssistantUiState>((ref) {
  return AssistantUiController();
});
