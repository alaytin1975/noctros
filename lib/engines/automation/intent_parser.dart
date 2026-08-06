import '../../domain/entities/device_action_entities.dart';

typedef IntentMatcher = ParsedDeviceIntent? Function(String normalized, String original);

/// Extensible structured intent parser for device voice/text commands.
class IntentParser {
  IntentParser({List<IntentMatcher>? extraMatchers})
      : _matchers = [..._builtInMatchers, ...?extraMatchers];

  final List<IntentMatcher> _matchers;

  ParsedDeviceIntent parse(String input) {
    final original = input.trim();
    if (original.isEmpty) {
      return ParsedDeviceIntent(
        type: DeviceActionType.unknown,
        rawText: original,
      );
    }

    final normalized = _normalize(original);
    for (final matcher in _matchers) {
      final intent = matcher(normalized, original);
      if (intent != null) {
        return intent;
      }
    }

    return ParsedDeviceIntent(
      type: DeviceActionType.unknown,
      rawText: original,
      confidence: 0,
      displaySummary: 'No device action matched',
    );
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s@.:/\-+]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static final List<IntentMatcher> _builtInMatchers = [
    _matchVoiceMode,
    _matchCall,
    _matchSms,
    _matchEmail,
    _matchNavigate,
    _matchFlashlight,
    _matchMusic,
    _matchOpenBrowser,
    _matchOpenSettings,
    _matchOpenSystemSurface,
    _matchOpenApp,
  ];

  static ParsedDeviceIntent? _matchVoiceMode(String n, String original) {
    if (RegExp(r'\b(turn on|enable|start)\s+(voice mode|continuous voice)\b')
            .hasMatch(n) ||
        n == 'voice mode') {
      return ParsedDeviceIntent(
        type: DeviceActionType.enableVoiceMode,
        rawText: original,
        confidence: 0.95,
        displaySummary: 'Enable voice mode',
      );
    }
    return null;
  }

  static ParsedDeviceIntent? _matchCall(String n, String original) {
    final match = RegExp(
      r'^(?:hey noctros|noctros)?\s*(?:please\s+)?(?:call|dial|phone)\s+(.+)$',
    ).firstMatch(n);
    if (match == null) {
      return null;
    }
    final target = match.group(1)!.trim();
    final isNumber = RegExp(r'^[\d\s+\-()]+$').hasMatch(target);
    return ParsedDeviceIntent(
      type: DeviceActionType.call,
      rawText: original,
      confidence: 0.92,
      requiresConfirmation: true,
      sensitivity: ActionSensitivity.high,
      parameters: {
        isNumber ? 'phoneNumber' : 'contactName': target,
      },
      displaySummary: 'Call $target',
    );
  }

  static ParsedDeviceIntent? _matchSms(String n, String original) {
    final withBody = RegExp(
      r'^(?:send\s+)?(?:a\s+)?(?:text|sms|message)\s+to\s+(.+?)(?:\s+(?:saying|that says|with)\s+(.+))?$',
    ).firstMatch(n);
    if (withBody == null) {
      return null;
    }
    final recipient = withBody.group(1)!.trim();
    final body = withBody.group(2)?.trim() ?? '';
    return ParsedDeviceIntent(
      type: DeviceActionType.sms,
      rawText: original,
      confidence: 0.9,
      requiresConfirmation: true,
      sensitivity: ActionSensitivity.high,
      parameters: {
        'recipient': recipient,
        if (body.isNotEmpty) 'body': body,
      },
      displaySummary: body.isEmpty
          ? 'Open SMS to $recipient'
          : 'Text $recipient: $body',
    );
  }

  static ParsedDeviceIntent? _matchEmail(String n, String original) {
    final match = RegExp(
      r'^(?:send\s+)?(?:an?\s+)?email\s+to\s+(\S+)(?:\s+(?:about|subject)\s+(.+?)(?:\s+body\s+(.+))?)?$',
    ).firstMatch(n);
    if (match == null) {
      return null;
    }
    return ParsedDeviceIntent(
      type: DeviceActionType.email,
      rawText: original,
      confidence: 0.88,
      requiresConfirmation: true,
      sensitivity: ActionSensitivity.medium,
      parameters: {
        'email': match.group(1)!,
        if ((match.group(2) ?? '').isNotEmpty) 'subject': match.group(2)!,
        if ((match.group(3) ?? '').isNotEmpty) 'body': match.group(3)!,
      },
      displaySummary: 'Email ${match.group(1)}',
    );
  }

  static ParsedDeviceIntent? _matchNavigate(String n, String original) {
    final match = RegExp(
      r'^(?:navigate|directions?|take me|drive|go)\s+(?:to\s+)?(.+)$',
    ).firstMatch(n);
    if (match == null) {
      return null;
    }
    final destination = match.group(1)!.trim();
    return ParsedDeviceIntent(
      type: DeviceActionType.navigate,
      rawText: original,
      confidence: 0.93,
      requiresConfirmation: true,
      sensitivity: ActionSensitivity.medium,
      parameters: {'destination': destination},
      displaySummary: 'Navigate to $destination',
    );
  }

