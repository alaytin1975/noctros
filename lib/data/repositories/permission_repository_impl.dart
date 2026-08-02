import '../../core/errors/noctros_failure.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/permission_entities.dart';
import '../../domain/repositories/permission_repository.dart';
import '../services/permission_service.dart';

class PermissionRepositoryImpl implements PermissionRepository {
  PermissionRepositoryImpl({required PermissionService service})
      : _service = service;

  final PermissionService _service;

  @override
  Future<Result<PermissionSnapshot>> check(NoctrosPermission permission) async {
    try {
      return Success(await _service.check(permission));
    } catch (error) {
      return FailureResult(
        PermissionFailure('Failed to check ${permission.name} permission.',
            cause: error),
      );
    }
  }

  @override
  Future<Result<List<PermissionSnapshot>>> checkAll(
    Iterable<NoctrosPermission> permissions,
  ) async {
    try {
      return Success(await _service.checkAll(permissions));
    } catch (error) {
      return FailureResult(
        PermissionFailure('Failed to check permissions.', cause: error),
      );
    }
  }

  @override
  Future<Result<PermissionSnapshot>> request(
    NoctrosPermission permission,
  ) async {
    try {
      return Success(await _service.request(permission));
    } catch (error) {
      return FailureResult(
        PermissionFailure('Failed to request ${permission.name} permission.',
            cause: error),
      );
    }
  }

  @override
  Future<Result<bool>> openAppSettings() async {
    try {
      return Success(await _service.openAppSettings());
    } catch (error) {
      return FailureResult(
        PermissionFailure('Failed to open app settings.', cause: error),
      );
    }
  }
}
