enum DeviceActionType {
  openApp,
  call,
  sms,
  email,
  navigate,
  openContacts,
  openCalendar,
  openClock,
  openCamera,
  openGallery,
  openBrowser,
  openSettings,
  enableVoiceMode,
  toggleFlashlight,
  playMusic,
  unknown,
}

enum DeviceSettingsTarget {
  main,
  wifi,
  bluetooth,
  display,
  sound,
  location,
  apps,
  battery,
  security,
}

enum ActionSensitivity {
  low,
  medium,
  high,
}

class ParsedDeviceIntent {
  const ParsedDeviceIntent({
    required this.type,
    required this.rawText,
    this.confidence = 0.0,
    this.parameters = const {},
    this.requiresConfirmation = false,
    this.sensitivity = ActionSensitivity.low,
    this.displaySummary = '',
  });

  final DeviceActionType type;
  final String rawText;
  final double confidence;
  final Map<String, String> parameters;
  final bool requiresConfirmation;
  final ActionSensitivity sensitivity;
  final String displaySummary;

  bool get isDeviceAction => type != DeviceActionType.unknown;
}

class DeviceActionResult {
  const DeviceActionResult({
    required this.success,
    required this.message,
    this.launchedExternally = false,
    this.needsConfirmation = false,
    this.pendingIntent,
  });

  final bool success;
  final String message;
  final bool launchedExternally;
  final bool needsConfirmation;
  final ParsedDeviceIntent? pendingIntent;
}

class DeviceActionLog {
  const DeviceActionLog({
    required this.id,
    required this.type,
    required this.summary,
    required this.createdAt,
    required this.success,
    this.rawCommand,
  });

  final String id;
  final DeviceActionType type;
  final String summary;
  final DateTime createdAt;
  final bool success;
  final String? rawCommand;
}

class DeviceShortcut {
  const DeviceShortcut({
    required this.id,
    required this.label,
    required this.command,
    required this.iconName,
    this.isFavorite = false,
  });

  final String id;
  final String label;
  final String command;
  final String iconName;
  final bool isFavorite;
}
