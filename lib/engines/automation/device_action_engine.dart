import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/foundation.dart';
import 'package:torch_light/torch_light.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/device_action_entities.dart';
import '../../domain/repositories/noctros_repositories.dart';

/// Executes secure, user-approved device intents via platform launchers.
class DeviceActionEngine {
  DeviceActionEngine({required SettingsRepository settingsRepository})
      : _settingsRepository = settingsRepository;

  final SettingsRepository _settingsRepository;

  static const knownApps = <String, String>{
    'whatsapp': 'com.whatsapp',
    'spotify': 'com.spotify.music',
    'youtube': 'com.google.android.youtube',
    'gmail': 'com.google.android.gm',
    'maps': 'com.google.android.apps.maps',
    'google maps': 'com.google.android.apps.maps',
    'chrome': 'com.android.chrome',
    'instagram': 'com.instagram.android',
    'telegram': 'org.telegram.messenger',
    'messages': 'com.google.android.apps.messaging',
    'phone': 'com.google.android.dialer',
    'camera': 'com.android.camera',
    'photos': 'com.google.android.apps.photos',
    'gallery': 'com.google.android.apps.photos',
    'clock': 'com.google.android.deskclock',
    'calendar': 'com.google.android.calendar',
    'contacts': 'com.google.android.contacts',
    'calculator': 'com.google.android.calculator',
    'hesap makinesi': 'com.google.android.calculator',
  };

  static const _calculatorPackages = <String>[
    'com.google.android.calculator',
    'com.android.calculator2',
    'com.sec.android.app.popupcalculator',
    'com.miui.calculator',
  ];

  Future<DeviceActionResult> execute(
    ParsedDeviceIntent intent, {
    bool userConfirmed = false,
  }) async {
    final settings = await _settingsRepository.loadSettings();
    final confirmEnabled = settings.isSuccess
        ? settings.valueOrThrow.confirmDeviceActions
        : true;

    if (intent.requiresConfirmation && confirmEnabled && !userConfirmed) {
      return DeviceActionResult(
        success: false,
        message: 'Confirmation required: ${intent.displaySummary}',
        needsConfirmation: true,
        pendingIntent: intent,
      );
    }

    try {
      switch (intent.type) {
        case DeviceActionType.call:
          return _launchCall(intent);
        case DeviceActionType.sms:
          return _launchSms(intent);
        case DeviceActionType.email:
          return _launchEmail(intent);
        case DeviceActionType.navigate:
          return _launchNavigation(intent);
        case DeviceActionType.openBrowser:
          return _launchBrowser(intent);
        case DeviceActionType.openSettings:
          return _launchSettings(intent);
        case DeviceActionType.openContacts:
          return _launchAndroidAction(
            action: 'android.intent.action.VIEW',
            data: 'content://contacts/people',
            fallbackPackage: knownApps['contacts'],
            summary: 'Opened Contacts',
          );
        case DeviceActionType.openCalendar:
          return _launchAndroidAction(
            action: 'android.intent.action.MAIN',
            package: knownApps['calendar'],
            summary: 'Opened Calendar',
          );
        case DeviceActionType.openClock:
          return _launchAndroidAction(
            action: 'android.intent.action.SHOW_ALARMS',
            package: knownApps['clock'],
            summary: 'Opened Clock',
          );
        case DeviceActionType.openCamera:
          return _launchCamera();
        case DeviceActionType.openGallery:
          return _launchGallery();
        case DeviceActionType.openApp:
          return _launchApp(intent);
        case DeviceActionType.toggleFlashlight:
          return _toggleFlashlight(intent);
        case DeviceActionType.playMusic:
          return _launchMusic(intent);
        case DeviceActionType.enableVoiceMode:
          return const DeviceActionResult(
            success: true,
            message:
                'Voice mode enabled. Continuous listening is ready in Chat.',
          );
        case DeviceActionType.unknown:
          return const DeviceActionResult(
            success: false,
            message: 'No device action matched.',
          );
      }
    } catch (error) {
      return DeviceActionResult(
        success: false,
        message: 'Could not complete action: $error',
      );
    }
  }

