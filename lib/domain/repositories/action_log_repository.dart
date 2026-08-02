import '../../core/utils/result.dart';
import '../entities/device_action_entities.dart';

abstract interface class ActionLogRepository {
  Future<Result<void>> append(DeviceActionLog log);
  Future<Result<List<DeviceActionLog>>> listRecent({int limit = 20});
  Future<Result<void>> clear();
}
