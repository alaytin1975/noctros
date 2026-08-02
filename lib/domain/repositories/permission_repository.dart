import '../../core/utils/result.dart';
import '../entities/permission_entities.dart';

abstract interface class PermissionRepository {
  Future<Result<PermissionSnapshot>> check(NoctrosPermission permission);

  Future<Result<List<PermissionSnapshot>>> checkAll(
    Iterable<NoctrosPermission> permissions,
  );

  Future<Result<PermissionSnapshot>> request(NoctrosPermission permission);

  Future<Result<bool>> openAppSettings();
}