  Future<DeviceActionResult> _launchCall(ParsedDeviceIntent intent) async {
    final number = intent.parameters['phoneNumber'];
    final contact = intent.parameters['contactName'];
    if (number != null && number.isNotEmpty) {
      final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
      final ok = await _launchUri(uri);
      return DeviceActionResult(
        success: ok,
        launchedExternally: ok,
        message: ok
            ? 'Calling $number.'
            : 'Unable to open the phone dialer.',
      );
    }
    // Open dialer; contact name is spoken so user can finish the call.
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await const AndroidIntent(
          action: 'android.intent.action.DIAL',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        ).launch();
        return DeviceActionResult(
          success: true,
          launchedExternally: true,
          message: contact == null || contact.isEmpty
              ? 'Opening phone.'
              : 'Opening dialer for $contact.',
        );
      } catch (_) {}
    }
    final uri = Uri(scheme: 'tel', path: '');
    final ok = await _launchUri(uri);
    return DeviceActionResult(
      success: ok,
      launchedExternally: ok,
      message: ok
          ? (contact == null || contact.isEmpty
              ? 'Opening phone.'
              : 'Opening dialer for $contact.')
          : 'Unable to open dialer for $contact.',
    );
  }

  Future<DeviceActionResult> _launchSms(ParsedDeviceIntent intent) async {
    final recipient = intent.parameters['recipient'] ?? '';
    final body = intent.parameters['body'] ?? '';
    final uri = recipient.isEmpty
        ? Uri(scheme: 'sms')
        : Uri(
            scheme: 'sms',
            path: recipient,
            queryParameters: body.isEmpty ? null : {'body': body},
          );
    final ok = await _launchUri(uri);
    return DeviceActionResult(
      success: ok,
      launchedExternally: ok,
      message: ok
          ? (recipient.isEmpty
              ? 'Opening messages.'
              : 'Opening messages for $recipient.')
          : 'Unable to open the SMS app.',
    );
  }

  Future<DeviceActionResult> _launchCamera() async {
    if (kIsWeb || !Platform.isAndroid) {
      return const DeviceActionResult(
        success: false,
        message: 'Camera is available on Android.',
      );
    }
    // Prefer still-image camera; fall back to IMAGE_CAPTURE / camera package.
    for (final action in const [
      'android.media.action.STILL_IMAGE_CAMERA',
      'android.media.action.IMAGE_CAPTURE',
    ]) {
      try {
        await AndroidIntent(
          action: action,
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        ).launch();
        return const DeviceActionResult(
          success: true,
          launchedExternally: true,
          message: 'Opening camera.',
        );
      } catch (_) {}
    }
    return _launchApp(
      const ParsedDeviceIntent(
        type: DeviceActionType.openApp,
        rawText: 'open camera',
        parameters: {'appName': 'camera'},
        displaySummary: 'Open camera',
      ),
    );
  }

  Future<DeviceActionResult> _launchGallery() async {
    if (kIsWeb || !Platform.isAndroid) {
      return const DeviceActionResult(
        success: false,
        message: 'Gallery is available on Android.',
      );
    }
    try {
      await AndroidIntent(
        action: 'android.intent.action.VIEW',
        type: 'image/*',
        package: knownApps['photos'],
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      ).launch();
      return const DeviceActionResult(
        success: true,
        launchedExternally: true,
        message: 'Opening gallery.',
      );
    } catch (_) {
      return _launchApp(
        const ParsedDeviceIntent(
          type: DeviceActionType.openApp,
          rawText: 'open gallery',
          parameters: {'appName': 'photos'},
          displaySummary: 'Open gallery',
        ),
      );
    }
  }

  Future<DeviceActionResult> _launchEmail(ParsedDeviceIntent intent) async {
    final email = intent.parameters['email'] ?? '';
    final subject = intent.parameters['subject'] ?? '';
    final body = intent.parameters['body'] ?? '';
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        if (subject.isNotEmpty) 'subject': subject,
        if (body.isNotEmpty) 'body': body,
      },
    );
    final ok = await _launchUri(uri);
    return DeviceActionResult(
      success: ok,
      launchedExternally: ok,
      message: ok ? 'Opening email to $email' : 'Unable to open email app.',
    );
  }

  Future<DeviceActionResult> _launchNavigation(ParsedDeviceIntent intent) async {
    final destination = intent.parameters['destination'] ?? '';
    final settings = await _settingsRepository.loadSettings();
    final navPref = settings.isSuccess
        ? settings.valueOrThrow.defaultNavigationApp
        : 'google_maps';

    if (!kIsWeb && Platform.isAndroid && navPref == 'google_maps') {
      final mapsIntent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'google.navigation:q=${Uri.encodeComponent(destination)}',
        package: knownApps['maps'],
      );
      try {
        await mapsIntent.launch();
        return DeviceActionResult(
          success: true,
          launchedExternally: true,
          message: 'Starting navigation to $destination',
        );
      } catch (_) {}
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}',
    );
    final ok = await _launchUri(uri);
    return DeviceActionResult(
      success: ok,
      launchedExternally: ok,
      message: ok
          ? 'Opening maps for $destination'
          : 'Unable to open navigation.',
    );
  }

  Future<DeviceActionResult> _launchBrowser(ParsedDeviceIntent intent) async {
    final url = intent.parameters['url'] ?? 'https://www.google.com';
    final settings = await _settingsRepository.loadSettings();
    final browser = settings.isSuccess
        ? settings.valueOrThrow.preferredBrowser
        : 'default';

    if (!kIsWeb && Platform.isAndroid && browser == 'chrome') {
      final intentChrome = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: url,
        package: knownApps['chrome'],
      );
      try {
        await intentChrome.launch();
        return DeviceActionResult(
          success: true,
          launchedExternally: true,
          message: 'Opened Chrome: $url',
        );
      } catch (_) {}
    }

    final ok = await _launchUri(Uri.parse(url));
    return DeviceActionResult(
      success: ok,
      launchedExternally: ok,
      message: ok ? 'Opened browser: $url' : 'Unable to open browser.',
    );
  }

  Future<DeviceActionResult> _launchSettings(ParsedDeviceIntent intent) async {
    if (kIsWeb || !Platform.isAndroid) {
      return const DeviceActionResult(
        success: false,
        message: 'System settings are available on Android devices.',
      );
    }

    final targetName = intent.parameters['target'] ?? 'main';
    final target = DeviceSettingsTarget.values.firstWhere(
      (value) => value.name == targetName,
      orElse: () => DeviceSettingsTarget.main,
    );

    final action = switch (target) {
      DeviceSettingsTarget.wifi => 'android.settings.WIFI_SETTINGS',
      DeviceSettingsTarget.bluetooth => 'android.settings.BLUETOOTH_SETTINGS',
      DeviceSettingsTarget.display => 'android.settings.DISPLAY_SETTINGS',
      DeviceSettingsTarget.sound => 'android.settings.SOUND_SETTINGS',
      DeviceSettingsTarget.location =>
        'android.settings.LOCATION_SOURCE_SETTINGS',
      DeviceSettingsTarget.apps => 'android.settings.APPLICATION_SETTINGS',
      DeviceSettingsTarget.battery => 'android.settings.BATTERY_SAVER_SETTINGS',
      DeviceSettingsTarget.security => 'android.settings.SECURITY_SETTINGS',
      DeviceSettingsTarget.main => 'android.settings.SETTINGS',
    };

    await AndroidIntent(
      action: action,
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    ).launch();
    return DeviceActionResult(
      success: true,
      launchedExternally: true,
      message: target == DeviceSettingsTarget.main
          ? 'Opening settings.'
          : 'Opening ${target.name} settings.',
    );
  }

  Future<DeviceActionResult> _toggleFlashlight(ParsedDeviceIntent intent) async {
    if (kIsWeb) {
      return const DeviceActionResult(
        success: false,
        message: 'Flashlight is unavailable on this platform.',
      );
    }
    try {
      final available = await TorchLight.isTorchAvailable();
      if (!available) {
        return const DeviceActionResult(
          success: false,
          message: 'No flashlight available on this device.',
        );
      }
      final state = intent.parameters['state'] ?? 'on';
      if (state == 'off') {
        await TorchLight.disableTorch();
        return const DeviceActionResult(
          success: true,
          message: 'Flashlight turned off.',
        );
      }
      await TorchLight.enableTorch();
      return const DeviceActionResult(
        success: true,
        message: 'Flashlight turned on.',
      );
    } catch (error) {
      return DeviceActionResult(
        success: false,
        message: 'Could not control flashlight: $error',
      );
    }
  }

  Future<DeviceActionResult> _launchMusic(ParsedDeviceIntent intent) async {
    final appName = (intent.parameters['appName'] ?? 'music').toLowerCase();
    if (appName.contains('spotify')) {
      return _launchApp(
        ParsedDeviceIntent(
          type: DeviceActionType.openApp,
          rawText: intent.rawText,
          parameters: const {'appName': 'spotify'},
          displaySummary: 'Open Spotify',
        ),
      );
    }
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await const AndroidIntent(
          action: 'android.intent.action.MUSIC_PLAYER',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        ).launch();
        return const DeviceActionResult(
          success: true,
          launchedExternally: true,
          message: 'Opening music player',
        );
      } catch (_) {}
    }
    return _launchApp(
      ParsedDeviceIntent(
        type: DeviceActionType.openApp,
        rawText: intent.rawText,
        parameters: const {'appName': 'spotify'},
        displaySummary: 'Open Spotify',
      ),
    );
  }

  Future<DeviceActionResult> _launchApp(ParsedDeviceIntent intent) async {
    final appName = (intent.parameters['appName'] ?? '').toLowerCase().trim();
    if (appName.contains('calculator') || appName.contains('hesap')) {
      return _launchCalculator();
    }

    String? package = knownApps[appName];
    package ??= () {
      for (final entry in knownApps.entries) {
        if (appName.contains(entry.key) || entry.key.contains(appName)) {
          return entry.value;
        }
      }
      return null;
    }();

    if (package == null) {
      final market = Uri.parse('market://search?q=$appName');
      final ok = await _launchUri(market);
      return DeviceActionResult(
        success: ok,
        launchedExternally: ok,
        message: ok
            ? 'Could not find "$appName" installed. Opened store search.'
            : 'App "$appName" is not recognized on this device.',
      );
    }

    if (kIsWeb || !Platform.isAndroid) {
      return DeviceActionResult(
        success: false,
        message: 'Opening "$appName" requires Android.',
      );
    }

    try {
      await AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: package,
        category: 'android.intent.category.LAUNCHER',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      ).launch();
      return DeviceActionResult(
        success: true,
        launchedExternally: true,
        message: 'Opening $appName.',
      );
    } catch (_) {
      // Some OEMs reject MAIN+LAUNCHER; try package-only launch.
      try {
        await AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: package,
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        ).launch();
        return DeviceActionResult(
          success: true,
          launchedExternally: true,
          message: 'Opening $appName.',
        );
      } catch (error) {
        return DeviceActionResult(
          success: false,
          message: 'Could not open $appName: $error',
        );
      }
    }
  }

  Future<DeviceActionResult> _launchCalculator() async {
    if (kIsWeb || !Platform.isAndroid) {
      return const DeviceActionResult(
        success: false,
        message: 'Calculator requires Android.',
      );
    }
    for (final package in _calculatorPackages) {
      try {
        await AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: package,
          category: 'android.intent.category.LAUNCHER',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        ).launch();
        return const DeviceActionResult(
          success: true,
          launchedExternally: true,
          message: 'Opening calculator.',
        );
      } catch (_) {}
    }
    final market = Uri.parse('market://search?q=calculator');
    final ok = await _launchUri(market);
    return DeviceActionResult(
      success: ok,
      launchedExternally: ok,
      message: ok
          ? 'Calculator not found. Opened store search.'
          : 'Unable to open calculator.',
    );
  }

  Future<DeviceActionResult> _launchAndroidAction({
    required String action,
    String? data,
    String? type,
    String? package,
    String? fallbackPackage,
    required String summary,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return DeviceActionResult(
        success: false,
        message: '$summary is available on Android.',
      );
    }
    try {
      await AndroidIntent(
        action: action,
        data: data,
        type: type,
        package: package ?? fallbackPackage,
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      ).launch();
      return DeviceActionResult(
        success: true,
        launchedExternally: true,
        message: summary,
      );
    } catch (_) {
      if (fallbackPackage != null && package == null) {
        return _launchAndroidAction(
          action: 'android.intent.action.MAIN',
          package: fallbackPackage,
          summary: summary,
        );
      }
      return DeviceActionResult(
        success: false,
        message: 'Unable to complete: $summary',
      );
    }
  }

  Future<bool> _launchUri(Uri uri) async {
    try {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
