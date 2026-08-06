import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

import '../../core/constants/noctros_constants.dart';
import 'noise_filter.dart';
import 'speech_recognition_service.dart';
import 'voice_pipeline_log.dart';

/// Always-on hotword detection via cycling STT sessions + partial transcripts.
///
/// Android speech recognizers do not support true 30-minute sessions, so we
/// run short dictation cycles and restart immediately when they end.
class WakeWordEngine {
  WakeWordEngine({
    required SpeechRecognitionService speechRecognition,
    NoiseFilter noiseFilter = const NoiseFilter(),
  })  : _speechRecognition = speechRecognition,
        _noiseFilter = noiseFilter;

  final SpeechRecognitionService _speechRecognition;
  final NoiseFilter _noiseFilter;

  /// Practical Android listen window (OS often ends sooner).
  static const _sessionListenFor = Duration(seconds: 12);
  static const _sessionPauseFor = Duration(seconds: 3);
  static const _minRestartGap = Duration(milliseconds: 400);
  static const _maxBackoff = Duration(seconds: 12);
  static const _detectionCooldown = Duration(milliseconds: 1600);
  static const _watchdogInterval = Duration(seconds: 3);

  /// Common STT mishearings of "Noctros".
  static final _fuzzyWake = RegExp(
    r'\b(hey\s+)?'
    r'(noctros|noktros|noctros|noctis|nocturne|nokros|noctrose|'
    r'knock\s*tross|noct\s*ross|no\s*cross|knock\s*ross|noct\s*rose)\b',
    caseSensitive: false,
  );

