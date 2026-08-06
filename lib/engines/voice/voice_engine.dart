import 'dart:async';

import '../../core/constants/noctros_constants.dart';
import '../../domain/entities/noctros_enums.dart';
import 'noise_filter.dart';
import 'speech_recognition_service.dart';
import 'speech_synthesis_service.dart';
import 'voice_session_manager.dart';
import 'wake_word_engine.dart';

export 'voice_session_manager.dart'
    show VoiceSession, VoiceSessionState;

/// Facade over modular voice services for wake-word, STT, TTS, and sessions.
class VoiceEngine {
  VoiceEngine({
    SpeechRecognitionService? speechRecognition,
    SpeechSynthesisService? speechSynthesis,
    WakeWordEngine? wakeWordEngine,
    VoiceSessionManager? sessionManager,
    NoiseFilter noiseFilter = const NoiseFilter(),
  })  : _speechRecognition =
            speechRecognition ?? SpeechRecognitionService(noiseFilter: noiseFilter),
        _speechSynthesis = speechSynthesis ?? SpeechSynthesisService(),
        _sessionManager = sessionManager ?? VoiceSessionManager(),
        _noiseFilter = noiseFilter {
    _wakeWordEngine = wakeWordEngine ??
        WakeWordEngine(
          speechRecognition: _speechRecognition,
          noiseFilter: noiseFilter,
        );
  }

  final SpeechRecognitionService _speechRecognition;
  final SpeechSynthesisService _speechSynthesis;
  late final WakeWordEngine _wakeWordEngine;
  final VoiceSessionManager _sessionManager;
  final NoiseFilter _noiseFilter;

  bool _continuousConversation = false;
  bool _backgroundServicePrepared = false;
  void Function(String transcript)? _continuousCallback;
  List<String> _wakeWords = NoctrosConstants.defaultWakeWords;

  SpeechRecognitionService get speechRecognition => _speechRecognition;
  SpeechSynthesisService get speechSynthesis => _speechSynthesis;
  WakeWordEngine get wakeWordEngine => _wakeWordEngine;
  VoiceSessionManager get sessionManager => _sessionManager;

  VoiceSession get session => _sessionManager.session;
  bool get isWakeWordListening => _wakeWordEngine.isActive;
  bool get isContinuousConversation => _continuousConversation;
  bool get isBackgroundServicePrepared => _backgroundServicePrepared;
  bool get isSpeaking => _speechSynthesis.isSpeaking;

  Future<void> initialize({
    List<String>? wakeWords,
    double speechRate = 0.48,
    double speechPitch = 1.0,
    double speechVolume = 1.0,
    String localeId = 'en_US',
    VoiceGender voiceGender = VoiceGender.system,
    SttBackend sttBackend = SttBackend.auto,
    bool cloudSttFallbackEnabled = true,
  }) async {
    _wakeWords = wakeWords ?? NoctrosConstants.defaultWakeWords;
    await _speechRecognition.initialize(
      localeId: localeId,
      backend: sttBackend,
      cloudFallbackEnabled: cloudSttFallbackEnabled,
    );
    await _speechSynthesis.initialize(
      speechRate: speechRate,
      pitch: speechPitch,
      volume: speechVolume,
      localeId: localeId,
      gender: voiceGender,
    );
    await _wakeWordEngine.configure(wakeWords: _wakeWords);
    _sessionManager.reset();
  }

  Future<void> configureVoice({
    double? speechRate,
    double? speechPitch,
    double? speechVolume,
    String? localeId,
    List<String>? wakeWords,
    VoiceGender? voiceGender,
    SttBackend? sttBackend,
    bool? cloudSttFallbackEnabled,
  }) async {
    if (wakeWords != null) {
      _wakeWords = wakeWords;
      await _wakeWordEngine.configure(wakeWords: wakeWords);
    }
    await _speechRecognition.configure(
      localeId: localeId,
      backend: sttBackend,
      cloudFallbackEnabled: cloudSttFallbackEnabled,
    );
    await _speechSynthesis.configure(
      speechRate: speechRate,
      pitch: speechPitch,
      volume: speechVolume,
      localeId: localeId,
      gender: voiceGender,
    );
  }

  /// Duty-cycled always-listening preparation (battery-aware wake cycles).
  Future<void> prepareAlwaysListeningBackgroundService() async {
    _backgroundServicePrepared = true;
    if (!_wakeWordEngine.isActive) {
      await startWakeWordListening(onWakeWordDetected: (_) {});
      await stopWakeWordListening();
    }
  }

  Future<void> startListening({
    required void Function(String transcript) onResult,
    void Function(String partial)? onPartial,
    bool continuous = false,
  }) async {
    await interruptSpeech();
    await stopWakeWordListening();
    _continuousConversation = continuous;
    _continuousCallback = continuous ? onResult : null;
    _sessionManager.update(
      const VoiceSession(state: VoiceSessionState.listening),
    );

    _speechRecognition.onStatus = (status) {
      if (_continuousConversation &&
          (status == 'notListening' || status == 'done')) {
        unawaited(_restartContinuousListening());
      }
    };

    await _speechRecognition.listen(
      onPartial: (partial) {
        _sessionManager.update(
          _sessionManager.session.copyWith(partialTranscript: partial),
        );
        onPartial?.call(partial);
      },
      onFinal: (words, {required backend, confidence = 1.0}) {
        final wakeWord = _wakeWordEngine.detect(words);
        final command = _noiseFilter.cleanTranscript(
          _wakeWordEngine.stripWakeWord(words, wakeWord),
        );
        _sessionManager.update(
          _sessionManager.session.copyWith(
            state: VoiceSessionState.processing,
            finalTranscript: command,
            activeWakeWord: wakeWord,
          ),
        );
        onResult(command);
      },
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
    await _speechRecognition.stop();
    _sessionManager.setState(VoiceSessionState.idle);
  }

  Future<void> startWakeWordListening({
    required void Function(String wakeWord) onWakeWordDetected,
    Duration listenDuration = const Duration(seconds: 20),
    Duration pauseDuration = const Duration(seconds: 4),
  }) async {
    // listen/pause durations are adapted internally for battery efficiency.
    await _wakeWordEngine.start(
      onDetected: (wakeWord, transcript) {
        _sessionManager.update(
          _sessionManager.session.copyWith(
            state: VoiceSessionState.waking,
            activeWakeWord: wakeWord,
            partialTranscript: transcript,
          ),
        );
        onWakeWordDetected(wakeWord);
      },
    );
    _sessionManager.setState(VoiceSessionState.listening);
  }

  Future<void> stopWakeWordListening() async {
    await _wakeWordEngine.stop();
    if (_sessionManager.session.state != VoiceSessionState.speaking) {
      _sessionManager.update(
        const VoiceSession(state: VoiceSessionState.idle),
      );
    }
  }

  Future<void> speak(String text, {String? languageCode}) async {
    _sessionManager.setState(VoiceSessionState.speaking);
    if (languageCode != null) {
      await _speechSynthesis.configure(
        localeId: languageCode.replaceAll('-', '_'),
      );
    }
    await _speechSynthesis.speak(text);
    if (_sessionManager.session.state == VoiceSessionState.speaking) {
      _sessionManager.setState(VoiceSessionState.idle);
    }
  }

  Future<void> interruptSpeech() async {
    await _speechSynthesis.interrupt();
    if (_sessionManager.session.state == VoiceSessionState.speaking) {
      _sessionManager.setState(VoiceSessionState.idle);
    }
  }
}
