import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/service_locator.dart';
import '../../domain/entities/communication_entities.dart';
import '../../domain/entities/noctros_enums.dart';
import '../../domain/repositories/communication_repository.dart';
import '../../domain/usecases/send_thread_message_use_case.dart';
import '../../domain/usecases/start_call_use_case.dart';

class InboxState {
  const InboxState({
    this.threads = const [],
    this.isLoading = false,
    this.query = '',
  });

  final List<InboxThreadView> threads;
  final bool isLoading;
  final String query;

  List<InboxThreadView> get filtered {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return threads;
    }
    return threads.where((item) {
      final title = item.thread.title.toLowerCase();
      final preview = item.thread.lastMessagePreview.toLowerCase();
      final contact = item.primaryContact?.displayName.toLowerCase() ?? '';
      return title.contains(normalized) ||
          preview.contains(normalized) ||
          contact.contains(normalized);
    }).toList();
  }

  InboxState copyWith({
    List<InboxThreadView>? threads,
    bool? isLoading,
    String? query,
  }) {
    return InboxState(
      threads: threads ?? this.threads,
      isLoading: isLoading ?? this.isLoading,
      query: query ?? this.query,
    );
  }
}

class InboxController extends StateNotifier<InboxState> {
  InboxController(this._repository) : super(const InboxState());

  final CommunicationRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final result = await _repository.listInboxThreads();
    if (!mounted) {
      return;
    }
    state = state.copyWith(
      isLoading: false,
      threads: result.isSuccess ? result.valueOrThrow : const [],
    );
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }
}

class ThreadSessionState {
  const ThreadSessionState({
    this.thread,
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
  });

  final MessageThread? thread;
  final List<ThreadMessage> messages;
  final bool isLoading;
  final bool isSending;

  ThreadSessionState copyWith({
    MessageThread? thread,
    List<ThreadMessage>? messages,
    bool? isLoading,
    bool? isSending,
  }) {
    return ThreadSessionState(
      thread: thread ?? this.thread,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
    );
  }
}

class ThreadSessionController extends StateNotifier<ThreadSessionState> {
  ThreadSessionController(
    this._repository,
    this._sendThreadMessageUseCase,
  ) : super(const ThreadSessionState());

  final CommunicationRepository _repository;
  final SendThreadMessageUseCase _sendThreadMessageUseCase;

  Future<void> open(String threadId) async {
    state = state.copyWith(isLoading: true);
    final threadResult = await _repository.getThread(threadId);
    final messagesResult = await _repository.listThreadMessages(threadId);
    await _repository.markThreadRead(threadId);
    if (!mounted) {
      return;
    }
    state = state.copyWith(
      isLoading: false,
      thread: threadResult.isSuccess ? threadResult.valueOrThrow : null,
      messages:
          messagesResult.isSuccess ? messagesResult.valueOrThrow : const [],
    );
  }

  Future<bool> send(String body) async {
    final thread = state.thread;
    if (thread == null || body.trim().isEmpty) {
      return false;
    }
    state = state.copyWith(isSending: true);
    final result = await _sendThreadMessageUseCase.execute(
      threadId: thread.id,
      body: body,
    );
    if (!mounted) {
      return false;
    }
    if (result.isFailure) {
      state = state.copyWith(isSending: false);
      return false;
    }
    final messagesResult = await _repository.listThreadMessages(thread.id);
    final threadResult = await _repository.getThread(thread.id);
    if (!mounted) {
      return false;
    }
    state = state.copyWith(
      isSending: false,
      messages:
          messagesResult.isSuccess ? messagesResult.valueOrThrow : state.messages,
      thread: threadResult.isSuccess ? threadResult.valueOrThrow : thread,
    );
    return true;
  }
}

class ContactsState {
  const ContactsState({
    this.contacts = const [],
    this.isLoading = false,
    this.query = '',
  });

  final List<Contact> contacts;
  final bool isLoading;
  final String query;

  List<Contact> get filtered {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return contacts;
    }
    return contacts
        .where(
          (contact) =>
              contact.displayName.toLowerCase().contains(normalized) ||
              contact.phoneNumber.contains(normalized),
        )
        .toList();
  }

  ContactsState copyWith({
    List<Contact>? contacts,
    bool? isLoading,
    String? query,
  }) {
    return ContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      query: query ?? this.query,
    );
  }
}

class ContactsController extends StateNotifier<ContactsState> {
  ContactsController(this._repository) : super(const ContactsState());

  final CommunicationRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final result = await _repository.listContacts();
    if (!mounted) {
      return;
    }
    state = state.copyWith(
      isLoading: false,
      contacts: result.isSuccess ? result.valueOrThrow : const [],
    );
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  Future<bool> save(Contact contact) async {
    final result = await _repository.upsertContact(contact);
    if (result.isSuccess) {
      await load();
    }
    return result.isSuccess;
  }
}

class CallsState {
  const CallsState({
    this.calls = const [],
    this.contactsById = const {},
    this.isLoading = false,
  });

  final List<CallRecord> calls;
  final Map<String, Contact> contactsById;
  final bool isLoading;

  CallsState copyWith({
    List<CallRecord>? calls,
    Map<String, Contact>? contactsById,
    bool? isLoading,
  }) {
    return CallsState(
      calls: calls ?? this.calls,
      contactsById: contactsById ?? this.contactsById,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CallsController extends StateNotifier<CallsState> {
  CallsController(this._repository, this._startCallUseCase)
      : super(const CallsState());

  final CommunicationRepository _repository;
  final StartCallUseCase _startCallUseCase;

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final callsResult = await _repository.listCalls();
    final contactsResult = await _repository.listContacts();
    if (!mounted) {
      return;
    }
    final contacts = contactsResult.isSuccess
        ? {
            for (final contact in contactsResult.valueOrThrow)
              contact.id: contact,
          }
        : <String, Contact>{};
    state = state.copyWith(
      isLoading: false,
      calls: callsResult.isSuccess ? callsResult.valueOrThrow : const [],
      contactsById: contacts,
    );
  }

  Future<CallRecord?> startCall({
    required String contactId,
    CallKind kind = CallKind.audio,
  }) async {
    final result = await _startCallUseCase.execute(
      contactId: contactId,
      kind: kind,
    );
    if (result.isFailure) {
      return null;
    }
    await load();
    return result.valueOrThrow;
  }

  Future<void> endCall({
    required String callId,
    required int durationSeconds,
  }) async {
    await _repository.endCall(
      callId: callId,
      durationSeconds: durationSeconds,
    );
    await load();
  }
}

final inboxControllerProvider =
    StateNotifierProvider<InboxController, InboxState>((ref) {
  return InboxController(ServiceLocator.get<CommunicationRepository>());
});

final threadSessionProvider = StateNotifierProvider.autoDispose
    .family<ThreadSessionController, ThreadSessionState, String>((ref, _) {
  return ThreadSessionController(
    ServiceLocator.get<CommunicationRepository>(),
    SendThreadMessageUseCase(),
  );
});

final contactsControllerProvider =
    StateNotifierProvider<ContactsController, ContactsState>((ref) {
  return ContactsController(ServiceLocator.get<CommunicationRepository>());
});

final callsControllerProvider =
    StateNotifierProvider<CallsController, CallsState>((ref) {
  return CallsController(
    ServiceLocator.get<CommunicationRepository>(),
    StartCallUseCase(),
  );
});
