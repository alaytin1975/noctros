import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../domain/entities/voice_entities.dart';
import 'voice_print_manager.dart';

/// Captures short PCM enrollment samples and stores an owner voice print.
class VoiceEnrollment {
  VoiceEnrollment({
    required VoicePrintManager voicePrintManager,
    AudioRecorder? recorder,
  })  : _voicePrintManager = voicePrintManager,
        _recorder = recorder ?? AudioRecorder();

  final VoicePrintManager _voicePrintManager;
  final AudioRecorder _recorder;

  static const requiredSamples = 3;
  static const sampleDuration = Duration(seconds: 3);

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<VoicePrintProfile> enroll({
    String passphraseHint = 'My voice is my passport',
    void Function(int sampleIndex)? onSampleCaptured,
  }) async {
    if (!await hasPermission()) {
      throw StateError('Microphone permission is required for Voice ID.');
    }

    final samples = <Uint8List>[];
    for (var i = 0; i < requiredSamples; i++) {
      final bytes = await _capturePcmSample();
      samples.add(bytes);
      onSampleCaptured?.call(i + 1);
    }

    return _voicePrintManager.enrollFromSamples(
      pcmSamples: samples,
      passphraseHint: passphraseHint,
    );
  }

  Future<VoicePrintProfile> retrain() async {
    final bytes = await _capturePcmSample();
    return _voicePrintManager.retrainWithSample(pcmSample: bytes);
  }

  Future<Uint8List> _capturePcmSample() async {
    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'noctros_voice_enroll_${DateTime.now().microsecondsSinceEpoch}.wav',
    );

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    await Future<void>.delayed(sampleDuration);
    final recordedPath = await _recorder.stop();
    if (recordedPath == null) {
      throw StateError('Failed to capture enrollment sample.');
    }

    final file = File(recordedPath);
    final bytes = await file.readAsBytes();
    try {
      await file.delete();
    } catch (_) {}

    // Skip WAV header if present (44 bytes).
    if (bytes.length > 44 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return Uint8List.sublistView(bytes, 44);
    }
    return bytes;
  }
}
