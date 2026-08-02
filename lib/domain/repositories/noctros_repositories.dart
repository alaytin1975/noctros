import '../../core/utils/result.dart';
import '../entities/noctros_entities.dart';
import '../entities/noctros_enums.dart';

abstract interface class AiRepository {
  Future<Result<AiResponse>> complete(AiRequest request);
  Stream<String> streamComplete(AiRequest request);
  Future<Result<AiExecutionMode>> resolveMode(AiRequest request);
}

abstract interface class ConversationRepository {
  Future<Result<List<Conversation>>> listConversations({
    String? query,
    bool favoritesOnly = false,
  });
  Future<Result<Conversation>> createConversation({required String title});
  Future<Result<Conversation>> updateConversation(Conversation conversation);
  Future<Result<void>> deleteConversation(String id);
  Future<Result<List<ChatMessage>>> listMessages(String conversationId);
  Future<Result<ChatMessage>> appendMessage(ChatMessage message);
  Future<Result<ChatMessage>> updateMessage(ChatMessage message);
  Future<Result<String>> exportConversation(String conversationId);
}

abstract interface class MemoryRepository {
  Future<Result<List<MemoryEntry>>> listEntries();
  Future<Result<MemoryEntry>> upsertEntry(MemoryEntry entry);
  Future<Result<void>> deleteEntry(String id);
  Future<Result<void>> deleteAll();
}

abstract interface class SettingsRepository {
  Future<Result<UserSettings>> loadSettings();
  Future<Result<UserSettings>> saveSettings(UserSettings settings);
}
