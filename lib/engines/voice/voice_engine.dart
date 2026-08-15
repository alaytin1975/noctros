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
  })  : _speechToTextOverride = speechToText,
        _flutterTtsOverride = flutterTts;

  final SpeechToText? _speechToTextOverride;
  final FlutterTts? _flutterTtsOverride;
  SpeechToText? _speechToText;
  FlutterTts? _flutterTts;

  SpeechToText get _speech =>
      _speechToText ??= _speechToTextOverride ?? SpeechToText();

  FlutterTts get _tts => _flutterTts ??= _flutterTtsOverride ?? FlutterTts();

  VoiceSession _session = const VoiceSession(state: VoiceSessionState.idle);
  List<String> _wakeWords = NoctrosConstants.defaultWakeWords;

  VoiceSession get session => _session;

  Future<void> initialize({List<String>? wakeWords}) async {
    _wakeWords = wakeWords ?? NoctrosConstants.defaultWakeWords;
    final available = await _speech.initialize();
    if (!available) {
      throw const VoiceFailure('Speech recognition is unavailable on this device.');
    }
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
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

    await _speech.listen(
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
      listenMode: ListenMode.dictation,
      partialResults: true,
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
    _session = _session.copyWith(state: VoiceSessionState.idle);
  }

  Future<void> speak(String text, {String languageCode = 'en-US'}) async {
    _session = _session.copyWith(state: VoiceSessionState.speaking);
    await _tts.setLanguage(languageCode);
    await _tts.speak(text);
    _session = _session.copyWith(state: VoiceSessionState.idle);
  }

  String? _detectWakeWord(String transcript) {
    final normalized = transcript.toLowerCase();
    for (final wakeWord in _wakeWords) {
      if (normalized.startsWith(wakeWord.toLowerCase())) {
        return wakeWord;
      }
    }
    return null;
  }

  String _stripWakeWord(String transcript, String? wakeWord) {
    if (wakeWord == null) {
      return transcript.trim();
    }
    return transcript.substring(wakeWord.length).trim();
  }
}
