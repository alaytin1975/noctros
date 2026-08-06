import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/service_locator.dart';
import '../../domain/entities/permission_entities.dart';
import '../../domain/repositories/permission_repository.dart';

/// Permissions Noctros actively uses across voice, emergency, and alerts.
const corePermissions = <NoctrosPermission>[
  NoctrosPermission.microphone,
  NoctrosPermission.notification,
  NoctrosPermission.contacts,
  NoctrosPermission.location,
  NoctrosPermission.phone,
  NoctrosPermission.sms,
  NoctrosPermission.ignoreBatteryOptimizations,
  NoctrosPermission.systemAlertWindow,
];

class PermissionsState {
  const PermissionsState({
    this.snapshots = const {},
    this.isLoading = false,
  });

  final Map<NoctrosPermission, PermissionSnapshot> snapshots;
  final bool isLoading;

  PermissionSnapshot? operator [](NoctrosPermission permission) =>
      snapshots[permission];

  bool get microphoneGranted =>
      snapshots[NoctrosPermission.microphone]?.isGranted ?? false;

  List<NoctrosPermission> get missingPermissions => snapshots.values
      .where((snapshot) => !snapshot.isGranted)
      .map((snapshot) => snapshot.permission)
      .toList();

  PermissionsState copyWith({
    Map<NoctrosPermission, PermissionSnapshot>? snapshots,
    bool? isLoading,
  }) {
    return PermissionsState(
      snapshots: snapshots ?? this.snapshots,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PermissionsController extends StateNotifier<PermissionsState> {
  PermissionsController(this._repository) : super(const PermissionsState());

  final PermissionRepository _repository;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    final result = await _repository.checkAll(corePermissions);
    if (result.isFailure) {
      state = state.copyWith(isLoading: false);
      return;
    }

    final snapshots = {
      for (final snapshot in result.valueOrThrow) snapshot.permission: snapshot,
    };
    state = state.copyWith(isLoading: false, snapshots: snapshots);
  }

  Future<PermissionSnapshot?> request(NoctrosPermission permission) async {
    final result = await _repository.request(permission);
    if (result.isFailure) {
      return null;
    }
    final snapshot = result.valueOrThrow;
    state = state.copyWith(
      snapshots: {
        ...state.snapshots,
        permission: snapshot,
      },
    );
    return snapshot;
  }

  Future<bool> openSettings() async {
    final result = await _repository.openAppSettings();
    return result.isSuccess && result.valueOrThrow;
  }
}

final permissionsControllerProvider =
    StateNotifierProvider<PermissionsController, PermissionsState>((ref) {
  return PermissionsController(ServiceLocator.get<PermissionRepository>());
});

String permissionLabel(NoctrosPermission permission) {
  return switch (permission) {
    NoctrosPermission.microphone => 'Microphone',
    NoctrosPermission.notification => 'Notifications',
    NoctrosPermission.contacts => 'Contacts',
    NoctrosPermission.location => 'Location',
    NoctrosPermission.phone => 'Phone',
    NoctrosPermission.sms => 'SMS',
    NoctrosPermission.ignoreBatteryOptimizations => 'Battery optimization',
    NoctrosPermission.systemAlertWindow => 'Display over other apps',
  };
}

String permissionRationale(NoctrosPermission permission) {
  return switch (permission) {
    NoctrosPermission.microphone =>
      'Noctros needs microphone access for wake word and voice commands.',
    NoctrosPermission.notification =>
      'Notifications let Noctros alert you during emergencies and important events.',
    NoctrosPermission.contacts =>
      'Contacts access enables emergency notifications to trusted people.',
    NoctrosPermission.location =>
      'Location helps Noctros share your position during emergency responses.',
    NoctrosPermission.phone =>
      'Phone access lets Noctros open the dialer for calls you approve.',
    NoctrosPermission.sms =>
      'SMS access lets Noctros open Messages with drafts you approve.',
    NoctrosPermission.ignoreBatteryOptimizations =>
      'Reduces OS killing of wake-word listening during battery optimization.',
    NoctrosPermission.systemAlertWindow =>
      'Optional overlay support for future always-available voice controls.',
  };
}
