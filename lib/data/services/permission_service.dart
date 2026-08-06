import 'package:permission_handler/permission_handler.dart' as handler;

import '../../domain/entities/permission_entities.dart';

/// Maps Noctros domain permissions to platform permission_handler types.
class PermissionService {
  handler.Permission _toPlatformPermission(NoctrosPermission permission) {
    return switch (permission) {
      NoctrosPermission.microphone => handler.Permission.microphone,
      NoctrosPermission.notification => handler.Permission.notification,
      NoctrosPermission.contacts => handler.Permission.contacts,
      NoctrosPermission.location => handler.Permission.locationWhenInUse,
      NoctrosPermission.phone => handler.Permission.phone,
      NoctrosPermission.sms => handler.Permission.sms,
      NoctrosPermission.ignoreBatteryOptimizations =>
        handler.Permission.ignoreBatteryOptimizations,
      NoctrosPermission.systemAlertWindow =>
        handler.Permission.systemAlertWindow,
    };
  }

  NoctrosPermissionStatus _toDomainStatus(handler.PermissionStatus status) {
    return switch (status) {
      handler.PermissionStatus.granted => NoctrosPermissionStatus.granted,
      handler.PermissionStatus.denied => NoctrosPermissionStatus.denied,
      handler.PermissionStatus.permanentlyDenied =>
        NoctrosPermissionStatus.permanentlyDenied,
      handler.PermissionStatus.restricted =>
        NoctrosPermissionStatus.restricted,
      handler.PermissionStatus.limited => NoctrosPermissionStatus.limited,
      handler.PermissionStatus.provisional => NoctrosPermissionStatus.granted,
    };
  }

  Future<PermissionSnapshot> check(NoctrosPermission permission) async {
    final status = await _toPlatformPermission(permission).status;
    return PermissionSnapshot(
      permission: permission,
      status: _toDomainStatus(status),
    );
  }

  Future<List<PermissionSnapshot>> checkAll(
    Iterable<NoctrosPermission> permissions,
  ) async {
    final results = <PermissionSnapshot>[];
    for (final permission in permissions) {
      results.add(await check(permission));
    }
    return results;
  }

  Future<PermissionSnapshot> request(NoctrosPermission permission) async {
    final status = await _toPlatformPermission(permission).request();
    return PermissionSnapshot(
      permission: permission,
      status: _toDomainStatus(status),
    );
  }

  Future<bool> openAppSettings() => handler.openAppSettings();
}
