/// Permissions Noctros requires for voice, notifications, and emergency features.
enum NoctrosPermission {
  microphone,
  notification,
  contacts,
  location,
}

enum NoctrosPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
  notDetermined,
}

class PermissionSnapshot {
  const PermissionSnapshot({
    required this.permission,
    required this.status,
  });

  final NoctrosPermission permission;
  final NoctrosPermissionStatus status;

  bool get isGranted => status == NoctrosPermissionStatus.granted;

  bool get requiresSettings =>
      status == NoctrosPermissionStatus.permanentlyDenied ||
      status == NoctrosPermissionStatus.restricted;

  PermissionSnapshot copyWith({
    NoctrosPermissionStatus? status,
  }) {
    return PermissionSnapshot(
      permission: permission,
      status: status ?? this.status,
    );
  }
}
