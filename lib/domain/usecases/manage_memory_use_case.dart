import '../../app/di/service_locator.dart';
import '../../core/errors/noctros_failure.dart';
import '../../core/utils/result.dart';
import '../entities/noctros_entities.dart';
import '../entities/noctros_enums.dart';
import '../repositories/noctros_repositories.dart';

class ManageMemoryUseCase {
  ManageMemoryUseCase({
    MemoryRepository? memoryRepository,
    SettingsRepository? settingsRepository,
  })  : _memoryRepository = memoryRepository ?? ServiceLocator.get(),
        _settingsRepository = settingsRepository ?? ServiceLocator.get();

  final MemoryRepository _memoryRepository;
  final SettingsRepository _settingsRepository;

  Future<Result<MemoryEntry>> remember({
    required MemoryCategory category,
    required String key,
    required String value,
    String? sourceConversationId,
  }) async {
    final settingsResult = await _settingsRepository.loadSettings();
    if (settingsResult is FailureResult<UserSettings>) {
      return FailureResult(settingsResult.failure);
    }
    if (!settingsResult.valueOrThrow.memoryEnabled) {
      return const FailureResult(
        PermissionFailure('Memory is disabled. Enable it in settings first.'),
      );
    }

    final now = DateTime.now().toUtc();
    return _memoryRepository.upsertEntry(
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

  Future<Result<void>> forgetAll() => _memoryRepository.deleteAll();
}
