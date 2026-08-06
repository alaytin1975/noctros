import '../../domain/entities/permission_entities.dart';
import '../../domain/repositories/permission_repository.dart';

/// Automatic voice-related permission orchestration with graceful denial.
class VoicePermissionManager {
  VoicePermissionManager({required PermissionRepository permissionRepository})
      : _permissionRepository = permissionRepository;

  final PermissionRepository _permissionRepository;

  static const voiceCritical = <NoctrosPermission>[
    NoctrosPermission.microphone,
  ];

  static const voiceRecommended = <NoctrosPermission>[
    NoctrosPermission.microphone,
    NoctrosPermission.notification,
    NoctrosPermission.location,
    NoctrosPermission.contacts,
    NoctrosPermission.phone,
    NoctrosPermission.sms,
  ];

  Future<bool> ensureMicrophone() async {
    final check = await _permissionRepository.check(NoctrosPermission.microphone);
    if (check.isSuccess && check.valueOrThrow.isGranted) {
      return true;
    }
    final requested =
        await _permissionRepository.request(NoctrosPermission.microphone);
    return requested.isSuccess && requested.valueOrThrow.isGranted;
  }

  Future<Map<NoctrosPermission, PermissionSnapshot>> refreshAll() async {
    final result = await _permissionRepository.checkAll(voiceRecommended);
    if (result.isFailure) {
      return {};
    }
    return {
      for (final snapshot in result.valueOrThrow) snapshot.permission: snapshot,
    };
  }

  Future<PermissionSnapshot?> request(NoctrosPermission permission) async {
    final result = await _permissionRepository.request(permission);
    if (result.isFailure) {
      return null;
    }
    return result.valueOrThrow;
  }

  Future<bool> openSystemSettings() async {
    final result = await _permissionRepository.openAppSettings();
    return result.isSuccess && result.valueOrThrow;
  }
}
