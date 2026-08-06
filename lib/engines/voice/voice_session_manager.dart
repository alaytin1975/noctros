import 'dart:async';

enum VoiceSessionState {
  idle,
  waking,
  listening,
  verifying,
  processing,
  speaking,
  emergency,
}

class VoiceSession {
  const VoiceSession({
    required this.state,
    this.partialTranscript = '',
    this.finalTranscript = '',
    this.activeWakeWord,
    this.accessDenied = false,
  });

  final VoiceSessionState state;
  final String partialTranscript;
  final String finalTranscript;
  final String? activeWakeWord;
  final bool accessDenied;

  VoiceSession copyWith({
    VoiceSessionState? state,
    String? partialTranscript,
    String? finalTranscript,
    String? activeWakeWord,
    bool? accessDenied,
  }) {
    return VoiceSession(
      state: state ?? this.state,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      finalTranscript: finalTranscript ?? this.finalTranscript,
      activeWakeWord: activeWakeWord ?? this.activeWakeWord,
      accessDenied: accessDenied ?? this.accessDenied,
    );
  }
}

/// Tracks voice pipeline session state with a broadcast stream.
class VoiceSessionManager {
  VoiceSession _session = const VoiceSession(state: VoiceSessionState.idle);
  final _controller = StreamController<VoiceSession>.broadcast();

  VoiceSession get session => _session;
  Stream<VoiceSession> get stream => _controller.stream;

  void update(VoiceSession next) {
    _session = next;
    if (!_controller.isClosed) {
      _controller.add(next);
    }
  }

  void setState(VoiceSessionState state) {
    update(_session.copyWith(state: state));
  }

  void reset() {
    update(const VoiceSession(state: VoiceSessionState.idle));
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
