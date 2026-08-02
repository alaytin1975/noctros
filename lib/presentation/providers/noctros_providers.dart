import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/service_locator.dart';
import '../../domain/entities/noctros_entities.dart';
import '../../domain/repositories/noctros_repositories.dart';

class ChatSessionState {
  const ChatSessionState({
    this.conversationId,
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
  });

  final String? conversationId;
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;

  ChatSessionState copyWith({
    String? conversationId,
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
  }) {
    return ChatSessionState(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
    );
  }
}

class ChatSessionController extends StateNotifier<ChatSessionState> {
  ChatSessionController(this._conversationRepository)
      : super(const ChatSessionState());

  final ConversationRepository _conversationRepository;

  Future<void> createConversation() async {
    state = state.copyWith(isLoading: true);
    final result = await _conversationRepository.createConversation(
      title: 'Noctros Session',
    );
    if (result.isFailure) {
      state = state.copyWith(isLoading: false);
      return;
    }
    state = state.copyWith(
      conversationId: result.valueOrThrow.id,
      messages: const [],
      isLoading: false,
    );
    await reloadMessages();
  }

  Future<void> openConversation(String conversationId) async {
    state = state.copyWith(
      conversationId: conversationId,
      isLoading: true,
      messages: const [],
    );
    await reloadMessages();
    state = state.copyWith(isLoading: false);
  }

  Future<void> reloadMessages() async {
    final conversationId = state.conversationId;
    if (conversationId == null) {
      return;
    }
    final result = await _conversationRepository.listMessages(conversationId);
    if (result.isSuccess) {
      state = state.copyWith(messages: result.valueOrThrow);
    }
  }

  void setSending(bool value) {
    state = state.copyWith(isSending: value);
  }
}

class ConversationListState {
  const ConversationListState({
    this.conversations = const [],
    this.isLoading = false,
  });

  final List<Conversation> conversations;
  final bool isLoading;

  ConversationListState copyWith({
    List<Conversation>? conversations,
    bool? isLoading,
  }) {
    return ConversationListState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ConversationListController extends StateNotifier<ConversationListState> {
  ConversationListController(this._conversationRepository)
      : super(const ConversationListState());

  final ConversationRepository _conversationRepository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final result = await _conversationRepository.listConversations();
    state = state.copyWith(
      isLoading: false,
      conversations: result.isSuccess ? result.valueOrThrow : const [],
    );
  }
}

class SettingsControllerState {
  const SettingsControllerState({
    this.settings,
    this.isLoading = false,
  });

  final UserSettings? settings;
  final bool isLoading;

  SettingsControllerState copyWith({
    UserSettings? settings,
    bool? isLoading,
  }) {
    return SettingsControllerState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsController extends StateNotifier<SettingsControllerState> {
  SettingsController(this._settingsRepository)
      : super(const SettingsControllerState());

  final SettingsRepository _settingsRepository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final result = await _settingsRepository.loadSettings();
    state = state.copyWith(
      isLoading: false,
      settings: result.isSuccess ? result.valueOrThrow : UserSettings.defaults(),
    );
  }

  Future<void> save(UserSettings settings) async {
    final result = await _settingsRepository.saveSettings(settings);
    if (result.isSuccess) {
      state = state.copyWith(settings: result.valueOrThrow);
    }
  }
}

final chatSessionProvider =
    StateNotifierProvider<ChatSessionController, ChatSessionState>((ref) {
  return ChatSessionController(ServiceLocator.get<ConversationRepository>());
});

final conversationListProvider =
    StateNotifierProvider<ConversationListController, ConversationListState>(
        (ref) {
  return ConversationListController(
    ServiceLocator.get<ConversationRepository>(),
  );
});

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsControllerState>((ref) {
  return SettingsController(ServiceLocator.get<SettingsRepository>());
});
