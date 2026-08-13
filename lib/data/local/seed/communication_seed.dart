import 'package:uuid/uuid.dart';

import '../../../domain/entities/noctros_enums.dart';
import '../database/noctros_database.dart';

/// Seeds a realistic inbox so the iPhone communication UI is usable offline.
abstract final class CommunicationSeed {
  static const _uuid = Uuid();

  static Future<void> ensureSeeded(NoctrosDatabase database) async {
    final existing = await database.fetchContacts();
    if (existing.isNotEmpty) {
      return;
    }

    final now = DateTime.now().toUtc();
    final contacts = <ContactRecord>[
      ContactRecord(
        id: 'contact-maya',
        displayName: 'Maya Chen',
        phoneNumber: '+1 (415) 555-0142',
        email: 'maya@example.com',
        avatarColor: 0xFF1F6B5A,
        isFavorite: true,
        notes: 'Weekend hiking plans',
      ),
      ContactRecord(
        id: 'contact-jordan',
        displayName: 'Jordan Blake',
        phoneNumber: '+1 (628) 555-0198',
        email: 'jordan@example.com',
        avatarColor: 0xFF2F5D8C,
        isFavorite: true,
        notes: 'Design critique Thursday',
      ),
      ContactRecord(
        id: 'contact-sam',
        displayName: 'Sam Okonkwo',
        phoneNumber: '+1 (510) 555-0177',
        email: 'sam@example.com',
        avatarColor: 0xFF8A4B2F,
        isFavorite: false,
        notes: null,
      ),
      ContactRecord(
        id: 'contact-elena',
        displayName: 'Elena Rossi',
        phoneNumber: '+1 (925) 555-0110',
        email: 'elena@example.com',
        avatarColor: 0xFF5C4B8A,
        isFavorite: false,
        notes: 'Sister',
      ),
      ContactRecord(
        id: 'contact-noah',
        displayName: 'Noah Patel',
        phoneNumber: '+1 (707) 555-0133',
        email: 'noah@example.com',
        avatarColor: 0xFF3D6B4F,
        isFavorite: false,
        notes: null,
      ),
    ];

    for (final contact in contacts) {
      await database.upsertContact(contact);
    }

    Future<void> seedThread({
      required String threadId,
      required String title,
      required List<String> participantIds,
      required List<({String from, String body, Duration ago})> messages,
      int unreadCount = 0,
      bool isPinned = false,
    }) async {
      final latest = now.subtract(messages.last.ago);
      await database.upsertThread(
        ThreadRecord(
          id: threadId,
          title: title,
          participantIds: participantIds,
          createdAt: now.subtract(const Duration(days: 14)),
          updatedAt: latest,
          lastMessagePreview: messages.last.body,
          unreadCount: unreadCount,
          isPinned: isPinned,
          isMuted: false,
        ),
      );

      for (final message in messages) {
        final isFromMe = message.from == 'me';
        await database.insertThreadMessage(
          ThreadMessageRecord(
            id: _uuid.v4(),
            threadId: threadId,
            senderContactId: isFromMe ? 'me' : message.from,
            body: message.body,
            sentAt: now.subtract(message.ago),
            isFromMe: isFromMe,
            status: isFromMe
                ? ThreadMessageStatus.read
                : ThreadMessageStatus.delivered,
          ),
        );
      }
    }

    await seedThread(
      threadId: 'thread-maya',
      title: 'Maya Chen',
      participantIds: const ['contact-maya'],
      isPinned: true,
      unreadCount: 1,
      messages: [
        (
          from: 'contact-maya',
          body: 'Are we still on for the trail tomorrow?',
          ago: const Duration(hours: 26),
        ),
        (
          from: 'me',
          body: 'Yes — leaving at 8. I’ll bring water.',
          ago: const Duration(hours: 25),
        ),
        (
          from: 'contact-maya',
          body: 'Perfect. See you at the overlook 🌅',
          ago: const Duration(minutes: 18),
        ),
      ],
    );

    await seedThread(
      threadId: 'thread-jordan',
      title: 'Jordan Blake',
      participantIds: const ['contact-jordan'],
      unreadCount: 2,
      messages: [
        (
          from: 'me',
          body: 'Sent the revised mockups.',
          ago: const Duration(hours: 5),
        ),
        (
          from: 'contact-jordan',
          body: 'Love the quieter header.',
          ago: const Duration(hours: 4, minutes: 40),
        ),
        (
          from: 'contact-jordan',
          body: 'Can we jump on a quick call later?',
          ago: const Duration(hours: 1),
        ),
      ],
    );

    await seedThread(
      threadId: 'thread-sam',
      title: 'Sam Okonkwo',
      participantIds: const ['contact-sam'],
      messages: [
        (
          from: 'contact-sam',
          body: 'Dinner reservation is confirmed for 7:30.',
          ago: const Duration(days: 1, hours: 3),
        ),
        (
          from: 'me',
          body: 'Great — I’ll meet you downstairs.',
          ago: const Duration(days: 1, hours: 2),
        ),
      ],
    );

    await seedThread(
      threadId: 'thread-elena',
      title: 'Elena Rossi',
      participantIds: const ['contact-elena'],
      messages: [
        (
          from: 'contact-elena',
          body: 'Mom says hi. Call when you can.',
          ago: const Duration(days: 2),
        ),
        (
          from: 'me',
          body: 'Will do tonight.',
          ago: const Duration(days: 2) - const Duration(hours: 1),
        ),
      ],
    );

    await database.insertCall(
      CallRecordRow(
        id: _uuid.v4(),
        contactId: 'contact-jordan',
        direction: CallDirection.outgoing,
        kind: CallKind.audio,
        startedAt: now.subtract(const Duration(hours: 6)),
        durationSeconds: 482,
      ),
    );
    await database.insertCall(
      CallRecordRow(
        id: _uuid.v4(),
        contactId: 'contact-maya',
        direction: CallDirection.missed,
        kind: CallKind.audio,
        startedAt: now.subtract(const Duration(days: 1, hours: 2)),
        durationSeconds: 0,
      ),
    );
    await database.insertCall(
      CallRecordRow(
        id: _uuid.v4(),
        contactId: 'contact-elena',
        direction: CallDirection.incoming,
        kind: CallKind.video,
        startedAt: now.subtract(const Duration(days: 3)),
        durationSeconds: 1210,
      ),
    );
  }
}
