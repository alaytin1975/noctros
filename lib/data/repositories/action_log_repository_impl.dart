import '../../core/errors/noctros_failure.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/device_action_entities.dart';
import '../../domain/repositories/action_log_repository.dart';
import '../local/database/noctros_database.dart';

class ActionLogRepositoryImpl implements ActionLogRepository {
  ActionLogRepositoryImpl({required NoctrosDatabase database})
      : _database = database;

  final NoctrosDatabase _database;

  @override
  Future<Result<void>> append(DeviceActionLog log) async {
    try {
      await _database.insertActionLog(
        id: log.id,
        actionType: log.type.name,
        summary: log.summary,
        success: log.success,
        createdAt: log.createdAt,
        rawCommand: log.rawCommand,
      );
      return const Success(null);
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to append action log.', cause: error),
      );
    }
  }

  @override
  Future<Result<List<DeviceActionLog>>> listRecent({int limit = 20}) async {
    try {
      final rows = await _database.fetchActionLogs(limit: limit);
      return Success(
        rows.map((row) {
          final typeName = row['action_type']! as String;
          final type = DeviceActionType.values.firstWhere(
            (value) => value.name == typeName,
            orElse: () => DeviceActionType.unknown,
          );
          return DeviceActionLog(
            id: row['id']! as String,
            type: type,
            summary: row['summary']! as String,
            createdAt: DateTime.parse(row['created_at']! as String),
            success: (row['success'] as int? ?? 1) == 1,
            rawCommand: row['raw_command'] as String?,
          );
        }).toList(),
      );
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to load action logs.', cause: error),
      );
    }
  }

  @override
  Future<Result<void>> clear() async {
    try {
      await _database.clearActionLogs();
      return const Success(null);
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to clear action logs.', cause: error),
      );
    }
  }
}
