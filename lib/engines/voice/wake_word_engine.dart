import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

import '../../core/constants/noctros_constants.dart';
import 'noise_filter.dart';
import 'speech_recognition_service.dart';

/// Silent always-on hotword detection with stable mic sessions.
///
/// Uses one long recognition session and only restarts on genuine end/error
/// with exponential backoff — never rapid open/close cycles (avoids beeps).
class WakeWordEngine {
  WakeWordEngine({
    required SpeechRecognitionService speechRecognition,
    NoiseFilter noiseFilter = const NoiseFilter(),
  })  : _speechRecognition = speechRecognition,
        _noiseFilter = noiseFilter;

  final SpeechRecognitionService _speechRecognition;
  final NoiseFilter _noiseFilter;

  static const _sessionListenFor = Duration(minutes: 30);
  static const _sessionPauseFor = Duration(seconds: 45);
  static const _minRestartGap = Duration(seconds: 3);
  static const _maxBackoff = Duration(seconds: 30);
  static const _detectionCooldown = Duration(milliseconds: 1800);

  bool _active = false;
  bool _sessionOpen = false;
  bool _restartScheduled = false;
  bool _detectionLocked = false;
  int _consecutiveFailures = 0;
  DateTime? _lastRestartAt;
  DateTime? _lastDetectionAt;
  List<String> _wakeWords = NoctrosConstants.defaultWakeWords;
  Timer? _restartTimer;
  void Function(String wakeWord, String transcript)? _onDetected;

  bool get isActive => _active;

  Future<void> configure({
    required List<String> wakeWords,
  }) async {
    _wakeWords = wakeWords
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toList();
    if (_wakeWords.isEmpty) {
      _wakeWords = const ['Noctros', 'Hey Noctros'];
    }
  }

  Future<void> start({
    required void Function(String wakeWord, String transcript) onDetected,
  }) async {
    if (_active) {
      return;
    }
    _active = true;
    _onDetected = onDetected;
    _consecutiveFailures = 0;
    _restartScheduled = false;
    _speechRecognition.onStatus = _handleStatus;
    await _ensureListeningSession();
  }

  Future<void> stop() async {
    _active = false;
    _onDetected = null;
    _sessionOpen = false;
    _restartScheduled = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    await _speechRecognition.stop();
  }

  void _handleStatus(String status) {
    if (!_active) {
      return;
    }
    if (status.startsWith('error:')) {
      _sessionOpen = false;
      _consecutiveFailures++;
      _scheduleRestart(errorRecovery: true);
      return;
    }
    if (status == SpeechToText.notListeningStatus ||
        status == SpeechToText.doneStatus) {
      _sessionOpen = false;
      _scheduleRestart(errorRecovery: false);
    } else if (status == SpeechToText.listeningStatus) {
      _sessionOpen = true;
      _consecutiveFailures = 0;
    }
  }

  Future<void> _ensureListeningSession() async {
    if (!_active || _sessionOpen || _speechRecognition.isListening) {
      return;
    }

    final now = DateTime.now();
    if (_lastRestartAt != null &&
        now.difference(_lastRestartAt!) < _minRestartGap) {
      _scheduleRestart(errorRecovery: false);
      return;
    }
    _lastRestartAt = now;

    try {
      await _speechRecognition.listen(
        mode: ListenMode.confirmation,
        listenFor: _sessionListenFor,
        pauseFor: _sessionPauseFor,
        partialResults: true,
        onPartial: _onTranscript,
        onFinal: (transcript, {required backend, confidence = 1.0}) {
          _onTranscript(_noiseFilter.cleanTranscript(transcript));
        },
      );
      _sessionOpen = true;
      _consecutiveFailures = 0;
    } catch (_) {
      _sessionOpen = false;
      _consecutiveFailures++;
      _scheduleRestart(errorRecovery: true);
    }
  }

  void _onTranscript(String words) {
    if (!_active || words.isEmpty || _detectionLocked) {
      return;
    }
    final wake = detect(words);
    if (wake == null) {
      return;
    }
    final now = DateTime.now();
    if (_lastDetectionAt != null &&
        now.difference(_lastDetectionAt!) < _detectionCooldown) {
      return;
    }
    _lastDetectionAt = now;
    _detectionLocked = true;
    _onDetected?.call(wake, words);
    // Unlock after cooldown so the next wake can fire after pipeline returns.
    Future<void>.delayed(_detectionCooldown, () {
      _detectionLocked = false;
    });
  }

  void _scheduleRestart({required bool errorRecovery}) {
    if (!_active || _restartScheduled) {
      return;
    }
    _restartScheduled = true;
    _restartTimer?.cancel();

    final backoffSeconds = errorRecovery
        ? (2 << _consecutiveFailures.clamp(0, 4)).clamp(3, 30)
        : _minRestartGap.inSeconds;
    final delay = Duration(
      seconds: backoffSeconds.clamp(
        _minRestartGap.inSeconds,
        _maxBackoff.inSeconds,
      ),
    );

    _restartTimer = Timer(delay, () {
      _restartScheduled = false;
      if (!_active) {
        return;
      }
      unawaited(_ensureListeningSession());
    });
  }

  String? detect(String transcript) {
    final normalized = transcript.toLowerCase();
    for (final wakeWord in _wakeWords) {
      if (normalized.contains(wakeWord.toLowerCase())) {
        return wakeWord;
      }
    }
    for (final phrase in NoctrosConstants.emergencyPhrases) {
      if (normalized.contains(phrase)) {
        return phrase;
      }
    }
    return null;
  }

  String stripWakeWord(String transcript, String? wakeWord) {
    if (wakeWord == null) {
      return transcript.trim();
    }
    final index = transcript.toLowerCase().indexOf(wakeWord.toLowerCase());
    if (index < 0) {
      return transcript.trim();
    }
    return transcript.substring(index + wakeWord.length).trim();
  }
}
