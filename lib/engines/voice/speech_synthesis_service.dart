import 'dart:async';
import 'dart:collection';

import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/entities/noctros_enums.dart';

class TtsUtterance {
  const TtsUtterance({
    required this.id,
    required this.text,
    this.priority = 0,
  });

  final String id;
  final String text;
  final int priority;
}

/// Offline-first TTS with interrupt support, gender preference, and queueing.
class SpeechSynthesisService {
  SpeechSynthesisService({FlutterTts? flutterTts})
      : _tts = flutterTts ?? FlutterTts();

  final FlutterTts _tts;
  final Queue<TtsUtterance> _queue = Queue<TtsUtterance>();
  bool _speaking = false;
  bool _initialized = false;
  double _speechRate = 0.48;
  double _pitch = 1.0;
  double _volume = 1.0;
  String _localeId = 'en_US';
  VoiceGender _gender = VoiceGender.system;
  Completer<void>? _speakCompleter;

  bool get isSpeaking => _speaking;

  Future<void> initialize({
    double speechRate = 0.48,
    double pitch = 1.0,
    double volume = 1.0,
    String localeId = 'en_US',
    VoiceGender gender = VoiceGender.system,
  }) async {
    _speechRate = speechRate;
    _pitch = pitch;
    _volume = volume;
    _localeId = localeId;
    _gender = gender;
    await _tts.awaitSpeakCompletion(true);
    await _applyVoiceSettings();
    _tts.setCompletionHandler(() {
      _speaking = false;
      _speakCompleter?.complete();
      _speakCompleter = null;
      unawaited(_drainQueue());
    });
    _tts.setCancelHandler(() {
      _speaking = false;
      _speakCompleter?.complete();
      _speakCompleter = null;
    });
    _initialized = true;
  }

  Future<void> configure({
    double? speechRate,
    double? pitch,
    double? volume,
    String? localeId,
    VoiceGender? gender,
  }) async {
    if (speechRate != null) {
      _speechRate = speechRate;
    }
    if (pitch != null) {
      _pitch = pitch;
    }
    if (volume != null) {
      _volume = volume;
    }
    if (localeId != null) {
      _localeId = localeId;
    }
    if (gender != null) {
      _gender = gender;
    }
    if (_initialized) {
      await _applyVoiceSettings();
    }
  }

  Future<void> speak(
    String text, {
    bool enqueue = false,
    int priority = 0,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final utterance = TtsUtterance(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: trimmed,
      priority: priority,
    );
    if (enqueue && _speaking) {
      _queue.add(utterance);
      return;
    }
    await interrupt();
    await _speakNow(utterance);
  }

  Future<void> interrupt() async {
    _queue.clear();
    await _tts.stop();
    _speaking = false;
    if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
      _speakCompleter!.complete();
    }
    _speakCompleter = null;
  }

  Future<void> _speakNow(TtsUtterance utterance) async {
    await _applyVoiceSettings();
    _speaking = true;
    _speakCompleter = Completer<void>();
    await _tts.speak(utterance.text);
    await _speakCompleter?.future;
  }

  Future<void> _drainQueue() async {
    if (_queue.isEmpty || _speaking) {
      return;
    }
    final next = _queue.removeFirst();
    await _speakNow(next);
  }

  Future<void> _applyVoiceSettings() async {
    final locale = _localeId.replaceAll('_', '-');
    await _tts.setLanguage(locale);
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(_pitch.clamp(0.5, 2.0));
    await _tts.setVolume(_volume.clamp(0.0, 1.0));
    await _applyGenderVoice();
  }

  Future<void> _applyGenderVoice() async {
    if (_gender == VoiceGender.system) {
      return;
    }
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) {
        return;
      }
      final locale = _localeId.replaceAll('_', '-').toLowerCase();
      final preferred = _gender == VoiceGender.female
          ? ['female', 'femma', 'samantha', 'karen', 'moira', 'tessa']
          : ['male', 'daniel', 'alex', 'tom', 'fred', 'aaron'];
      Map<Object?, Object?>? match;
      for (final voice in voices) {
        if (voice is! Map) {
          continue;
        }
        final voiceMap = Map<Object?, Object?>.from(voice);
        final name = '${voiceMap['name']}'.toLowerCase();
        final localeName = '${voiceMap['locale']}'.toLowerCase();
        if (!localeName.contains(locale.split('-').first)) {
          continue;
        }
        if (preferred.any(name.contains)) {
          match = voiceMap;
          break;
        }
      }
      if (match != null) {
        await _tts.setVoice({
          'name': '${match['name']}',
          'locale': '${match['locale']}',
        });
      }
    } catch (_) {
      // Platform may not expose voice enumeration; keep defaults.
    }
  }
}
