import '../../core/utils/result.dart';
import '../entities/noctros_entities.dart';
import '../entities/noctros_enums.dart';

abstract interface class AiRepository {
  Future<Result<AiResponse>> complete(AiRequest request);
  Future<Result<AiExecutionMode>> resolveMode(AiRequest request);
}

abstract interface class ConversationRepository {
  Future<Result<List<Conversation>>> listConversations();
  Future<Result<Conversation>> createConversation({required String title});
  Future<Result<List<ChatMessage>>> listMessages(String conversationId);
  Future<Result<ChatMessage>> appendMessage(ChatMessage message);
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
