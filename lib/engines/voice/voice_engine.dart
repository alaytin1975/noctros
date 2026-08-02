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

/// Voice engine coordinating wake-word detection, STT, and TTS.
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
  Timer? _wakeWordRestartTimer;
  void Function(String wakeWord)? _wakeWordCallback;
  Duration _wakeListenDuration = const Duration(seconds: 25);
  Duration _wakePauseDuration = const Duration(seconds: 3);

  VoiceSession get session => _session;
  bool get isWakeWordListening => _wakeWordListening;

  Future<void> initialize({List<String>? wakeWords}) async {
    _wakeWords = wakeWords ?? NoctrosConstants.defaultWakeWords;
    final available = await _speechToText.initialize(
      onStatus: _handleSpeechStatus,
    );
    if (!available) {
      throw const VoiceFailure(
        'Speech recognition is unavailable on this device.',
      );
    }
    await _flutterTts.setSpeechRate(0.48);
    await _flutterTts.setPitch(1.0);
  }

  void _handleSpeechStatus(String status) {
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
  }) async {
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
      ),
    );
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
    _session = _session.copyWith(state: VoiceSessionState.idle);
  }

  /// Battery-conscious wake-word loop: short listen windows with pauses.
  Future<void> startWakeWordListening({
    required void Function(String wakeWord) onWakeWordDetected,
    Duration listenDuration = const Duration(seconds: 25),
    Duration pauseDuration = const Duration(seconds: 3),
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
        listenMode: ListenMode.search,
        partialResults: true,
        listenFor: _wakeListenDuration,
        pauseFor: _wakePauseDuration,
        cancelOnError: false,
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

  Future<void> speak(String text, {String languageCode = 'en-US'}) async {
    _session = _session.copyWith(state: VoiceSessionState.speaking);
    await _flutterTts.setLanguage(languageCode);
    await _flutterTts.speak(text);
    _session = _session.copyWith(state: VoiceSessionState.idle);
  }

  String? _detectWakeWord(String transcript) {
    final normalized = transcript.toLowerCase();
    for (final wakeWord in _wakeWords) {
      if (normalized.contains(wakeWord.toLowerCase())) {
        return wakeWord;
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
