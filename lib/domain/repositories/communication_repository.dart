import '../../core/utils/result.dart';
import '../entities/communication_entities.dart';
import '../entities/noctros_enums.dart';

abstract interface class CommunicationRepository {
  Future<Result<List<Contact>>> listContacts();
  Future<Result<Contact>> getContact(String id);
  Future<Result<Contact>> upsertContact(Contact contact);
  Future<Result<void>> deleteContact(String id);

  Future<Result<List<InboxThreadView>>> listInboxThreads();
  Future<Result<MessageThread>> getThread(String threadId);
  Future<Result<MessageThread>> createThread({
    required String title,
    required List<String> participantIds,
  });
  Future<Result<List<ThreadMessage>>> listThreadMessages(String threadId);
  Future<Result<ThreadMessage>> sendThreadMessage({
    required String threadId,
    required String body,
  });
  Future<Result<void>> markThreadRead(String threadId);

  Future<Result<List<CallRecord>>> listCalls();
  Future<Result<CallRecord>> startCall({
    required String contactId,
    required CallKind kind,
    CallDirection direction = CallDirection.outgoing,
  });
  Future<Result<CallRecord>> endCall({
    required String callId,
    required int durationSeconds,
  });
}
