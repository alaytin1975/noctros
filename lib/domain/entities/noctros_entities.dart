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
    this.isFavorite = false,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final bool isFavorite;

  Conversation copyWith({
    String? title,
    DateTime? updatedAt,
    bool? isPinned,
    bool? isFavorite,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
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
    this.speechRate = 0.48,
    this.ttsEnabled = true,
    this.sttLocaleId = 'en_US',
    this.continuousVoiceEnabled = false,
    this.alwaysListeningPrepared = false,
    this.defaultNavigationApp = 'google_maps',
    this.preferredBrowser = 'default',
    this.rememberPreferredContacts = false,
    this.confirmDeviceActions = true,
    this.assistantName = 'Noctros',
    this.wakeWordEnabled = true,
    this.voiceGender = VoiceGender.system,
    this.speechPitch = 1.0,
    this.speechVolume = 1.0,
    this.voiceIdEnabled = false,
    this.cloudSttFallbackEnabled = true,
    this.sttBackend = SttBackend.auto,
    this.ttsBackend = TtsBackend.offline,
    this.emergencyNumber = '112',
  });

  final List<String> wakeWords;
  final String preferredLanguageCode;
  final AiExecutionMode aiExecutionMode;
  final PrivacyCloudPolicy cloudPolicy;
  final bool memoryEnabled;
  final bool emergencyAutoDialEnabled;
  final List<EmergencyContact> emergencyContacts;
  final bool darkModeEnabled;
  final double speechRate;
  final bool ttsEnabled;
  final String sttLocaleId;
  final bool continuousVoiceEnabled;
  final bool alwaysListeningPrepared;
  final String defaultNavigationApp;
  final String preferredBrowser;
  final bool rememberPreferredContacts;
  final bool confirmDeviceActions;
  final String assistantName;
  final bool wakeWordEnabled;
  final VoiceGender voiceGender;
  final double speechPitch;
  final double speechVolume;
  final bool voiceIdEnabled;
  final bool cloudSttFallbackEnabled;
  final SttBackend sttBackend;
  final TtsBackend ttsBackend;
  final String emergencyNumber;

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

  /// Builds wake phrases from the current assistant name.
  List<String> get derivedWakeWords {
    final name = assistantName.trim();
    if (name.isEmpty) {
      return wakeWords;
    }
    final hey = 'Hey $name';
    final unique = <String>{hey, name, ...wakeWords};
    return unique.toList();
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
    double? speechRate,
    bool? ttsEnabled,
    String? sttLocaleId,
    bool? continuousVoiceEnabled,
    bool? alwaysListeningPrepared,
    String? defaultNavigationApp,
    String? preferredBrowser,
    bool? rememberPreferredContacts,
    bool? confirmDeviceActions,
    String? assistantName,
    bool? wakeWordEnabled,
    VoiceGender? voiceGender,
    double? speechPitch,
    double? speechVolume,
    bool? voiceIdEnabled,
    bool? cloudSttFallbackEnabled,
    SttBackend? sttBackend,
    TtsBackend? ttsBackend,
    String? emergencyNumber,
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
      speechRate: speechRate ?? this.speechRate,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      sttLocaleId: sttLocaleId ?? this.sttLocaleId,
      continuousVoiceEnabled:
          continuousVoiceEnabled ?? this.continuousVoiceEnabled,
      alwaysListeningPrepared:
          alwaysListeningPrepared ?? this.alwaysListeningPrepared,
      defaultNavigationApp:
          defaultNavigationApp ?? this.defaultNavigationApp,
      preferredBrowser: preferredBrowser ?? this.preferredBrowser,
      rememberPreferredContacts:
          rememberPreferredContacts ?? this.rememberPreferredContacts,
      confirmDeviceActions: confirmDeviceActions ?? this.confirmDeviceActions,
      assistantName: assistantName ?? this.assistantName,
      wakeWordEnabled: wakeWordEnabled ?? this.wakeWordEnabled,
      voiceGender: voiceGender ?? this.voiceGender,
      speechPitch: speechPitch ?? this.speechPitch,
      speechVolume: speechVolume ?? this.speechVolume,
      voiceIdEnabled: voiceIdEnabled ?? this.voiceIdEnabled,
      cloudSttFallbackEnabled:
          cloudSttFallbackEnabled ?? this.cloudSttFallbackEnabled,
      sttBackend: sttBackend ?? this.sttBackend,
      ttsBackend: ttsBackend ?? this.ttsBackend,
      emergencyNumber: emergencyNumber ?? this.emergencyNumber,
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
    this.memoryContext,
  });

  final String prompt;
  final String conversationId;
  final AiTaskComplexity complexity;
  final AiExecutionMode? preferredMode;
  final List<ChatMessage> contextMessages;
  final bool requiresInternet;
  final String? memoryContext;
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
