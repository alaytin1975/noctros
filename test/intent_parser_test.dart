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
  });

  test('parses open camera', () {
    expect(parser.parse('Open Camera').type, DeviceActionType.openCamera);
  });

  test('parses sms commands', () {
    final intent = parser.parse('Send a text to Sarah saying hello');
    expect(intent.type, DeviceActionType.sms);
    expect(intent.parameters['recipient'], 'sarah');
    expect(intent.parameters['body'], 'hello');
  });

  test('parses settings and voice mode', () {
    expect(parser.parse('Open Settings').type, DeviceActionType.openSettings);
    expect(
      parser.parse('Turn on voice mode').type,
      DeviceActionType.enableVoiceMode,
    );
  });

  test('falls back to unknown for chat prompts', () {
    final intent = parser.parse('What is the weather today?');
    expect(intent.type, DeviceActionType.unknown);
    expect(intent.isDeviceAction, isFalse);
  });
}
