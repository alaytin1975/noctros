import 'package:uuid/uuid.dart';

import '../../app/di/service_locator.dart';
import '../../core/utils/result.dart';
import '../../engines/automation/ai_orchestrator.dart';
import '../entities/device_action_entities.dart';
import '../entities/noctros_entities.dart';
import '../entities/noctros_enums.dart';
import '../repositories/noctros_repositories.dart';
import 'send_chat_message_use_case.dart';

/// Routes user text/voice through the AI orchestrator, with chat fallback.
class HandleUserCommandUseCase {
  HandleUserCommandUseCase({
    AiOrchestrator? orchestrator,
    SendChatMessageUseCase? sendChatMessageUseCase,
    ConversationRepository? conversationRepository,
    SettingsRepository? settingsRepository,
    Uuid? uuid,
  })  : _orchestrator = orchestrator ?? ServiceLocator.get<AiOrchestrator>(),
        _sendChatMessageUseCase =
            sendChatMessageUseCase ?? SendChatMessageUseCase(),
        _conversationRepository =
            conversationRepository ?? ServiceLocator.get(),
        _settingsRepository = settingsRepository ?? ServiceLocator.get(),
        _uuid = uuid ?? const Uuid();

  final AiOrchestrator _orchestrator;
  final SendChatMessageUseCase _sendChatMessageUseCase;
  final ConversationRepository _conversationRepository;
  final SettingsRepository _settingsRepository;
  final Uuid _uuid;

  Future<Result<HandleCommandResult>> execute({
    required String conversationId,
    required String userMessage,
    bool userConfirmed = false,
    ParsedDeviceIntent? confirmedIntent,
    void Function(String partial)? onStreamChunk,
  }) async {
    final settings = await _settingsRepository.loadSettings();
    final confirmEnabled = settings.isSuccess
        ? settings.valueOrThrow.confirmDeviceActions
        : true;

    final autoConfirm = userConfirmed || !confirmEnabled;
    final outcome = await _orchestrator.handle(
      userMessage,
      userConfirmed: autoConfirm,
      confirmedIntent: confirmedIntent,
    );

    if (outcome.type == OrchestratorOutcomeType.fallbackChat) {
      final chatResult = await _sendChatMessageUseCase.execute(
        conversationId: conversationId,
        userMessage: userMessage,
        onStreamChunk: onStreamChunk,
      );
      if (chatResult.isFailure) {
        return FailureResult(chatResult.failureOrNull!);
      }
      return Success(
        HandleCommandResult(
          kind: HandleCommandKind.chatReply,
          assistantMessage: chatResult.valueOrThrow,
        ),
      );
    }

    if (outcome.type == OrchestratorOutcomeType.needsConfirmation) {
      return Success(
        HandleCommandResult(
          kind: HandleCommandKind.needsConfirmation,
          confirmationMessage: outcome.message,
          pendingIntent: outcome.intent,
          pendingUserMessage: userMessage,
        ),
      );
    }

    final now = DateTime.now().toUtc();
    await _conversationRepository.appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        conversationId: conversationId,
        role: MessageRole.user,
        content: userMessage,
        createdAt: now,
        metadata: const {'source': 'device_command'},
      ),
    );
    final assistant = await _conversationRepository.appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        conversationId: conversationId,
        role: MessageRole.assistant,
        content: outcome.message,
        createdAt: DateTime.now().toUtc(),
        metadata: {
          'source': 'device_action',
          'action': outcome.intent?.type.name,
        },
      ),
    );

    if (assistant.isFailure) {
      return FailureResult(assistant.failureOrNull!);
    }

    return Success(
      HandleCommandResult(
        kind: HandleCommandKind.deviceAction,
        assistantMessage: assistant.valueOrThrow,
        enableVoiceMode: outcome.enableVoiceMode,
        deviceResult: outcome.deviceResult,
      ),
    );
  }
}

enum HandleCommandKind {
  chatReply,
  deviceAction,
  needsConfirmation,
}

class HandleCommandResult {
  const HandleCommandResult({
    required this.kind,
    this.assistantMessage,
    this.confirmationMessage,
    this.pendingIntent,
    this.pendingUserMessage,
    this.enableVoiceMode = false,
    this.deviceResult,
  });

  final HandleCommandKind kind;
  final ChatMessage? assistantMessage;
  final String? confirmationMessage;
  final ParsedDeviceIntent? pendingIntent;
  final String? pendingUserMessage;
  final bool enableVoiceMode;
  final DeviceActionResult? deviceResult;
}
