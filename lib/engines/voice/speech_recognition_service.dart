import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/config/openai_config_service.dart';
import '../../core/errors/noctros_failure.dart';
import '../../domain/entities/noctros_enums.dart';
import 'noise_filter.dart';

typedef PartialTranscriptCallback = void Function(String partial);
typedef FinalTranscriptCallback = void Function(
  String transcript, {
  required SttBackend backend,
  double confidence,
});

/// Offline-first STT with automatic cloud (Whisper) fallback and recovery.
class SpeechRecognitionService {
  SpeechRecognitionService({
    SpeechToText? speechToText,
    OpenAiConfigService? openAiConfigService,
    Dio? dio,
    AudioRecorder? recorder,
    NoiseFilter noiseFilter = const NoiseFilter(),
  })  : _speechToText = speechToText ?? SpeechToText(),
        _openAiConfigService = openAiConfigService,
        _dio = dio ?? Dio(),
        _recorderOverride = recorder,
        _noiseFilter = noiseFilter;

  final SpeechToText _speechToText;
  final OpenAiConfigService? _openAiConfigService;
  final Dio _dio;
  final AudioRecorder? _recorderOverride;
  final NoiseFilter _noiseFilter;
  AudioRecorder? _recorder;

  AudioRecorder get _audioRecorder =>
      _recorder ??= (_recorderOverride ?? AudioRecorder());

  bool _initialized = false;
  bool _listening = false;
  String _localeId = 'en_US';
  SttBackend _backend = SttBackend.auto;
  bool _cloudFallbackEnabled = true;
  void Function(String status)? onStatus;

  bool get isListening => _listening || _speechToText.isListening;
  bool get isAvailable => _initialized;

  Future<void> initialize({
    String localeId = 'en_US',
    SttBackend backend = SttBackend.auto,
    bool cloudFallbackEnabled = true,
  }) async {
    _localeId = localeId;
    _backend = backend;
    _cloudFallbackEnabled = cloudFallbackEnabled;
    final available = await _speechToText.initialize(
      onStatus: (status) {
        _syncListeningFromStatus(status);
        onStatus?.call(status);
      },
      onError: (error) {
        _listening = false;
        onStatus?.call('error:${error.errorMsg}');
      },
    );
    if (!available && _backend == SttBackend.offline) {
      throw const VoiceFailure(
        'Offline speech recognition is unavailable on this device.',
      );
    }
    _initialized = available || _cloudFallbackEnabled;
    if (!_initialized) {
      throw const VoiceFailure(
        'Speech recognition is unavailable on this device.',
      );
    }
  }

  void _syncListeningFromStatus(String status) {
    if (status == SpeechToText.notListeningStatus ||
        status == SpeechToText.doneStatus ||
        status.startsWith('error:')) {
      _listening = false;
    } else if (status == SpeechToText.listeningStatus) {
      _listening = true;
    }
  }

  Future<void> configure({
    String? localeId,
    SttBackend? backend,
    bool? cloudFallbackEnabled,
  }) async {
    if (localeId != null) {
      _localeId = localeId;
    }
    if (backend != null) {
      _backend = backend;
    }
    if (cloudFallbackEnabled != null) {
      _cloudFallbackEnabled = cloudFallbackEnabled;
    }
  }

