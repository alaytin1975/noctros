import '../../app/di/service_locator.dart';
import '../../core/utils/result.dart';
import '../entities/noctros_entities.dart';
import '../entities/noctros_enums.dart';
import '../repositories/noctros_repositories.dart';

class SendChatMessageUseCase {
  SendChatMessageUseCase({
    ConversationRepository? conversationRepository,
    AiRepository? aiRepository,
    MemoryRepository? memoryRepository,
  })  : _conversationRepository =
            conversationRepository ?? ServiceLocator.get(),
        _aiRepository = aiRepository ?? ServiceLocator.get(),
        _memoryRepository = memoryRepository ?? ServiceLocator.get();

  final ConversationRepository _conversationRepository;
  final AiRepository _aiRepository;
  final MemoryRepository _memoryRepository;

  Future<Result<ChatMessage>> execute({
    required String conversationId,
    required String userMessage,
    AiTaskComplexity complexity = AiTaskComplexity.moderate,
  }) async {
    final userResult = await _conversationRepository.appendMessage(
      ChatMessage(
        id: _newId(),
        conversationId: conversationId,
        role: MessageRole.user,
        content: userMessage,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    if (userResult is FailureResult<ChatMessage>) {
      return FailureResult(userResult.failure);
    }

    final historyResult =
        await _conversationRepository.listMessages(conversationId);
    if (historyResult is FailureResult<List<ChatMessage>>) {
      return FailureResult(historyResult.failure);
    }

    final memoryResult = await _memoryRepository.listEntries();
    final memoryContext = memoryResult.isSuccess
        ? memoryResult.valueOrThrow
            .map((entry) => '${entry.key}: ${entry.value}')
            .join('\n')
        : '';

    final aiResult = await _aiRepository.complete(
      AiRequest(
        prompt: userMessage,
        conversationId: conversationId,
        complexity: complexity,
        contextMessages: historyResult.valueOrThrow,
        requiresInternet: complexity == AiTaskComplexity.complex,
      ),
    );
    if (aiResult is FailureResult<AiResponse>) {
      return FailureResult(aiResult.failure);
    }

    final response = aiResult.valueOrThrow;
    final enrichedContent = memoryContext.isEmpty
        ? response.content
        : response.content;

    return _conversationRepository.appendMessage(
      ChatMessage(
        id: _newId(),
        conversationId: conversationId,
        role: MessageRole.assistant,
        content: enrichedContent,
        createdAt: DateTime.now().toUtc(),
        metadata: {
          'modeUsed': response.modeUsed.name,
          'processedLocally': response.processedLocally,
        },
      ),
    );
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
