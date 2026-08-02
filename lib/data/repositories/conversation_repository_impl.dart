import 'dart:convert';

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
  Future<Result<List<Conversation>>> listConversations({
    String? query,
    bool favoritesOnly = false,
  }) async {
    try {
      final rows = await _database.fetchConversations(
        query: query,
        favoritesOnly: favoritesOnly,
      );
      return Success(
        rows
            .map(
              (row) => Conversation(
                id: row.id,
                title: row.title,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt,
                isPinned: row.isPinned,
                isFavorite: row.isFavorite,
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
  Future<Result<Conversation>> updateConversation(
    Conversation conversation,
  ) async {
    try {
      await _database.upsertConversation(
        id: conversation.id,
        title: conversation.title,
        createdAt: conversation.createdAt,
        updatedAt: conversation.updatedAt,
        isPinned: conversation.isPinned,
        isFavorite: conversation.isFavorite,
      );
      return Success(conversation);
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to update conversation.', cause: error),
      );
    }
  }

  @override
  Future<Result<void>> deleteConversation(String id) async {
    try {
      await _database.deleteConversation(id);
      return const Success(null);
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to delete conversation.', cause: error),
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

  @override
  Future<Result<ChatMessage>> updateMessage(ChatMessage message) async {
    try {
      await _database.updateMessage(
        id: message.id,
        content: message.content,
        metadata: message.metadata,
      );
      return Success(message);
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to update message.', cause: error),
      );
    }
  }

  @override
  Future<Result<String>> exportConversation(String conversationId) async {
    try {
      final conversations = await _database.fetchConversations();
      ConversationRecord? conversation;
      for (final item in conversations) {
        if (item.id == conversationId) {
          conversation = item;
          break;
        }
      }
      final messages = await _database.fetchMessages(conversationId);
      final payload = {
        'conversation': {
          'id': conversation?.id,
          'title': conversation?.title,
          'createdAt': conversation?.createdAt.toIso8601String(),
          'updatedAt': conversation?.updatedAt.toIso8601String(),
        },
        'messages': messages
            .map(
              (message) => {
                'role': message.role.name,
                'content': message.content,
                'createdAt': message.createdAt.toIso8601String(),
              },
            )
            .toList(),
      };
      return Success(const JsonEncoder.withIndent('  ').convert(payload));
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to export conversation.', cause: error),
      );
    }
  }
}
