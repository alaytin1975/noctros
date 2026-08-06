import '../../domain/entities/device_action_entities.dart';

typedef IntentMatcher = ParsedDeviceIntent? Function(
  String normalized,
  String original,
);

/// Extensible structured intent parser for device voice/text commands.
/// Supports English and Turkish phrases.
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
    var text = input.toLowerCase().trim();
    // Fold Turkish letters to ASCII so STT variants and Dart \w/\b agree.
    const fold = {
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'i̇': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
      'â': 'a',
      'î': 'i',
      'û': 'u',
    };
    for (final entry in fold.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    // Strip leading wake / assistant prefixes (EN + TR).
    text = text.replaceFirst(
      RegExp(r'^(hey\s+)?(noctros|noktros)u?\s*[,:]?\s*'),
      '',
    );
    text = text.replaceFirst(RegExp(r'^(lutfen|please)\s+'), '');
    text = text
        .replaceAll(RegExp(r'[^\w\s@.:/\-+]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text;
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
    _matchOpenCalculator,
    _matchOpenApp,
  ];

  static ParsedDeviceIntent? _matchVoiceMode(String n, String original) {
    if (RegExp(
          r'\b(turn on|enable|start)\s+(voice mode|continuous voice)\b',
        ).hasMatch(n) ||
        RegExp(r'\b(ses modu(nu)?\s+(ac|etkinlestir)|sesli mod)\b')
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
      r'^(?:please\s+)?'
      r'(?:call|dial|phone|ara|telefon et)\s+(.+)$',
    ).firstMatch(n);
    if (match == null) {
      // Turkish: "john ara"
      final tr = RegExp(r'^(.+?)\s+ara$').firstMatch(n);
      if (tr != null &&
          !RegExp(r'\b(open|ac|navigate|yol)\b').hasMatch(tr.group(1)!)) {
        final target = tr.group(1)!.trim();
        if (target.isNotEmpty && target.split(' ').length <= 4) {
          return _callIntent(original, target);
        }
      }
      return null;
    }
    return _callIntent(original, match.group(1)!.trim());
  }

  static ParsedDeviceIntent _callIntent(String original, String target) {
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
      r'^(?:send\s+)?(?:a\s+)?(?:text|sms|message)\s+to\s+(.+?)'
      r'(?:\s+(?:saying|that says|with)\s+(.+))?$',
    ).firstMatch(n);
    if (withBody != null) {
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

    // EN: "send sms" / "open sms" — TR: "sms gonder" / "mesaj gonder"
    if (RegExp(
      r'^(send\s+)?(sms|text|message)$|'
      r'^(sms|mesaj)\s*(gonder|yaz|ac)?$|'
      r'^open\s+(sms|messages?)$|'
      r'^(mesajlari|sms)\s*ac$',
    ).hasMatch(n)) {
      return ParsedDeviceIntent(
        type: DeviceActionType.sms,
        rawText: original,
        confidence: 0.88,
        requiresConfirmation: false,
        sensitivity: ActionSensitivity.medium,
        parameters: const {'recipient': ''},
        displaySummary: 'Open SMS',
      );
    }

    final trSms = RegExp(
      r'^(?:(.+?)(?:na|ya|e)?\s+)?(?:sms|mesaj)\s+(?:gonder|yaz)'
      r'(?:\s+(.+))?$',
    ).firstMatch(n);
    if (trSms != null) {
      final recipient = (trSms.group(1) ?? '').trim();
      final body = (trSms.group(2) ?? '').trim();
      return ParsedDeviceIntent(
        type: DeviceActionType.sms,
        rawText: original,
        confidence: 0.9,
        requiresConfirmation: recipient.isNotEmpty,
        sensitivity: ActionSensitivity.high,
        parameters: {
          'recipient': recipient,
          if (body.isNotEmpty) 'body': body,
        },
        displaySummary: recipient.isEmpty
            ? 'Open SMS'
            : (body.isEmpty
                ? 'Open SMS to $recipient'
                : 'Text $recipient: $body'),
      );
    }
    return null;
  }

  static ParsedDeviceIntent? _matchEmail(String n, String original) {
    final match = RegExp(
      r'^(?:send\s+)?(?:an?\s+)?email\s+to\s+(\S+)'
      r'(?:\s+(?:about|subject)\s+(.+?)(?:\s+body\s+(.+))?)?$',
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
      r'^(?:navigate|directions?|take me|drive|go|'
      r'yol tarifi|navigasyon|git)\s+(?:to\s+|ya\s+|e\s+)?'
      r'(.+)$',
    ).firstMatch(n);
    if (match == null) {
      return null;
    }
    final destination = match.group(1)!.trim();
    if (destination.isEmpty ||
        RegExp(r'^(browser|chrome|safari|settings|ayarlar)$')
            .hasMatch(destination)) {
      return null;
    }
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
      r'^(?:open|browse|go to|ac)\s+'
      r'((?:https?:\/\/)?[\w.-]+\.[\w]{2,}(?:[\/\w\-.?=&%]*)?)$',
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
    if (RegExp(
      r'^(open\s+)?(browser|chrome|safari)$|'
      r'^(chrome|tarayici|safari)\s*ac$|'
      r'^ac\s+(chrome|tarayici|browser)$',
    ).hasMatch(n)) {
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
    final mentionsSettings = n.contains('settings') ||
        n.contains('ayar') ||
        n.contains('wifi') ||
        n.contains('wi-fi') ||
        n.contains('bluetooth') ||
        n.contains('bluetoot');
    if (!mentionsSettings) {
      return null;
    }

    DeviceSettingsTarget target = DeviceSettingsTarget.main;
    if (n.contains('wifi') || n.contains('wi-fi')) {
      target = DeviceSettingsTarget.wifi;
    } else if (n.contains('bluetooth')) {
      target = DeviceSettingsTarget.bluetooth;
    } else if (n.contains('display') ||
        n.contains('brightness') ||
        n.contains('ekran')) {
      target = DeviceSettingsTarget.display;
    } else if (n.contains('sound') ||
        n.contains('volume') ||
        n.contains('audio') ||
        n.contains('ses')) {
      target = DeviceSettingsTarget.sound;
    } else if (n.contains('location') ||
        n.contains('gps') ||
        n.contains('konum')) {
      target = DeviceSettingsTarget.location;
    } else if (n.contains('battery') || n.contains('pil')) {
      target = DeviceSettingsTarget.battery;
    } else if (n.contains('security') ||
        n.contains('privacy') ||
        n.contains('guvenlik')) {
      target = DeviceSettingsTarget.security;
    } else if (RegExp(r'\bapps?\b').hasMatch(n) || n.contains('uygulama')) {
      target = DeviceSettingsTarget.apps;
    } else if (!RegExp(
      r'\b(open\s+)?settings\b|ayarlari?\s*ac|ac\s+ayar',
    ).hasMatch(n)) {
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
    final isOff = RegExp(
      r'\b(turn off|disable|close)\s+(the\s+)?(flashlight|torch|flash)\b|'
      r'\b(flashlight|torch|flash)\s*off\b|'
      r'\b(feneri?|el feneri)\s*(kapat|sondur)\b|'
      r'\b(kapat|sondur)\s+(feneri?|el feneri)\b',
    ).hasMatch(n);
    if (isOff) {
      return ParsedDeviceIntent(
        type: DeviceActionType.toggleFlashlight,
        rawText: original,
        confidence: 0.94,
        parameters: const {'state': 'off'},
        displaySummary: 'Turn off flashlight',
      );
    }

    final isOn = RegExp(
      r'\b(turn on|enable|open)\s+(the\s+)?(flashlight|torch|flash)\b|'
      r'\b(flashlight|torch)\s*on\b|'
      r'^open\s+(flashlight|torch)$|'
      r'^(flashlight|torch)$|'
      r'\b(feneri?|el feneri)\s*(ac|yak|etkinlestir)\b|'
      r'\b(ac|yak)\s+(feneri?|el feneri)\b',
    ).hasMatch(n);
    if (isOn) {
      return ParsedDeviceIntent(
        type: DeviceActionType.toggleFlashlight,
        rawText: original,
        confidence: 0.94,
        parameters: const {'state': 'on'},
        displaySummary: 'Turn on flashlight',
      );
    }
    return null;
  }

  static ParsedDeviceIntent? _matchMusic(String n, String original) {
    if (RegExp(
          r'\b(play|open|start)\s+(music|spotify|songs?)\b',
        ).hasMatch(n) ||
        RegExp(r'\b(muzik|spotify)\s*(ac|cal)\b').hasMatch(n) ||
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

  static ParsedDeviceIntent? _matchOpenSystemSurface(
    String n,
    String original,
  ) {
    // Camera / take photo (ASCII-folded Turkish: kamera ac, fotograf cek)
    if (RegExp(
      r'\b(open\s+)?camera\b|'
      r'\b(take\s+(a\s+)?(photo|picture)|capture\s+(a\s+)?(photo|picture))\b|'
      r'\b(kamerayi?\s*ac|kamera\s+ac|ac\s+kamera)\b|'
      r'\b(fotograf\s*cek|resim\s*cek)\b',
    ).hasMatch(n)) {
      return ParsedDeviceIntent(
        type: DeviceActionType.openCamera,
        rawText: original,
        confidence: 0.93,
        displaySummary: 'Open camera',
      );
    }

    if (RegExp(
      r'\b(open\s+)?(gallery|photos|photos app)\b|'
      r'\b(galeri(yi)?|fotograflari?)\s*ac\b|'
      r'\bac\s+(galeri|fotograflar)\b',
    ).hasMatch(n)) {
      return ParsedDeviceIntent(
        type: DeviceActionType.openGallery,
        rawText: original,
        confidence: 0.91,
        displaySummary: 'Open gallery',
      );
    }

    if (RegExp(
      r'\b(open\s+)?contacts?\b|'
      r'\b(kisiler|rehber)\s*ac\b',
    ).hasMatch(n)) {
      return ParsedDeviceIntent(
        type: DeviceActionType.openContacts,
        rawText: original,
        confidence: 0.91,
        displaySummary: 'Open contacts',
      );
    }

    if (RegExp(
      r'\b(open\s+)?calendar\b|'
      r'\b(takvim)\s*ac\b',
    ).hasMatch(n)) {
      return ParsedDeviceIntent(
        type: DeviceActionType.openCalendar,
        rawText: original,
        confidence: 0.91,
        displaySummary: 'Open calendar',
      );
    }

    if (RegExp(
      r'\b(open\s+)?(clock|alarm|timer)\b|'
      r'\b(saat|alarm|zamanlayici)\s*ac\b',
    ).hasMatch(n)) {
      return ParsedDeviceIntent(
        type: DeviceActionType.openClock,
        rawText: original,
        confidence: 0.91,
        displaySummary: 'Open clock',
      );
    }

    return null;
  }

  static ParsedDeviceIntent? _matchOpenCalculator(
    String n,
    String original,
  ) {
    if (RegExp(
      r'\b(open\s+)?calculator\b|'
      r'\b(hesap\s*makinesi(ni)?|hesap makinesi|hesap makinesi)\s*ac\b|'
      r'\bac\s+(hesap\s*makinesi|calculator)\b|'
      r'^hesap\s*makinesi$',
    ).hasMatch(n)) {
      return ParsedDeviceIntent(
        type: DeviceActionType.openApp,
        rawText: original,
        confidence: 0.93,
        parameters: const {'appName': 'calculator'},
        displaySummary: 'Open calculator',
      );
    }
    return null;
  }

  static ParsedDeviceIntent? _matchOpenApp(String n, String original) {
    // EN: "open X"  TR (folded): "X ac" / "ac X"
    String? appName;
    final en = RegExp(r'^open\s+(.+)$').firstMatch(n);
    if (en != null) {
      appName = en.group(1)!.trim();
    } else {
      final trSuffix = RegExp(r'^(.+?)\s+ac$').firstMatch(n);
      final trPrefix = RegExp(r'^ac\s+(.+)$').firstMatch(n);
      appName = (trSuffix?.group(1) ?? trPrefix?.group(1))?.trim();
    }
    if (appName == null || appName.isEmpty) {
      return null;
    }
    if (appName.contains('settings') ||
        appName.contains('ayar') ||
        appName.contains('camera') ||
        appName.contains('kamera') ||
        appName.contains('browser') ||
        appName.contains('flashlight') ||
        appName.contains('fener') ||
        appName.contains('calculator') ||
        appName.contains('hesap')) {
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
