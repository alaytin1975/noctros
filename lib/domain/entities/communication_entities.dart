import 'noctros_enums.dart';

class Contact {
  const Contact({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    this.email,
    this.avatarColor = 0xFF1F6B5A,
    this.isFavorite = false,
    this.notes,
  });

  final String id;
  final String displayName;
  final String phoneNumber;
  final String? email;
  final int avatarColor;
  final bool isFavorite;
  final String? notes;

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  Contact copyWith({
    String? displayName,
    String? phoneNumber,
    String? email,
    int? avatarColor,
    bool? isFavorite,
    String? notes,
  }) {
    return Contact(
      id: id,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      avatarColor: avatarColor ?? this.avatarColor,
      isFavorite: isFavorite ?? this.isFavorite,
      notes: notes ?? this.notes,
    );
  }
}

class MessageThread {
  const MessageThread({
    required this.id,
    required this.title,
    required this.participantIds,
    required this.updatedAt,
    required this.createdAt,
    this.lastMessagePreview = '',
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
  });

  final String id;
  final String title;
  final List<String> participantIds;
  final DateTime updatedAt;
  final DateTime createdAt;
  final String lastMessagePreview;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;

  MessageThread copyWith({
    String? title,
    List<String>? participantIds,
    DateTime? updatedAt,
    String? lastMessagePreview,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
  }) {
    return MessageThread(
      id: id,
      title: title ?? this.title,
      participantIds: participantIds ?? this.participantIds,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}

class ThreadMessage {
  const ThreadMessage({
    required this.id,
    required this.threadId,
    required this.senderContactId,
    required this.body,
    required this.sentAt,
    required this.isFromMe,
    this.status = ThreadMessageStatus.sent,
  });

  final String id;
  final String threadId;
  final String senderContactId;
  final String body;
  final DateTime sentAt;
  final bool isFromMe;
  final ThreadMessageStatus status;
}

class CallRecord {
  const CallRecord({
    required this.id,
    required this.contactId,
    required this.direction,
    required this.kind,
    required this.startedAt,
    this.durationSeconds = 0,
  });

  final String id;
  final String contactId;
  final CallDirection direction;
  final CallKind kind;
  final DateTime startedAt;
  final int durationSeconds;

  bool get wasMissed => direction == CallDirection.missed;
}

class InboxThreadView {
  const InboxThreadView({
    required this.thread,
    required this.primaryContact,
  });

  final MessageThread thread;
  final Contact? primaryContact;
}
