import 'package:flutter_test/flutter_test.dart';
import 'package:noctros/data/local/database/noctros_database.dart';
import 'package:noctros/data/local/seed/communication_seed.dart';
import 'package:noctros/data/repositories/communication_repository_impl.dart';
import 'package:noctros/domain/entities/noctros_enums.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NoctrosDatabase database;
  late CommunicationRepositoryImpl repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = NoctrosDatabase(
      databasePath: '${inMemoryDatabasePath}_${DateTime.now().microsecondsSinceEpoch}',
    );
    await database.open();
    await CommunicationSeed.ensureSeeded(database);
    repository = CommunicationRepositoryImpl(database: database);
  });

  test('seed creates contacts, inbox threads, and call history', () async {
    final contacts = await repository.listContacts();
    final inbox = await repository.listInboxThreads();
    final calls = await repository.listCalls();

    expect(contacts.isSuccess, isTrue);
    expect(contacts.valueOrThrow, isNotEmpty);
    expect(inbox.isSuccess, isTrue);
    expect(inbox.valueOrThrow.length, greaterThanOrEqualTo(3));
    expect(calls.isSuccess, isTrue);
    expect(calls.valueOrThrow, isNotEmpty);
  });

  test('sending a message appends local echo reply', () async {
    const threadId = 'thread-maya';
    final before = await repository.listThreadMessages(threadId);
    expect(before.isSuccess, isTrue);
    expect(before.valueOrThrow, isNotEmpty);

    final sent = await repository.sendThreadMessage(
      threadId: threadId,
      body: 'Can we call later?',
    );
    expect(sent.isSuccess, isTrue);

    final messages = await repository.listThreadMessages(threadId);
    expect(messages.isSuccess, isTrue);
    expect(messages.valueOrThrow.length, before.valueOrThrow.length + 2);
    expect(messages.valueOrThrow.last.isFromMe, isFalse);
    expect(
      messages.valueOrThrow.last.body.toLowerCase(),
      contains('call'),
    );
  });

  test('start and end call updates duration', () async {
    final contacts = await repository.listContacts();
    final contactId = contacts.valueOrThrow.first.id;

    final started = await repository.startCall(
      contactId: contactId,
      kind: CallKind.audio,
    );
    expect(started.isSuccess, isTrue);

    final ended = await repository.endCall(
      callId: started.valueOrThrow.id,
      durationSeconds: 42,
    );
    expect(ended.isSuccess, isTrue);
    expect(ended.valueOrThrow.durationSeconds, 42);
  });
}
