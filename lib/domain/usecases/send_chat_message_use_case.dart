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
    void Function(String partial)? onStreamChunk,
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
            .map((entry) => '- ${entry.key}: ${entry.value}')
            .join('\n')
        : '';

    final request = AiRequest(
      prompt: userMessage,
      conversationId: conversationId,
      complexity: complexity,
      preferredMode: AiExecutionMode.hybrid,
      contextMessages: historyResult.valueOrThrow,
      requiresInternet: true,
      memoryContext: memoryContext,
    );

    final buffer = StringBuffer();
    var usedOffline = false;

    try {
      await for (final chunk in _aiRepository.streamComplete(request)) {
        buffer.write(chunk);
        onStreamChunk?.call(buffer.toString());
      }
    } catch (_) {
      usedOffline = true;
      final fallback = await _aiRepository.complete(request);
      if (fallback is FailureResult<AiResponse>) {
        return FailureResult(fallback.failure);
      }
      buffer
        ..clear()
        ..write(fallback.valueOrThrow.content);
      onStreamChunk?.call(buffer.toString());
      usedOffline = fallback.valueOrThrow.processedLocally;
    }

    final content = buffer.toString().trim();
    if (content.isEmpty) {
      final complete = await _aiRepository.complete(request);
      if (complete is FailureResult<AiResponse>) {
        return FailureResult(complete.failure);
      }
      return _conversationRepository.appendMessage(
        ChatMessage(
          id: _newId(),
          conversationId: conversationId,
          role: MessageRole.assistant,
          content: complete.valueOrThrow.content,
          createdAt: DateTime.now().toUtc(),
          metadata: {
            'modeUsed': complete.valueOrThrow.modeUsed.name,
            'processedLocally': complete.valueOrThrow.processedLocally,
            'streamed': false,
          },
        ),
      );
    }

    return _conversationRepository.appendMessage(
      ChatMessage(
        id: _newId(),
        conversationId: conversationId,
        role: MessageRole.assistant,
        content: content,
        createdAt: DateTime.now().toUtc(),
        metadata: {
          'modeUsed': usedOffline ? 'local' : 'cloud',
          'processedLocally': usedOffline,
          'streamed': true,
        },
      ),
    );
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
