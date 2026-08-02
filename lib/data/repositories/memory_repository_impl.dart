import '../../core/errors/noctros_failure.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/noctros_entities.dart';
import '../../domain/repositories/noctros_repositories.dart';
import '../local/database/noctros_database.dart';

class MemoryRepositoryImpl implements MemoryRepository {
  MemoryRepositoryImpl({required NoctrosDatabase database}) : _database = database;

  final NoctrosDatabase _database;

  @override
  Future<Result<void>> deleteAll() async {
    try {
      await _database.deleteAllMemoryEntries();
      return const Success(null);
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to delete memory.', cause: error),
      );
    }
  }

  @override
  Future<Result<void>> deleteEntry(String id) async {
    try {
      await _database.deleteMemoryEntry(id);
      return const Success(null);
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to delete memory entry.', cause: error),
      );
    }
  }

  @override
  Future<Result<List<MemoryEntry>>> listEntries() async {
    try {
      final rows = await _database.fetchMemoryEntries();
      return Success(
        rows
            .map(
              (row) => MemoryEntry(
                id: row.id,
                category: row.category,
                key: row.key,
                value: row.value,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt,
                sourceConversationId: row.sourceConversationId,
              ),
            )
            .toList(),
      );
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to load memory entries.', cause: error),
      );
    }
  }

  @override
  Future<Result<MemoryEntry>> upsertEntry(MemoryEntry entry) async {
    try {
      await _database.upsertMemoryEntry(
        id: entry.id,
        category: entry.category,
        key: entry.key,
        value: entry.value,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
        sourceConversationId: entry.sourceConversationId,
      );
      return Success(entry);
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to save memory entry.', cause: error),
      );
    }
  }
}
