import 'dart:convert';

import '../../app/di/service_locator.dart';
import '../../core/errors/noctros_failure.dart';
import '../../core/utils/result.dart';
import '../../data/local/database/noctros_database.dart';
import '../entities/noctros_entities.dart';
import '../repositories/action_log_repository.dart';
import '../repositories/noctros_repositories.dart';

/// Export and wipe local non-secret data (privacy controls).
class ManageLocalDataUseCase {
  ManageLocalDataUseCase({
    NoctrosDatabase? database,
    MemoryRepository? memoryRepository,
    ActionLogRepository? actionLogRepository,
    ConversationRepository? conversationRepository,
    SettingsRepository? settingsRepository,
  })  : _database = database ?? ServiceLocator.get<NoctrosDatabase>(),
        _memoryRepository = memoryRepository ?? ServiceLocator.get(),
        _actionLogRepository = actionLogRepository ?? ServiceLocator.get(),
        _conversationRepository =
            conversationRepository ?? ServiceLocator.get(),
        _settingsRepository = settingsRepository ?? ServiceLocator.get();

  final NoctrosDatabase _database;
  final MemoryRepository _memoryRepository;
  final ActionLogRepository _actionLogRepository;
  final ConversationRepository _conversationRepository;
  final SettingsRepository _settingsRepository;

  Future<Result<String>> exportLocalData() async {
    try {
      final conversations = await _conversationRepository.listConversations();
      final memory = await _memoryRepository.listEntries();
      final logs = await _actionLogRepository.listRecent(limit: 100);
      final settings = await _settingsRepository.loadSettings();

      final payload = {
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'app': 'noctros',
        'version': '0.5.0',
        'settings': settings.isSuccess
            ? <String, Object?>{
                'aiExecutionMode': settings.valueOrThrow.aiExecutionMode.name,
                'cloudPolicy': settings.valueOrThrow.cloudPolicy.name,
                'memoryEnabled': settings.valueOrThrow.memoryEnabled,
                'defaultNavigationApp':
                    settings.valueOrThrow.defaultNavigationApp,
                'preferredBrowser': settings.valueOrThrow.preferredBrowser,
                'confirmDeviceActions':
                    settings.valueOrThrow.confirmDeviceActions,
                'rememberPreferredContacts':
                    settings.valueOrThrow.rememberPreferredContacts,
              }
            : <String, Object?>{},
        'conversationCount':
            conversations.isSuccess ? conversations.valueOrThrow.length : 0,
        'memory': memory.isSuccess
            ? memory.valueOrThrow
                .map(
                  (entry) => <String, Object?>{
                    'category': entry.category.name,
                    'key': entry.key,
                    'value': entry.value,
                  },
                )
                .toList()
            : <Map<String, Object?>>[],
        'recentActions': logs.isSuccess
            ? logs.valueOrThrow
                .map(
                  (log) => <String, Object?>{
                    'type': log.type.name,
                    'summary': log.summary,
                    'success': log.success,
                    'createdAt': log.createdAt.toIso8601String(),
                  },
                )
                .toList()
            : <Map<String, Object?>>[],
      };

      return Success(const JsonEncoder.withIndent('  ').convert(payload));
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to export local data.', cause: error),
      );
    }
  }

  Future<Result<void>> deleteLocalData() async {
    try {
      await _database.clearConversationsAndMessages();
      await _memoryRepository.deleteAll();
      await _actionLogRepository.clear();

      final settings = await _settingsRepository.loadSettings();
      if (settings.isSuccess) {
        await _settingsRepository.saveSettings(
          settings.valueOrThrow.copyWith(
            memoryEnabled: false,
            rememberPreferredContacts: false,
            confirmDeviceActions: true,
          ),
        );
      } else {
        await _settingsRepository.saveSettings(UserSettings.defaults());
      }
      return const Success(null);
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to delete local data.', cause: error),
      );
    }
  }
}
