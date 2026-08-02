import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/constants/noctros_constants.dart';
import '../../core/errors/noctros_failure.dart';

enum VoiceSessionState {
  idle,
  listening,
  processing,
  speaking,
}

class VoiceSession {
  const VoiceSession({
    required this.state,
    this.partialTranscript = '',
    this.finalTranscript = '',
    this.activeWakeWord,
  });

  final VoiceSessionState state;
  final String partialTranscript;
  final String finalTranscript;
  final String? activeWakeWord;

  VoiceSession copyWith({
    VoiceSessionState? state,
    String? partialTranscript,
    String? finalTranscript,
    String? activeWakeWord,
  }) {
    return VoiceSession(
      state: state ?? this.state,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      finalTranscript: finalTranscript ?? this.finalTranscript,
      activeWakeWord: activeWakeWord ?? this.activeWakeWord,
    );
  }
}

/// Voice engine: wake-word, STT, TTS, interruption, continuous conversation.
class VoiceEngine {
  VoiceEngine({
    SpeechToText? speechToText,
    FlutterTts? flutterTts,
  })  : _speechToText = speechToText ?? SpeechToText(),
        _flutterTts = flutterTts ?? FlutterTts();

  final SpeechToText _speechToText;
  final FlutterTts _flutterTts;

  VoiceSession _session = const VoiceSession(state: VoiceSessionState.idle);
  List<String> _wakeWords = NoctrosConstants.defaultWakeWords;
  bool _wakeWordListening = false;
  bool _continuousConversation = false;
  bool _backgroundServicePrepared = false;
  Timer? _wakeWordRestartTimer;
  void Function(String wakeWord)? _wakeWordCallback;
  void Function(String transcript)? _continuousCallback;
  Duration _wakeListenDuration = const Duration(seconds: 20);
  Duration _wakePauseDuration = const Duration(seconds: 4);
  double _speechRate = 0.48;
  String _localeId = 'en_US';

  VoiceSession get session => _session;
  bool get isWakeWordListening => _wakeWordListening;
  bool get isContinuousConversation => _continuousConversation;
  bool get isBackgroundServicePrepared => _backgroundServicePrepared;
  bool get isSpeaking => _session.state == VoiceSessionState.speaking;

  Future<void> initialize({
    List<String>? wakeWords,
    double speechRate = 0.48,
    String localeId = 'en_US',
  }) async {
    _wakeWords = wakeWords ?? NoctrosConstants.defaultWakeWords;
    _speechRate = speechRate;
    _localeId = localeId;
    final available = await _speechToText.initialize(
      onStatus: _handleSpeechStatus,
    );
    if (!available) {
      throw const VoiceFailure(
        'Speech recognition is unavailable on this device.',
      );
    }
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> configureVoice({
    double? speechRate,
    String? localeId,
    List<String>? wakeWords,
  }) async {
    if (speechRate != null) {
      _speechRate = speechRate;
      await _flutterTts.setSpeechRate(speechRate);
    }
    if (localeId != null) {
      _localeId = localeId;
    }
    if (wakeWords != null) {
      _wakeWords = wakeWords;
    }
  }

  /// Prepares architecture for a future always-on background wake service.
  Future<void> prepareAlwaysListeningBackgroundService() async {
    // Platform foreground-service wiring lands in a later release.
    // This marks readiness and keeps wake-word cycles battery-aware.
    _backgroundServicePrepared = true;
    if (!_wakeWordListening) {
      await startWakeWordListening(
        onWakeWordDetected: (_) {},
        listenDuration: const Duration(seconds: 18),
        pauseDuration: const Duration(seconds: 5),
      );
      await stopWakeWordListening();
    }
  }

  void _handleSpeechStatus(String status) {
    if (_continuousConversation &&
        (status == SpeechToText.notListeningStatus ||
            status == SpeechToText.doneStatus)) {
      unawaited(_restartContinuousListening());
      return;
    }
    if (!_wakeWordListening) {
      return;
    }
    if (status == SpeechToText.notListeningStatus ||
        status == SpeechToText.doneStatus) {
      _scheduleWakeWordRestart();
    }
  }

  Future<void> startListening({
    required void Function(String transcript) onResult,
    void Function(String partial)? onPartial,
    bool continuous = false,
  }) async {
    await interruptSpeech();
    _continuousConversation = continuous;
    _continuousCallback = continuous ? onResult : null;
    _session = _session.copyWith(
      state: VoiceSessionState.listening,
      partialTranscript: '',
      finalTranscript: '',
    );

    await _speechToText.listen(
      onResult: (result) {
        final words = result.recognizedWords.trim();
        if (result.finalResult) {
          final wakeWord = _detectWakeWord(words);
          final command = _stripWakeWord(words, wakeWord);
          _session = _session.copyWith(
            state: VoiceSessionState.processing,
            finalTranscript: command,
            activeWakeWord: wakeWord,
          );
          onResult(command);
        } else {
          _session = _session.copyWith(partialTranscript: words);
          onPartial?.call(words);
        }
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(milliseconds: 1200),
        localeId: _localeId,
      ),
    );
  }

  Future<void> _restartContinuousListening() async {
    if (!_continuousConversation || _continuousCallback == null) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!_continuousConversation) {
      return;
    }
    await startListening(
      onResult: _continuousCallback!,
      continuous: true,
    );
  }