  bool _active = false;
  bool _sessionOpen = false;
  bool _restartScheduled = false;
  bool _detectionLocked = false;
  bool _startingSession = false;
  int _consecutiveFailures = 0;
  DateTime? _lastRestartAt;
  DateTime? _lastDetectionAt;
  DateTime? _lastPartialAt;
  List<String> _wakeWords = NoctrosConstants.defaultWakeWords;
  Timer? _restartTimer;
  Timer? _watchdog;
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
    VoicePipelineLog.stage(
      'Wake Engine configured',
      'words=${_wakeWords.join(", ")}',
    );
  }

  Future<void> start({
    required void Function(String wakeWord, String transcript) onDetected,
  }) async {
    _onDetected = onDetected;
    if (_active) {
      VoicePipelineLog.stage(
        'Wake Engine already active',
        'sessionOpen=$_sessionOpen listening=${_speechRecognition.isListening}',
      );
      if (!_sessionOpen && !_speechRecognition.isListening) {
        await _ensureListeningSession();
      }
      return;
    }

    _active = true;
    _consecutiveFailures = 0;
    _restartScheduled = false;
    _detectionLocked = false;
    _sessionOpen = false;
    _speechRecognition.onStatus = _handleStatus;
    _startWatchdog();
    VoicePipelineLog.stage('Wake Engine started');
    await _ensureListeningSession();
  }

  Future<void> stop() async {
    final wasActive = _active;
    _active = false;
    _onDetected = null;
    _sessionOpen = false;
    _restartScheduled = false;
    _detectionLocked = false;
    _startingSession = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    _watchdog?.cancel();
    _watchdog = null;
    await _speechRecognition.stop();
    if (wasActive) {
      VoicePipelineLog.stage('Wake Engine stopped');
    }
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(_watchdogInterval, (_) {
      if (!_active || _detectionLocked || _startingSession) {
        return;
      }
      if (!_sessionOpen && !_speechRecognition.isListening) {
        VoicePipelineLog.fail(
          'Wake Engine watchdog',
          'session dead — restarting',
        );
        unawaited(_ensureListeningSession());
      }
    });
  }

  void _handleStatus(String status) {
    if (!_active) {
      return;
    }
    VoicePipelineLog.stage('Wake STT status', status);
    if (status.startsWith('error:')) {
      _sessionOpen = false;
      _consecutiveFailures++;
      VoicePipelineLog.fail('Wake STT', status);
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
    if (!_active || _sessionOpen || _startingSession || _detectionLocked) {
      return;
    }

    if (_speechRecognition.isListening) {
      await _speechRecognition.stop();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    final now = DateTime.now();
    if (_lastRestartAt != null &&
        now.difference(_lastRestartAt!) < _minRestartGap) {
      _scheduleRestart(errorRecovery: false);
      return;
    }
    _lastRestartAt = now;
    _startingSession = true;

    try {
      if (!_speechRecognition.isOfflineSttAvailable) {
        VoicePipelineLog.fail(
          'Wake Engine',
          'offline STT unavailable — reinitializing',
        );
        final ready = await _speechRecognition.ensureInitialized();
        if (!ready) {
          throw StateError('Speech recognition unavailable on this device');
        }
      }

      VoicePipelineLog.stage('Wake STT session starting');
      await _speechRecognition.listen(
        mode: ListenMode.dictation,
        listenFor: _sessionListenFor,
        pauseFor: _sessionPauseFor,
        partialResults: true,
        allowCloudFallback: false,
        onPartial: _onTranscript,
        onFinal: (transcript, {required backend, confidence = 1.0}) {
          _onTranscript(_noiseFilter.cleanTranscript(transcript));
        },
      );
      _sessionOpen = true;
      _consecutiveFailures = 0;
      VoicePipelineLog.stage('Wake STT session open');
    } catch (error) {
      _sessionOpen = false;
      _consecutiveFailures++;
      VoicePipelineLog.fail('Wake STT session start', error);
      _scheduleRestart(errorRecovery: true);
    } finally {
      _startingSession = false;
    }
  }

  void _onTranscript(String words) {
    if (!_active || words.isEmpty || _detectionLocked) {
      return;
    }
    _lastPartialAt = DateTime.now();
    VoicePipelineLog.stage('Wake partial', words);

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
    final callback = _onDetected;
    VoicePipelineLog.stage('Wake Word detected', '$wake <= "$words"');

    // Free the mic immediately, then hand off to the conversation pipeline.
    unawaited(() async {
      try {
        await _speechRecognition.stop();
      } catch (_) {}
      _active = false;
      _sessionOpen = false;
      _watchdog?.cancel();
      _watchdog = null;
      callback?.call(wake, words);
      Future<void>.delayed(_detectionCooldown, () {
        _detectionLocked = false;
      });
    }());
  }

  void _scheduleRestart({required bool errorRecovery}) {
    if (!_active || _restartScheduled || _detectionLocked) {
      return;
    }
    _restartScheduled = true;
    _restartTimer?.cancel();

    final backoffSeconds = errorRecovery
        ? (1 << _consecutiveFailures.clamp(0, 3)).clamp(1, 12)
        : 0;
    final delay = Duration(
      milliseconds: errorRecovery
          ? (backoffSeconds * 1000).clamp(
              _minRestartGap.inMilliseconds,
              _maxBackoff.inMilliseconds,
            )
          : _minRestartGap.inMilliseconds,
    );

    VoicePipelineLog.stage(
      'Wake Engine restart scheduled',
      'in ${delay.inMilliseconds}ms failures=$_consecutiveFailures',
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
    final normalized = transcript.toLowerCase().trim();
    if (normalized.isEmpty) {
      return null;
    }

    // Prefer longer configured wake phrases first.
    final sorted = [..._wakeWords]
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final wakeWord in sorted) {
      if (normalized.contains(wakeWord.toLowerCase())) {
        return wakeWord;
      }
    }

    final fuzzy = _fuzzyWake.firstMatch(normalized);
    if (fuzzy != null) {
      return fuzzy.group(0)!;
    }

    for (final phrase in NoctrosConstants.emergencyPhrases) {
      if (normalized.contains(phrase)) {
        return phrase;
      }
    }
    return null;
  }

  String stripWakeWord(String transcript, String? wakeWord) {
    if (wakeWord == null || wakeWord.isEmpty) {
      return transcript.trim();
    }
    final lower = transcript.toLowerCase();
    final wakeLower = wakeWord.toLowerCase();
    var index = lower.indexOf(wakeLower);
    var length = wakeWord.length;
    if (index < 0) {
      final fuzzy = _fuzzyWake.firstMatch(lower);
      if (fuzzy == null) {
        return transcript.trim();
      }
      index = fuzzy.start;
      length = fuzzy.end - fuzzy.start;
    }
    var remainder = transcript.substring(index + length).trim();
    remainder = remainder.replaceFirst(RegExp(r'^[,.\-:)!]+\s*'), '');
    return remainder.trim();
  }

  /// Exposed for diagnostics / tests.
  DateTime? get lastPartialAt => _lastPartialAt;
}
