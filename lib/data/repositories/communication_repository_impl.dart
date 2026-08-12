import 'package:uuid/uuid.dart';

import '../../core/errors/noctros_failure.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/communication_entities.dart';
import '../../domain/entities/noctros_enums.dart';
import '../../domain/repositories/communication_repository.dart';
import '../local/database/noctros_database.dart';

class CommunicationRepositoryImpl implements CommunicationRepository {
  CommunicationRepositoryImpl({required NoctrosDatabase database})
      : _database = database;

  final NoctrosDatabase _database;
  static const _uuid = Uuid();

  @override
  Future<Result<List<Contact>>> listContacts() async {
    try {
      final rows = await _database.fetchContacts();
      return Success(rows.map(_toContact).toList());
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to load contacts.', cause: error),
      );
    }
  }

  @override
  Future<Result<Contact>> getContact(String id) async {
    try {
      final row = await _database.fetchContact(id);
      if (row == null) {
        return const FailureResult(StorageFailure('Contact not found.'));
      }
      return Success(_toContact(row));
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to load contact.', cause: error),
      );
    }
  }

  @override
  Future<Result<Contact>> upsertContact(Contact contact) async {
    try {
      await _database.upsertContact(
        ContactRecord(
          id: contact.id,
          displayName: contact.displayName,
          phoneNumber: contact.phoneNumber,
          email: contact.email,
          avatarColor: contact.avatarColor,
          isFavorite: contact.isFavorite,
          notes: contact.notes,
        ),
      );
      return Success(contact);
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to save contact.', cause: error),
      );
    }
  }

  @override
  Future<Result<void>> deleteContact(String id) async {
    try {
      await _database.deleteContact(id);
      return const Success(null);
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to delete contact.', cause: error),
      );
    }
  }

  @override
  Future<Result<List<InboxThreadView>>> listInboxThreads() async {
    try {
      final threads = await _database.fetchThreads();
      final contacts = {
        for (final contact in await _database.fetchContacts())
          contact.id: _toContact(contact),
      };
      return Success(
        threads
            .map(
              (thread) => InboxThreadView(
                thread: _toThread(thread),
                primaryContact: thread.participantIds.isEmpty
                    ? null
                    : contacts[thread.participantIds.first],
              ),
            )
            .toList(),
      );
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to load inbox.', cause: error),
      );
    }
  }

  @override
  Future<Result<MessageThread>> getThread(String threadId) async {
    try {
      final thread = await _database.fetchThread(threadId);
      if (thread == null) {
        return const FailureResult(StorageFailure('Thread not found.'));
      }
      return Success(_toThread(thread));
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to load thread.', cause: error),
      );
    }
  }

  @override
  Future<Result<MessageThread>> createThread({
    required String title,
    required List<String> participantIds,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final thread = ThreadRecord(
        id: _uuid.v4(),
        title: title,
        participantIds: participantIds,
        createdAt: now,
        updatedAt: now,
        lastMessagePreview: '',
        unreadCount: 0,
        isPinned: false,
        isMuted: false,
      );
      await _database.upsertThread(thread);
      return Success(_toThread(thread));
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to create thread.', cause: error),
      );
    }
  }

  @override
  Future<Result<List<ThreadMessage>>> listThreadMessages(
    String threadId,
  ) async {
    try {
      final rows = await _database.fetchThreadMessages(threadId);
      return Success(rows.map(_toThreadMessage).toList());
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to load messages.', cause: error),
      );
    }
  }

  @override
  Future<Result<ThreadMessage>> sendThreadMessage({
    required String threadId,
    required String body,
  }) async {
    try {
      final thread = await _database.fetchThread(threadId);
      if (thread == null) {
        return const FailureResult(StorageFailure('Thread not found.'));
      }

      final now = DateTime.now().toUtc();
      final message = ThreadMessageRecord(
        id: _uuid.v4(),
        threadId: threadId,
        senderContactId: 'me',
        body: body.trim(),
        sentAt: now,
        isFromMe: true,
        status: ThreadMessageStatus.sent,
      );
      await _database.insertThreadMessage(message);
      await _database.upsertThread(
        ThreadRecord(
          id: thread.id,
          title: thread.title,
          participantIds: thread.participantIds,
          createdAt: thread.createdAt,
          updatedAt: now,
          lastMessagePreview: message.body,
          unreadCount: 0,
          isPinned: thread.isPinned,
          isMuted: thread.isMuted,
        ),
      );

      // Local echo reply so one-device demos feel alive without a backend.
      if (thread.participantIds.isNotEmpty) {
        final reply = ThreadMessageRecord(
          id: _uuid.v4(),
          threadId: threadId,
          senderContactId: thread.participantIds.first,
          body: _localEchoReply(body),
          sentAt: now.add(const Duration(seconds: 1)),
          isFromMe: false,
          status: ThreadMessageStatus.delivered,
        );
        await _database.insertThreadMessage(reply);
        await _database.upsertThread(
          ThreadRecord(
            id: thread.id,
            title: thread.title,
            participantIds: thread.participantIds,
            createdAt: thread.createdAt,
            updatedAt: reply.sentAt,
            lastMessagePreview: reply.body,
            unreadCount: 0,
            isPinned: thread.isPinned,
            isMuted: thread.isMuted,
          ),
        );
      }

      return Success(_toThreadMessage(message));
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to send message.', cause: error),
      );
    }
  }

  @override
  Future<Result<void>> markThreadRead(String threadId) async {
    try {
      final thread = await _database.fetchThread(threadId);
      if (thread == null) {
        return const FailureResult(StorageFailure('Thread not found.'));
      }
      await _database.upsertThread(
        ThreadRecord(
          id: thread.id,
          title: thread.title,
          participantIds: thread.participantIds,
          createdAt: thread.createdAt,
          updatedAt: thread.updatedAt,
          lastMessagePreview: thread.lastMessagePreview,
          unreadCount: 0,
          isPinned: thread.isPinned,
          isMuted: thread.isMuted,
        ),
      );
      return const Success(null);
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to mark thread read.', cause: error),
      );
    }
  }

  @override
  Future<Result<List<CallRecord>>> listCalls() async {
    try {
      final rows = await _database.fetchCalls();
      return Success(
        rows
            .map(
              (row) => CallRecord(
                id: row.id,
                contactId: row.contactId,
                direction: row.direction,
                kind: row.kind,
                startedAt: row.startedAt,
                durationSeconds: row.durationSeconds,
              ),
            )
            .toList(),
      );
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to load calls.', cause: error),
      );
    }
  }

  @override
  Future<Result<CallRecord>> startCall({
    required String contactId,
    required CallKind kind,
    CallDirection direction = CallDirection.outgoing,
  }) async {
    try {
      final call = CallRecordRow(
        id: _uuid.v4(),
        contactId: contactId,
        direction: direction,
        kind: kind,
        startedAt: DateTime.now().toUtc(),
        durationSeconds: 0,
      );
      await _database.insertCall(call);
      return Success(
        CallRecord(
          id: call.id,
          contactId: call.contactId,
          direction: call.direction,
          kind: call.kind,
          startedAt: call.startedAt,
          durationSeconds: call.durationSeconds,
        ),
      );
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to start call.', cause: error),
      );
    }
  }

  @override
  Future<Result<CallRecord>> endCall({
    required String callId,
    required int durationSeconds,
  }) async {
    try {
      await _database.updateCallDuration(
        callId: callId,
        durationSeconds: durationSeconds,
      );
      final calls = await _database.fetchCalls();
      final match = calls.where((call) => call.id == callId);
      if (match.isEmpty) {
        return const FailureResult(StorageFailure('Call not found.'));
      }
      final call = match.first;
      return Success(
        CallRecord(
          id: call.id,
          contactId: call.contactId,
          direction: call.direction,
          kind: call.kind,
          startedAt: call.startedAt,
          durationSeconds: durationSeconds,
        ),
      );
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to end call.', cause: error),
      );
    }
  }

  Contact _toContact(ContactRecord row) {
    return Contact(
      id: row.id,
      displayName: row.displayName,
      phoneNumber: row.phoneNumber,
      email: row.email,
      avatarColor: row.avatarColor,
      isFavorite: row.isFavorite,
      notes: row.notes,
    );
  }

  MessageThread _toThread(ThreadRecord row) {
    return MessageThread(
      id: row.id,
      title: row.title,
      participantIds: row.participantIds,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      lastMessagePreview: row.lastMessagePreview,
      unreadCount: row.unreadCount,
      isPinned: row.isPinned,
      isMuted: row.isMuted,
    );
  }

  ThreadMessage _toThreadMessage(ThreadMessageRecord row) {
    return ThreadMessage(
      id: row.id,
      threadId: row.threadId,
      senderContactId: row.senderContactId,
      body: row.body,
      sentAt: row.sentAt,
      isFromMe: row.isFromMe,
      status: row.status,
    );
  }

  String _localEchoReply(String body) {
    final trimmed = body.trim();
    if (trimmed.toLowerCase().contains('call')) {
      return 'Sounds good — call me whenever you’re free.';
    }
    if (trimmed.endsWith('?')) {
      return 'Got it. I’ll get back to you shortly.';
    }
    return 'Thanks — just saw this.';
  }
}