  Future<void> stopListening() async {
    _continuousConversation = false;
    _continuousCallback = null;
    await _speechToText.stop();
    _session = _session.copyWith(state: VoiceSessionState.idle);
  }

  Future<void> startWakeWordListening({
    required void Function(String wakeWord) onWakeWordDetected,
    Duration listenDuration = const Duration(seconds: 20),
    Duration pauseDuration = const Duration(seconds: 4),
  }) async {
    if (_wakeWordListening) {
      return;
    }
    _wakeWordListening = true;
    _wakeWordCallback = onWakeWordDetected;
    _wakeListenDuration = listenDuration;
    _wakePauseDuration = pauseDuration;
    _session = _session.copyWith(state: VoiceSessionState.listening);
    await _beginWakeWordCycle();
  }

  Future<void> stopWakeWordListening() async {
    _wakeWordListening = false;
    _wakeWordCallback = null;
    _wakeWordRestartTimer?.cancel();
    _wakeWordRestartTimer = null;
    await _speechToText.stop();
    _session = _session.copyWith(
      state: VoiceSessionState.idle,
      partialTranscript: '',
      activeWakeWord: null,
    );
  }

  Future<void> _beginWakeWordCycle() async {
    if (!_wakeWordListening) {
      return;
    }

    await _speechToText.listen(
      onResult: (result) {
        final words = result.recognizedWords.trim();
        if (words.isEmpty) {
          return;
        }
        _session = _session.copyWith(partialTranscript: words);
        final wakeWord = _detectWakeWord(words);
        if (wakeWord == null) {
          return;
        }
        _session = _session.copyWith(activeWakeWord: wakeWord);
        _wakeWordCallback?.call(wakeWord);
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        partialResults: true,
        listenFor: _wakeListenDuration,
        pauseFor: _wakePauseDuration,
        cancelOnError: false,
        localeId: _localeId,
      ),
    );
  }

  void _scheduleWakeWordRestart() {
    _wakeWordRestartTimer?.cancel();
    _wakeWordRestartTimer = Timer(_wakePauseDuration, () {
      if (!_wakeWordListening) {
        return;
      }
      unawaited(_beginWakeWordCycle());
    });
  }

  Future<void> speak(String text, {String? languageCode}) async {
    final locale = languageCode ?? _localeId.replaceAll('_', '-');
    _session = _session.copyWith(state: VoiceSessionState.speaking);
    await _flutterTts.setLanguage(locale);
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.speak(text);
    if (_session.state == VoiceSessionState.speaking) {
      _session = _session.copyWith(state: VoiceSessionState.idle);
    }
  }

  Future<void> interruptSpeech() async {
    await _flutterTts.stop();
    if (_session.state == VoiceSessionState.speaking) {
      _session = _session.copyWith(state: VoiceSessionState.idle);
    }
  }

  String? _detectWakeWord(String transcript) {
    final normalized = transcript.toLowerCase();
    for (final wakeWord in _wakeWords) {
      if (normalized.contains(wakeWord.toLowerCase())) {
        return wakeWord;
      }
    }
    // Emergency phrases treated as voice emergency activation signals.
    for (final phrase in NoctrosConstants.emergencyPhrases) {
      if (normalized.contains(phrase)) {
        return phrase;
      }
    }
    return null;
  }

  String _stripWakeWord(String transcript, String? wakeWord) {
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
