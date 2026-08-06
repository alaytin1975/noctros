import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Persistent “Noctros is ready” notification while always listening.
class VoiceNotificationService {
  VoiceNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'noctros_voice_ready';
  static const _notificationId = 7001;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  Future<void> initialize({void Function()? onTap}) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (_) => onTap?.call(),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Noctros Voice',
        description: 'Shows when Noctros is silently listening for your wake word.',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );
    _ready = true;
  }

  Future<void> showReady() async {
    if (!_ready) {
      await initialize();
    }
    const android = AndroidNotificationDetails(
      _channelId,
      'Noctros Voice',
      channelDescription: 'Always-listening status',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
    );
    await _plugin.show(
      _notificationId,
      'Noctros is ready.',
      'Say “Noctros” to start.',
      const NotificationDetails(android: android),
    );
  }

  Future<void> hide() async {
    await _plugin.cancel(_notificationId);
  }
}
