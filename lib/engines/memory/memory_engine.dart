import '../../core/utils/result.dart';
import '../../domain/entities/noctros_entities.dart';
import '../../domain/entities/noctros_enums.dart';
import '../../domain/repositories/noctros_repositories.dart';

/// Permission-based long-term memory engine.
class MemoryEngine {
  MemoryEngine({required MemoryRepository repository}) : _repository = repository;

  final MemoryRepository _repository;

  Future<Result<List<MemoryEntry>>> recallAll() => _repository.listEntries();

  Future<Result<MemoryEntry>> remember({
    required MemoryCategory category,
    required String key,
    required String value,
    String? sourceConversationId,
  }) {
    final now = DateTime.now().toUtc();
    return _repository.upsertEntry(
      MemoryEntry(
        id: now.microsecondsSinceEpoch.toString(),
        category: category,
        key: key,
        value: value,
        createdAt: now,
        updatedAt: now,
        sourceConversationId: sourceConversationId,
      ),
    );
  }

  Future<Result<void>> forgetAll() => _repository.deleteAll();

  Future<Result<String>> buildContextPrompt() async {
    final result = await _repository.listEntries();
    if (result is FailureResult<List<MemoryEntry>>) {
      return FailureResult(result.failure);
    }

    if (result.valueOrThrow.isEmpty) {
      return const Success('');
    }

    final buffer = StringBuffer('Known user memory:\n');
    for (final entry in result.valueOrThrow) {
      buffer.writeln('- ${entry.category.name}/${entry.key}: ${entry.value}');
    }
    return Success(buffer.toString());
  }
}
