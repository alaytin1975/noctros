import '../../core/errors/noctros_failure.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/noctros_entities.dart';
import '../../domain/repositories/noctros_repositories.dart';
import '../local/database/noctros_database.dart';

class ConversationRepositoryImpl implements ConversationRepository {
  ConversationRepositoryImpl({required NoctrosDatabase database})
      : _database = database;

  final NoctrosDatabase _database;

  @override
  Future<Result<Conversation>> createConversation({required String title}) async {
    try {
      final now = DateTime.now().toUtc();
      final conversation = Conversation(
        id: now.microsecondsSinceEpoch.toString(),
        title: title,
        createdAt: now,
        updatedAt: now,
      );
      await _database.upsertConversation(
        id: conversation.id,
        title: conversation.title,
        createdAt: conversation.createdAt,
        updatedAt: conversation.updatedAt,
      );
      return Success(conversation);
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to create conversation.', cause: error),
      );
    }
  }

  @override
  Future<Result<List<Conversation>>> listConversations() async {
    try {
      final rows = await _database.fetchConversations();
      return Success(
        rows
            .map(
              (row) => Conversation(
                id: row.id,
                title: row.title,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt,
                isPinned: row.isPinned,
              ),
            )
            .toList(),
      );
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to load conversations.', cause: error),
      );
    }
  }

  @override
  Future<Result<List<ChatMessage>>> listMessages(String conversationId) async {
    try {
      final rows = await _database.fetchMessages(conversationId);
      return Success(
        rows
            .map(
              (row) => ChatMessage(
                id: row.id,
                conversationId: row.conversationId,
                role: row.role,
                content: row.content,
                createdAt: row.createdAt,
                metadata: row.metadata,
              ),
            )
            .toList(),
      );
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to load messages.', cause: error),
      );
    }
  }

  @override
  Future<Result<ChatMessage>> appendMessage(ChatMessage message) async {
    try {
      await _database.insertMessage(
        id: message.id,
        conversationId: message.conversationId,
        role: message.role,
        content: message.content,
        createdAt: message.createdAt,
        metadata: message.metadata,
      );
      return Success(message);
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to save message.', cause: error),
      );
    }
  }
}