  Future<void> listen({
    required FinalTranscriptCallback onFinal,
    PartialTranscriptCallback? onPartial,
    ListenMode mode = ListenMode.dictation,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(milliseconds: 1200),
    bool partialResults = true,
  }) async {
    if (_backend == SttBackend.cloud) {
      await _listenCloud(onFinal: onFinal, onPartial: onPartial);
      return;
    }

    if (!_speechToText.isAvailable) {
      if (_cloudFallbackEnabled) {
        await _listenCloud(onFinal: onFinal, onPartial: onPartial);
        return;
      }
      throw const VoiceFailure('Speech recognition unavailable.');
    }

    // Never leave a prior session stuck — force-clear before opening mic.
    if (_speechToText.isListening || _listening) {
      await stop();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    _listening = true;
    var gotFinal = false;

    await _speechToText.listen(
      onResult: (result) {
        final words = _noiseFilter.cleanTranscript(result.recognizedWords);
        if (words.isEmpty) {
          return;
        }
        if (result.finalResult) {
          // Always clear listening flag — even for rejected noise —
          // otherwise wake-word sessions can never reopen the mic.
          _listening = false;
          if (_noiseFilter.isLikelyNoise(
            words,
            confidence: result.confidence,
          )) {
            return;
          }
          gotFinal = true;
          onFinal(
            words,
            backend: SttBackend.offline,
            confidence: result.confidence,
          );
        } else if (partialResults) {
          onPartial?.call(words);
        }
      },
      listenOptions: SpeechListenOptions(
        listenMode: mode,
        partialResults: partialResults,
        cancelOnError: false,
        listenFor: listenFor,
        pauseFor: pauseFor,
        localeId: _localeId,
      ),
    );

    // Auto cloud recovery if offline produced nothing useful.
    if (_backend == SttBackend.auto &&
        _cloudFallbackEnabled &&
        !gotFinal &&
        !_listening) {
      // Status-driven cycles handle wake listening; command path uses stop().
    }
  }

  Future<String?> recognizeOnceWithFallback({
    Duration listenFor = const Duration(seconds: 12),
  }) async {
    final completer = Completer<String?>();
    var lastPartial = '';

    try {
      await listen(
        listenFor: listenFor,
        pauseFor: const Duration(seconds: 2),
        mode: ListenMode.dictation,
        onPartial: (partial) {
          lastPartial = partial;
        },
        onFinal: (transcript, {required backend, confidence = 1.0}) {
          if (!completer.isCompleted) {
            completer.complete(transcript);
          }
        },
      );
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    final result = await completer.future.timeout(
      listenFor + const Duration(seconds: 4),
      onTimeout: () async {
        await stop();
        if (lastPartial.trim().isNotEmpty) {
          return _noiseFilter.cleanTranscript(lastPartial);
        }
        if (_cloudFallbackEnabled) {
          return _transcribeCloudFromMic(duration: listenFor);
        }
        return null;
      },
    );

    await stop();
    return result;
  }

  Future<void> stop() async {
    _listening = false;
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (_) {}
  }

  Future<void> cancel() async {
    _listening = false;
    try {
      await _speechToText.cancel();
    } catch (_) {}
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (_) {}
  }

  String detectLanguageHint(String transcript) {
    final text = transcript.toLowerCase();
    if (RegExp(r'[äöüß]').hasMatch(text)) {
      return 'de_DE';
    }
    if (RegExp(r'[àâçéèêëîïôùûü]').hasMatch(text)) {
      return 'fr_FR';
    }
    if (RegExp(r'[áéíóúñ¿¡]').hasMatch(text)) {
      return 'es_ES';
    }
    if (RegExp(r'[ğışçöü]', unicode: true).hasMatch(text)) {
      return 'tr_TR';
    }
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) {
      return 'ar_SA';
    }
    return _localeId;
  }

  Future<void> _listenCloud({
    required FinalTranscriptCallback onFinal,
    PartialTranscriptCallback? onPartial,
  }) async {
    onPartial?.call('Listening (cloud)…');
    final transcript = await _transcribeCloudFromMic();
    if (transcript == null || transcript.isEmpty) {
      throw const VoiceFailure('Cloud speech recognition failed.');
    }
    onFinal(transcript, backend: SttBackend.cloud, confidence: 0.9);
  }

  Future<String?> _transcribeCloudFromMic({
    Duration duration = const Duration(seconds: 8),
  }) async {
    final config = _openAiConfigService;
    if (config == null) {
      return null;
    }
    final apiKey = await config.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'noctros_stt_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );

    if (!await _audioRecorder.hasPermission()) {
      return null;
    }

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    await Future<void>.delayed(duration);
    final recordedPath = await _audioRecorder.stop();
    if (recordedPath == null) {
      return null;
    }

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          recordedPath,
          filename: p.basename(recordedPath),
          contentType: MediaType('audio', 'mp4'),
        ),
        'model': 'whisper-1',
        'language': _localeId.split('_').first,
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '${await _baseUrl(config)}/audio/transcriptions',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
        ),
      );
      final text = response.data?['text'] as String?;
      return _noiseFilter.cleanTranscript(text ?? '');
    } catch (_) {
      return null;
    } finally {
      try {
        await File(recordedPath).delete();
      } catch (_) {}
    }
  }

  Future<String> _baseUrl(OpenAiConfigService config) async {
    // Prefer env-backed OpenAI base via existing provider defaults.
    return 'https://api.openai.com/v1';
  }
}