  static ParsedDeviceIntent? _matchOpenBrowser(String n, String original) {
    final urlMatch = RegExp(
      r'^(?:open|browse|go to)\s+((?:https?:\/\/)?[\w.-]+\.[\w]{2,}(?:[\/\w\-.?=&%]*)?)$',
    ).firstMatch(n);
    if (urlMatch != null) {
      var url = urlMatch.group(1)!;
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }
      return ParsedDeviceIntent(
        type: DeviceActionType.openBrowser,
        rawText: original,
        confidence: 0.9,
        parameters: {'url': url},
        displaySummary: 'Open $url',
      );
    }
    if (RegExp(r'^open\s+(browser|chrome|safari)$').hasMatch(n)) {
      return ParsedDeviceIntent(
        type: DeviceActionType.openBrowser,
        rawText: original,
        confidence: 0.85,
        parameters: {'url': 'https://www.google.com'},
        displaySummary: 'Open browser',
      );
    }
    return null;
  }

  static ParsedDeviceIntent? _matchOpenSettings(String n, String original) {
    if (!n.contains('settings') &&
        !n.contains('wifi') &&
        !n.contains('wi-fi') &&
        !n.contains('bluetooth')) {
      return null;
    }

    DeviceSettingsTarget target = DeviceSettingsTarget.main;
    if (n.contains('wifi') || n.contains('wi-fi')) {
      target = DeviceSettingsTarget.wifi;
    } else if (n.contains('bluetooth')) {
      target = DeviceSettingsTarget.bluetooth;
    } else if (n.contains('display') || n.contains('brightness')) {
      target = DeviceSettingsTarget.display;
    } else if (n.contains('sound') || n.contains('volume') || n.contains('audio')) {
      target = DeviceSettingsTarget.sound;
    } else if (n.contains('location') || n.contains('gps')) {
      target = DeviceSettingsTarget.location;
    } else if (n.contains('battery')) {
      target = DeviceSettingsTarget.battery;
    } else if (n.contains('security') || n.contains('privacy')) {
      target = DeviceSettingsTarget.security;
    } else if (n.contains('app')) {
      target = DeviceSettingsTarget.apps;
    } else if (!RegExp(r'\bopen\s+settings\b').hasMatch(n) &&
        !RegExp(r'\bsettings\b').hasMatch(n)) {
      return null;
    }

    return ParsedDeviceIntent(
      type: DeviceActionType.openSettings,
      rawText: original,
      confidence: 0.9,
      parameters: {'target': target.name},
      displaySummary: 'Open ${target.name} settings',
    );
  }

  static ParsedDeviceIntent? _matchFlashlight(String n, String original) {
    if (RegExp(r'\b(turn on|enable|open)\s+(the\s+)?(flashlight|torch)\b')
        .hasMatch(n)) {
      return ParsedDeviceIntent(
        type: DeviceActionType.toggleFlashlight,
        rawText: original,
        confidence: 0.94,
        parameters: {'state': 'on'},
        displaySummary: 'Turn on flashlight',
      );
    }
    if (RegExp(r'\b(turn off|disable|close)\s+(the\s+)?(flashlight|torch)\b')
        .hasMatch(n)) {
      return ParsedDeviceIntent(
        type: DeviceActionType.toggleFlashlight,
        rawText: original,
        confidence: 0.94,
        parameters: {'state': 'off'},
        displaySummary: 'Turn off flashlight',
      );
    }
    if (RegExp(r'\b(flashlight|torch)\b').hasMatch(n) &&
        RegExp(r'\b(on|off|toggle)\b').hasMatch(n)) {
      final on = n.contains('on') && !n.contains('off');
      return ParsedDeviceIntent(
        type: DeviceActionType.toggleFlashlight,
        rawText: original,
        confidence: 0.9,
        parameters: {'state': on ? 'on' : 'off'},
        displaySummary: on ? 'Turn on flashlight' : 'Turn off flashlight',
      );
    }
    return null;
  }

  static ParsedDeviceIntent? _matchMusic(String n, String original) {
    if (RegExp(r'\b(play|open|start)\s+(music|spotify|songs?)\b').hasMatch(n) ||
        n == 'play music') {
      return ParsedDeviceIntent(
        type: DeviceActionType.playMusic,
        rawText: original,
        confidence: 0.9,
        parameters: {'appName': n.contains('spotify') ? 'spotify' : 'music'},
        displaySummary: 'Play music',
      );
    }
    return null;
  }

  static ParsedDeviceIntent? _matchOpenSystemSurface(String n, String original) {
    final map = <RegExp, DeviceActionType>{
      RegExp(r'\bopen\s+contacts?\b'): DeviceActionType.openContacts,
      RegExp(r'\bopen\s+calendar\b'): DeviceActionType.openCalendar,
      RegExp(r'\bopen\s+(clock|alarm|timer)\b'): DeviceActionType.openClock,
      RegExp(r'\bopen\s+camera\b'): DeviceActionType.openCamera,
      RegExp(r'\bopen\s+(gallery|photos|photos app)\b'):
          DeviceActionType.openGallery,
    };

    for (final entry in map.entries) {
      if (entry.key.hasMatch(n)) {
        return ParsedDeviceIntent(
          type: entry.value,
          rawText: original,
          confidence: 0.91,
          displaySummary: 'Open ${entry.value.name.replaceFirst('open', '')}',
        );
      }
    }
    return null;
  }

  static ParsedDeviceIntent? _matchOpenApp(String n, String original) {
    final match = RegExp(r'^open\s+(.+)$').firstMatch(n);
    if (match == null) {
      return null;
    }
    final appName = match.group(1)!.trim();
    if (appName.isEmpty ||
        appName.contains('settings') ||
        appName.contains('camera') ||
        appName.contains('browser')) {
      return null;
    }
    return ParsedDeviceIntent(
      type: DeviceActionType.openApp,
      rawText: original,
      confidence: 0.86,
      parameters: {'appName': appName},
      displaySummary: 'Open $appName',
    );
  }
}
