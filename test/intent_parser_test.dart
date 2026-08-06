import 'package:flutter_test/flutter_test.dart';
import 'package:noctros/domain/entities/device_action_entities.dart';
import 'package:noctros/engines/automation/intent_parser.dart';

void main() {
  late IntentParser parser;

  setUp(() {
    parser = IntentParser();
  });

  test('parses call commands', () {
    final intent = parser.parse('Call John');
    expect(intent.type, DeviceActionType.call);
    expect(intent.parameters['contactName'], 'john');
    expect(intent.requiresConfirmation, isTrue);
  });

  test('parses navigation commands', () {
    final intent = parser.parse('Navigate to home');
    expect(intent.type, DeviceActionType.navigate);
    expect(intent.parameters['destination'], 'home');
  });

  test('parses open app commands', () {
    expect(parser.parse('Open WhatsApp').type, DeviceActionType.openApp);
    expect(parser.parse('Open Spotify').parameters['appName'], 'spotify');
    expect(parser.parse('Open YouTube').parameters['appName'], 'youtube');
    expect(parser.parse('Open Chrome').type, DeviceActionType.openBrowser);
    expect(parser.parse('Open Maps').parameters['appName'], 'maps');
  });

  test('parses open camera and take photo', () {
    expect(parser.parse('Open Camera').type, DeviceActionType.openCamera);
    expect(parser.parse('take a photo').type, DeviceActionType.openCamera);
    expect(parser.parse('Noctros, open camera').type, DeviceActionType.openCamera);
  });

  test('parses gallery flashlight calculator settings', () {
    expect(parser.parse('Open Gallery').type, DeviceActionType.openGallery);
    expect(parser.parse('Open Settings').type, DeviceActionType.openSettings);
    expect(
      parser.parse('open flashlight').type,
      DeviceActionType.toggleFlashlight,
    );
    expect(
      parser.parse('turn flashlight on').parameters['state'],
      'on',
    );
    expect(
      parser.parse('turn flashlight off').parameters['state'],
      'off',
    );
    expect(
      parser.parse('Open Calculator').parameters['appName'],
      'calculator',
    );
  });

  test('parses sms commands', () {
    final intent = parser.parse('Send a text to Sarah saying hello');
    expect(intent.type, DeviceActionType.sms);
    expect(intent.parameters['recipient'], 'sarah');
    expect(intent.parameters['body'], 'hello');
    expect(parser.parse('send SMS').type, DeviceActionType.sms);
  });

  test('parses settings and voice mode', () {
    expect(parser.parse('Open Settings').type, DeviceActionType.openSettings);
    expect(
      parser.parse('Turn on voice mode').type,
      DeviceActionType.enableVoiceMode,
    );
  });

  test('parses Turkish device commands', () {
    expect(parser.parse('kamerayı aç').type, DeviceActionType.openCamera);
    expect(parser.parse('fotoğraf çek').type, DeviceActionType.openCamera);
    expect(parser.parse('galeriyi aç').type, DeviceActionType.openGallery);
    expect(parser.parse('ayarları aç').type, DeviceActionType.openSettings);
    expect(
      parser.parse('feneri aç').type,
      DeviceActionType.toggleFlashlight,
    );
    expect(
      parser.parse('feneri kapat').parameters['state'],
      'off',
    );
    expect(
      parser.parse('hesap makinesi aç').parameters['appName'],
      'calculator',
    );
    expect(parser.parse('whatsapp aç').parameters['appName'], 'whatsapp');
    expect(
      parser.parse('yol tarifi istanbul').type,
      DeviceActionType.navigate,
    );
  });

  test('falls back to unknown for chat prompts', () {
    final intent = parser.parse('What is the weather today?');
    expect(intent.type, DeviceActionType.unknown);
    expect(intent.isDeviceAction, isFalse);
  });
}
