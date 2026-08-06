import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/service_locator.dart';
import '../../domain/entities/device_action_entities.dart';
import '../../domain/entities/noctros_entities.dart';
import '../../domain/repositories/action_log_repository.dart';
import '../../domain/repositories/noctros_repositories.dart';

class ChatSessionState {
  const ChatSessionState({
    this.conversationId,
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.streamingContent,
  });

  final String? conversationId;
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? streamingContent;

  ChatSessionState copyWith({
    String? conversationId,
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? streamingContent,
    bool clearStreaming = false,
  }) {
    return ChatSessionState(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      streamingContent:
          clearStreaming ? null : (streamingContent ?? this.streamingContent),
    );
  }
}

class ChatSessionController extends StateNotifier<ChatSessionState> {
  ChatSessionController(this._conversationRepository)
      : super(const ChatSessionState());

  final ConversationRepository _conversationRepository;

  Future<void> createConversation() async {
    state = state.copyWith(isLoading: true, clearStreaming: true);
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
  }

  Future<void> openConversation(String conversationId) async {
    state = state.copyWith(
      conversationId: conversationId,
      isLoading: true,
      messages: const [],
      clearStreaming: true,
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
      state = state.copyWith(
        messages: result.valueOrThrow,
        clearStreaming: true,
      );
    }
  }

  void setSending(bool value) {
    state = state.copyWith(isSending: value);
  }

  void setStreamingContent(String? value) {
    if (value == null) {
      state = state.copyWith(clearStreaming: true);
      return;
    }
    state = state.copyWith(streamingContent: value);
  }
}

class ConversationListState {
  const ConversationListState({
    this.conversations = const [],
    this.isLoading = false,
    this.query = '',
    this.favoritesOnly = false,
  });

  final List<Conversation> conversations;
  final bool isLoading;
  final String query;
  final bool favoritesOnly;

  ConversationListState copyWith({
    List<Conversation>? conversations,
    bool? isLoading,
    String? query,
    bool? favoritesOnly,
  }) {
    return ConversationListState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      query: query ?? this.query,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    );
  }
}

class ConversationListController extends StateNotifier<ConversationListState> {
  ConversationListController(this._conversationRepository)
      : super(const ConversationListState());

  final ConversationRepository _conversationRepository;

  Future<void> load({String? query, bool? favoritesOnly}) async {
    state = state.copyWith(
      isLoading: true,
      query: query ?? state.query,
      favoritesOnly: favoritesOnly ?? state.favoritesOnly,
    );
    final result = await _conversationRepository.listConversations(
      query: state.query.isEmpty ? null : state.query,
      favoritesOnly: state.favoritesOnly,
    );
    state = state.copyWith(
      isLoading: false,
      conversations: result.isSuccess ? result.valueOrThrow : const [],
    );
  }

  Future<void> togglePin(Conversation conversation) async {
    await _conversationRepository.updateConversation(
      conversation.copyWith(isPinned: !conversation.isPinned),
    );
    await load();
  }

  Future<void> toggleFavorite(Conversation conversation) async {
    await _conversationRepository.updateConversation(
      conversation.copyWith(isFavorite: !conversation.isFavorite),
    );
    await load();
  }

  Future<void> rename(Conversation conversation, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _conversationRepository.updateConversation(
      conversation.copyWith(title: trimmed),
    );
    await load();
  }

  Future<void> delete(String conversationId) async {
    await _conversationRepository.deleteConversation(conversationId);
    await load();
  }

  Future<ResultExport> export(String conversationId) async {
    final result =
        await _conversationRepository.exportConversation(conversationId);
    if (result.isFailure) {
      return ResultExport(error: result.failureOrNull?.message);
    }
    return ResultExport(content: result.valueOrThrow);
  }
}

class ResultExport {
  ResultExport({this.content, this.error});

  final String? content;
  final String? error;
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

final recentConversationsProvider = Provider<List<Conversation>>((ref) {
  return ref.watch(conversationListProvider).conversations.take(5).toList();
});

final recentActionsProvider =
    FutureProvider<List<DeviceActionLog>>((ref) async {
  final result =
      await ServiceLocator.get<ActionLogRepository>().listRecent(limit: 8);
  if (result.isFailure) {
    return const [];
  }
  return result.valueOrThrow;
});

final favoriteMemoryProvider =
    FutureProvider<List<MemoryEntry>>((ref) async {
  final result = await ServiceLocator.get<MemoryRepository>().listEntries();
  if (result.isFailure) {
    return const [];
  }
  return result.valueOrThrow
      .where(
        (entry) =>
            entry.key == 'favorite_app' ||
            entry.key == 'favorite_destination' ||
            entry.key == 'preferred_contact' ||
            entry.key == 'frequent_command',
      )
      .toList();
});

/// Pending command queued from Home shortcuts into Chat.
final pendingCommandProvider = StateProvider<String?>((ref) => null);

/// Default home shortcuts for fast device actions.
const defaultDeviceShortcuts = <DeviceShortcut>[
  DeviceShortcut(
    id: 'camera',
    label: 'Camera',
    command: 'Open Camera',
    iconName: 'camera',
    isFavorite: true,
  ),
  DeviceShortcut(
    id: 'maps',
    label: 'Navigate home',
    command: 'Navigate to home',
    iconName: 'map',
    isFavorite: true,
  ),
  DeviceShortcut(
    id: 'whatsapp',
    label: 'WhatsApp',
    command: 'Open WhatsApp',
    iconName: 'chat',
    isFavorite: true,
  ),
  DeviceShortcut(
    id: 'settings',
    label: 'Settings',
    command: 'Open Settings',
    iconName: 'settings',
    isFavorite: true,
  ),
];
