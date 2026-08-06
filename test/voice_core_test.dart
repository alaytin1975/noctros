import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noctros/core/constants/noctros_constants.dart';
import 'package:noctros/domain/entities/device_action_entities.dart';
import 'package:noctros/domain/entities/noctros_entities.dart';
import 'package:noctros/domain/entities/noctros_enums.dart';
import 'package:noctros/domain/entities/permission_entities.dart';
import 'package:noctros/engines/automation/intent_parser.dart';
import 'package:noctros/engines/security/voice_feature_extractor.dart';
import 'package:noctros/engines/voice/noise_filter.dart';
import 'package:noctros/engines/voice/speech_recognition_service.dart';
import 'package:noctros/engines/voice/wake_word_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NoiseFilter', () {
    const filter = NoiseFilter();

    test('cleans filler words', () {
      expect(filter.cleanTranscript('um hello uh world'), 'hello world');
    });

    test('detects empty noise', () {
      expect(filter.isLikelyNoise('   '), isTrue);
      expect(filter.isLikelyNoise('open camera'), isFalse);
    });
  });

  group('WakeWordEngine', () {
    test('matches configurable assistant names and strips wake word', () async {
      final engine = WakeWordEngine(
        speechRecognition: SpeechRecognitionService(),
      );
      await engine.configure(wakeWords: ['Hey Nova', 'Nova']);
      expect(engine.detect('Hey Nova open camera'), 'Hey Nova');
      expect(
        engine.stripWakeWord('Hey Nova open camera', 'Hey Nova'),
        'open camera',
      );
      expect(engine.detect('help me please'), 'help');
    });

    test('matches fuzzy noctros mishearings', () async {
      final engine = WakeWordEngine(
        speechRecognition: SpeechRecognitionService(),
      );
      await engine.configure(wakeWords: ['Noctros', 'Hey Noctros']);
      expect(engine.detect('Noctros open camera'), 'Noctros');
      expect(engine.detect('hey noktros'), isNotNull);
      expect(engine.detect('knock tross turn on flashlight'), isNotNull);
      expect(
        engine.stripWakeWord('Noctros, open camera', 'Noctros'),
        'open camera',
      );
    });
  });

  group('UserSettings wake words', () {
    test('derivedWakeWords include Hey + name', () {
      final settings = UserSettings.defaults().copyWith(assistantName: 'Jarvis');
      expect(settings.derivedWakeWords, contains('Hey Jarvis'));
      expect(settings.derivedWakeWords, contains('Jarvis'));
    });
  });

  group('VoiceFeatureExtractor', () {
    const extractor = VoiceFeatureExtractor();

    Uint8List tone({required int seed, int samples = 16000}) {
      final bytes = BytesBuilder();
      for (var i = 0; i < samples; i++) {
        final value = (((i * seed) % 20000) - 10000);
        bytes.addByte(value & 0xff);
        bytes.addByte((value >> 8) & 0xff);
      }
      return bytes.toBytes();
    }

    test('extracts fixed-size normalized vector', () {
      final vector = extractor.extractFromPcm16(tone(seed: 17));
      expect(vector.length, VoiceFeatureExtractor.featureSize);
      expect(vector.every((v) => v.abs() <= 1.0 + 1e-9), isTrue);
    });

    test('similar samples score higher than dissimilar ones', () {
      final a = extractor.extractFromPcm16(tone(seed: 17));
      final b = extractor.extractFromPcm16(tone(seed: 18));
      final c = extractor.extractFromPcm16(tone(seed: 91, samples: 8000));
      final similar = extractor.cosineSimilarity(a, b);
      final different = extractor.cosineSimilarity(a, c);
      expect(similar, greaterThan(different));
    });
  });

  group('Emergency phrases', () {
    test('constants include required SOS phrases', () {
      expect(NoctrosConstants.emergencyPhrases, contains('help'));
      expect(NoctrosConstants.emergencyPhrases, contains('emergency'));
      expect(NoctrosConstants.emergencyPhrases, contains('call 112'));
      expect(NoctrosConstants.emergencyPhrases, contains('save me'));
    });
  });

  group('Intent parser voice phone control', () {
    final parser = IntentParser();

    test('parses flashlight and music', () {
      expect(
        parser.parse('Turn on flashlight').type,
        DeviceActionType.toggleFlashlight,
      );
      expect(parser.parse('Play music').type, DeviceActionType.playMusic);
    });
  });

  group('Permissions model', () {
    test('includes voice-critical and emergency permissions', () {
      expect(NoctrosPermission.values, contains(NoctrosPermission.microphone));
      expect(NoctrosPermission.values, contains(NoctrosPermission.phone));
      expect(NoctrosPermission.values, contains(NoctrosPermission.sms));
      expect(
        NoctrosPermission.values,
        contains(NoctrosPermission.ignoreBatteryOptimizations),
      );
    });
  });

  group('Voice access enums', () {
    test('voice gender and backends exist', () {
      expect(VoiceGender.values, contains(VoiceGender.female));
      expect(SttBackend.values, contains(SttBackend.auto));
      expect(VoiceAccessLevel.values, contains(VoiceAccessLevel.emergencyOnly));
    });
  });
}
