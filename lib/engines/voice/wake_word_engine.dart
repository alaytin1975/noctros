import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/constants/noctros_constants.dart';
import 'noise_filter.dart';
import 'speech_recognition_service.dart';

/// Battery-aware hotword detection using duty-cycled offline STT.
class WakeWordEngine {
  WakeWordEngine({
    required SpeechRecognitionService speechRecognition,
    Battery? battery,
    NoiseFilter noiseFilter = const NoiseFilter(),
  })  : _speechRecognition = speechRecognition,
        _battery = battery ?? Battery(),
        _noiseFilter = noiseFilter;

  final SpeechRecognitionService _speechRecognition;
  final Battery _battery;
  final NoiseFilter _noiseFilter;

  bool _active = false;
  List<String> _wakeWords = NoctrosConstants.defaultWakeWords;
  Timer? _restartTimer;
  void Function(String wakeWord, String transcript)? _onDetected;
  Duration _listenDuration = const Duration(seconds: 14);
  Duration _pauseDuration = const Duration(seconds: 5);

  bool get isActive => _active;

  Future<void> configure({
    required List<String> wakeWords,
  }) async {
    _wakeWords = wakeWords
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toList();
    if (_wakeWords.isEmpty) {
      _wakeWords = NoctrosConstants.defaultWakeWords;
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
    await _applyBatteryAwareDutyCycle();
    _speechRecognition.onStatus = _handleStatus;
    await _beginCycle();
  }

  Future<void> stop() async {
    _active = false;
    _onDetected = null;
    _restartTimer?.cancel();
    _restartTimer = null;
    await _speechRecognition.stop();
  }

  Future<void> _applyBatteryAwareDutyCycle() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      if (state == BatteryState.charging || state == BatteryState.full) {
        _listenDuration = const Duration(seconds: 18);
        _pauseDuration = const Duration(seconds: 3);
      } else if (level <= 15) {
        _listenDuration = const Duration(seconds: 8);
        _pauseDuration = const Duration(seconds: 12);
      } else if (level <= 30) {
        _listenDuration = const Duration(seconds: 10);
        _pauseDuration = const Duration(seconds: 8);
      } else {
        _listenDuration = const Duration(seconds: 14);
        _pauseDuration = const Duration(seconds: 5);
      }
    } catch (_) {
      _listenDuration = const Duration(seconds: 14);
      _pauseDuration = const Duration(seconds: 5);
    }
  }

  void _handleStatus(String status) {
    if (!_active) {
      return;
    }
    if (status == SpeechToText.notListeningStatus ||
        status == SpeechToText.doneStatus) {
      _scheduleRestart();
    }
  }

  Future<void> _beginCycle() async {
    if (!_active) {
      return;
    }
    await _applyBatteryAwareDutyCycle();
    await _speechRecognition.listen(
      mode: ListenMode.confirmation,
      listenFor: _listenDuration,
      pauseFor: _pauseDuration,
      partialResults: true,
      onPartial: (partial) {
        final wake = detect(partial);
        if (wake != null) {
          _onDetected?.call(wake, partial);
        }
      },
      onFinal: (transcript, {required backend, confidence = 1.0}) {
        final cleaned = _noiseFilter.cleanTranscript(transcript);
        final wake = detect(cleaned);
        if (wake != null) {
          _onDetected?.call(wake, cleaned);
        }
      },
    );
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(_pauseDuration, () {
      if (!_active) {
        return;
      }
      unawaited(_beginCycle());
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
