import 'noctros_enums.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.metadata = const {},
  });

  final String id;
  final String conversationId;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
  final Map<String, Object?> metadata;

  ChatMessage copyWith({
    String? content,
    Map<String, Object?>? metadata,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
}

class MemoryEntry {
  const MemoryEntry({
    required this.id,
    required this.category,
    required this.key,
    required this.value,
    required this.createdAt,
    required this.updatedAt,
    this.sourceConversationId,
  });

  final String id;
  final MemoryCategory category;
  final String key;
  final String value;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sourceConversationId;
}

class UserSettings {
  const UserSettings({
    required this.wakeWords,
    required this.preferredLanguageCode,
    required this.aiExecutionMode,
    required this.cloudPolicy,
    required this.memoryEnabled,
    required this.emergencyAutoDialEnabled,
    required this.emergencyContacts,
    required this.darkModeEnabled,
  });

  final List<String> wakeWords;
  final String preferredLanguageCode;
  final AiExecutionMode aiExecutionMode;
  final PrivacyCloudPolicy cloudPolicy;
  final bool memoryEnabled;
  final bool emergencyAutoDialEnabled;
  final List<EmergencyContact> emergencyContacts;
  final bool darkModeEnabled;

  static UserSettings defaults() {
    return const UserSettings(
      wakeWords: ['Hey Noctros', 'Noctros'],
      preferredLanguageCode: 'en',
      aiExecutionMode: AiExecutionMode.hybrid,
      cloudPolicy: PrivacyCloudPolicy.whenRequired,
      memoryEnabled: false,
      emergencyAutoDialEnabled: false,
      emergencyContacts: [],
      darkModeEnabled: false,
    );
  }

  UserSettings copyWith({
    List<String>? wakeWords,
    String? preferredLanguageCode,
    AiExecutionMode? aiExecutionMode,
    PrivacyCloudPolicy? cloudPolicy,
    bool? memoryEnabled,
    bool? emergencyAutoDialEnabled,
    List<EmergencyContact>? emergencyContacts,
    bool? darkModeEnabled,
  }) {
    return UserSettings(
      wakeWords: wakeWords ?? this.wakeWords,
      preferredLanguageCode:
          preferredLanguageCode ?? this.preferredLanguageCode,
      aiExecutionMode: aiExecutionMode ?? this.aiExecutionMode,
      cloudPolicy: cloudPolicy ?? this.cloudPolicy,
      memoryEnabled: memoryEnabled ?? this.memoryEnabled,
      emergencyAutoDialEnabled:
          emergencyAutoDialEnabled ?? this.emergencyAutoDialEnabled,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
    );
  }
}

class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.notifyOnEmergency = true,
  });

  final String id;
  final String name;
  final String phoneNumber;
  final bool notifyOnEmergency;
}

class AiRequest {
  const AiRequest({
    required this.prompt,
    required this.conversationId,
    this.complexity = AiTaskComplexity.moderate,
    this.preferredMode,
    this.contextMessages = const [],
    this.requiresInternet = false,
  });

  final String prompt;
  final String conversationId;
  final AiTaskComplexity complexity;
  final AiExecutionMode? preferredMode;
  final List<ChatMessage> contextMessages;
  final bool requiresInternet;
}

class AiResponse {
  const AiResponse({
    required this.content,
    required this.modeUsed,
    required this.processedLocally,
    this.tokenCount,
  });

  final String content;
  final AiExecutionMode modeUsed;
  final bool processedLocally;
  final int? tokenCount;
}

class EmergencyEvent {
  const EmergencyEvent({
    required this.id,
    required this.triggerType,
    required this.detectedPhrase,
    required this.detectedAt,
    this.latitude,
    this.longitude,
    this.requiresConfirmation = true,
  });

  final String id;
  final EmergencyTriggerType triggerType;
  final String detectedPhrase;
  final DateTime detectedAt;
  final double? latitude;
  final double? longitude;
  final bool requiresConfirmation;
}
