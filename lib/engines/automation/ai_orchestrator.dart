import 'package:uuid/uuid.dart';

import '../../domain/entities/device_action_entities.dart';
import '../../domain/entities/noctros_entities.dart';
import '../../domain/entities/noctros_enums.dart';
import '../../domain/repositories/action_log_repository.dart';
import '../../domain/repositories/noctros_repositories.dart';
import 'device_action_engine.dart';
import 'intent_parser.dart';

enum OrchestratorOutcomeType {
  deviceAction,
  needsConfirmation,
  fallbackChat,
}

class OrchestratorOutcome {
  const OrchestratorOutcome({
    required this.type,
    required this.message,
    this.intent,
    this.deviceResult,
    this.enableVoiceMode = false,
  });

  final OrchestratorOutcomeType type;
  final String message;
  final ParsedDeviceIntent? intent;
  final DeviceActionResult? deviceResult;
  final bool enableVoiceMode;
}

/// Central command router: device intents first, AI chat fallback second.
class AiOrchestrator {
  AiOrchestrator({
    required IntentParser intentParser,
    required DeviceActionEngine deviceActionEngine,
    required ActionLogRepository actionLogRepository,
    required MemoryRepository memoryRepository,
    required SettingsRepository settingsRepository,
    Uuid? uuid,
  })  : _intentParser = intentParser,
        _deviceActionEngine = deviceActionEngine,
        _actionLogRepository = actionLogRepository,
        _memoryRepository = memoryRepository,
        _settingsRepository = settingsRepository,
        _uuid = uuid ?? const Uuid();

  final IntentParser _intentParser;
  final DeviceActionEngine _deviceActionEngine;
  final ActionLogRepository _actionLogRepository;
  final MemoryRepository _memoryRepository;
  final SettingsRepository _settingsRepository;
  final Uuid _uuid;

  ParsedDeviceIntent parse(String command) => _intentParser.parse(command);

  Future<OrchestratorOutcome> handle(
    String userCommand, {
    bool userConfirmed = false,
    ParsedDeviceIntent? confirmedIntent,
  }) async {
    final intent = confirmedIntent ?? _intentParser.parse(userCommand);

    if (!intent.isDeviceAction) {
      return OrchestratorOutcome(
        type: OrchestratorOutcomeType.fallbackChat,
        message: userCommand,
        intent: intent,
      );
    }

    final result = await _deviceActionEngine.execute(
      intent,
      userConfirmed: userConfirmed,
    );

    if (result.needsConfirmation) {
      return OrchestratorOutcome(
        type: OrchestratorOutcomeType.needsConfirmation,
        message: result.message,
        intent: intent,
        deviceResult: result,
      );
    }

    await _actionLogRepository.append(
      DeviceActionLog(
        id: _uuid.v4(),
        type: intent.type,
        summary: intent.displaySummary.isEmpty
            ? intent.type.name
            : intent.displaySummary,
        createdAt: DateTime.now().toUtc(),
        success: result.success,
        rawCommand: intent.rawText,
      ),
    );

    if (result.success) {
      await _rememberUsage(intent);
    }

    return OrchestratorOutcome(
      type: OrchestratorOutcomeType.deviceAction,
      message: result.message,
      intent: intent,
      deviceResult: result,
      enableVoiceMode: intent.type == DeviceActionType.enableVoiceMode,
    );
  }

  Future<void> _rememberUsage(ParsedDeviceIntent intent) async {
    final settings = await _settingsRepository.loadSettings();
    if (settings.isFailure || !settings.valueOrThrow.memoryEnabled) {
      return;
    }
    // Preferred contacts require explicit approval flag.
    final allowContacts = settings.valueOrThrow.rememberPreferredContacts;

    final now = DateTime.now().toUtc();
    late final String key;
    late final String value;
    var category = MemoryCategory.habit;

    switch (intent.type) {
      case DeviceActionType.openApp:
        key = 'favorite_app';
        value = intent.parameters['appName'] ?? '';
        category = MemoryCategory.preference;
      case DeviceActionType.navigate:
        key = 'favorite_destination';
        value = intent.parameters['destination'] ?? '';
        category = MemoryCategory.place;
      case DeviceActionType.call:
      case DeviceActionType.sms:
        if (!allowContacts) {
          return;
        }
        value = intent.parameters['contactName'] ??
            intent.parameters['recipient'] ??
            intent.parameters['phoneNumber'] ??
            '';
        key = 'preferred_contact';
        category = MemoryCategory.contact;
      default:
        key = 'frequent_command';
        value = intent.type.name;
        category = MemoryCategory.habit;
    }

    if (value.isEmpty) {
      return;
    }

    await _memoryRepository.upsertEntry(
      MemoryEntry(
        id: '${key}_${value.hashCode}',
        category: category,
        key: key,
        value: value,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}
