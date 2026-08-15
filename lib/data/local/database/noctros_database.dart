import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../domain/entities/noctros_enums.dart';

class ConversationRecord {
  ConversationRecord({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.isPinned,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
}

class MessageRecord {
  MessageRecord({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.metadata,
  });

  final String id;
  final String conversationId;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
  final Map<String, Object?> metadata;
}

class MemoryEntryRecord {
  MemoryEntryRecord({
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

class ContactRecord {
  ContactRecord({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    required this.avatarColor,
    required this.isFavorite,
    this.email,
    this.notes,
  });

  final String id;
  final String displayName;
  final String phoneNumber;
  final String? email;
  final int avatarColor;
  final bool isFavorite;
  final String? notes;
}

class ThreadRecord {
  ThreadRecord({
    required this.id,
    required this.title,
    required this.participantIds,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessagePreview,
    required this.unreadCount,
    required this.isPinned,
    required this.isMuted,
  });

  final String id;
  final String title;
  final List<String> participantIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastMessagePreview;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
}

class ThreadMessageRecord {
  ThreadMessageRecord({
    required this.id,
    required this.threadId,
    required this.senderContactId,
    required this.body,
    required this.sentAt,
    required this.isFromMe,
    required this.status,
  });

  final String id;
  final String threadId;
  final String senderContactId;
  final String body;
  final DateTime sentAt;
  final bool isFromMe;
  final ThreadMessageStatus status;
}

class CallRecordRow {
  CallRecordRow({
    required this.id,
    required this.contactId,
    required this.direction,
    required this.kind,
    required this.startedAt,
    required this.durationSeconds,
  });

  final String id;
  final String contactId;
  final CallDirection direction;
  final CallKind kind;
  final DateTime startedAt;
  final int durationSeconds;
}

/// Owns the on-disk sqflite database. The path is resolved by
/// [PlatformStorage] before construction; this class never talks to
/// path_provider directly.
class NoctrosDatabase {
  NoctrosDatabase({required this.databasePath});

  final String databasePath;

  Database? _database;

  Future<void> open() async {
    _database ??= await _openDatabase();
  }

  Database get db {
    final database = _database;
    if (database == null) {
      throw StateError('NoctrosDatabase.open() must be called first.');
    }
    return database;
  }

  Future<void> upsertConversation({
    required String id,
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
    bool isPinned = false,
  }) async {
    await db.insert(
      'conversations',
      {
        'id': id,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_pinned': isPinned ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ConversationRecord>> fetchConversations() async {
    final rows = await db.query(
      'conversations',
      orderBy: 'updated_at DESC',
    );
    return rows.map(_mapConversation).toList();
  }

  Future<void> insertMessage({
    required String id,
    required String conversationId,
    required MessageRole role,
    required String content,
    required DateTime createdAt,
    Map<String, Object?> metadata = const {},
  }) async {
    await db.insert(
      'messages',
      {
        'id': id,
        'conversation_id': conversationId,
        'role': role.name,
        'content': content,
        'metadata_json': jsonEncode(metadata),
        'created_at': createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MessageRecord>> fetchMessages(String conversationId) async {
    final rows = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return rows.map(_mapMessage).toList();
  }

  Future<void> upsertMemoryEntry({
    required String id,
    required MemoryCategory category,
    required String key,
    required String value,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? sourceConversationId,
  }) async {
    await db.insert(
      'memory_entries',
      {
        'id': id,
        'category': category.name,
        'entry_key': key,
        'entry_value': value,
        'source_conversation_id': sourceConversationId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MemoryEntryRecord>> fetchMemoryEntries() async {
    final rows = await db.query('memory_entries');
    return rows.map(_mapMemoryEntry).toList();
  }

  Future<void> deleteMemoryEntry(String id) async {
    await db.delete(
      'memory_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllMemoryEntries() async {
    await db.delete('memory_entries');
  }

  Future<void> upsertSetting(String key, Map<String, Object?> value) async {
    await db.insert(
      'settings',
      {
        'key': key,
        'value_json': jsonEncode(value),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> fetchSetting(String key) async {
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return jsonDecode(rows.first['value_json']! as String)
        as Map<String, Object?>;
  }

  Future<void> upsertContact(ContactRecord contact) async {
    await db.insert(
      'contacts',
      {
        'id': contact.id,
        'display_name': contact.displayName,
        'phone_number': contact.phoneNumber,
        'email': contact.email,
        'avatar_color': contact.avatarColor,
        'is_favorite': contact.isFavorite ? 1 : 0,
        'notes': contact.notes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ContactRecord>> fetchContacts() async {
    final rows = await db.query(
      'contacts',
      orderBy: 'display_name COLLATE NOCASE ASC',
    );
    return rows.map(_mapContact).toList();
  }

  Future<ContactRecord?> fetchContact(String id) async {
    final rows = await db.query(
      'contacts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapContact(rows.first);
  }

  Future<void> deleteContact(String id) async {
    await db.delete(
      'contacts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> upsertThread(ThreadRecord thread) async {
    final payload = {
      'id': thread.id,
      'title': thread.title,
      'participant_ids_json': jsonEncode(thread.participantIds),
      'created_at': thread.createdAt.toIso8601String(),
      'updated_at': thread.updatedAt.toIso8601String(),
      'last_message_preview': thread.lastMessagePreview,
      'unread_count': thread.unreadCount,
      'is_pinned': thread.isPinned ? 1 : 0,
      'is_muted': thread.isMuted ? 1 : 0,
    };
    // Avoid ConflictAlgorithm.replace: SQLite REPLACE deletes the row first
    // and cascades away thread_messages via the foreign key.
    final updated = await db.update(
      'message_threads',
      payload,
      where: 'id = ?',
      whereArgs: [thread.id],
    );
    if (updated == 0) {
      await db.insert('message_threads', payload);
    }
  }

  Future<List<ThreadRecord>> fetchThreads() async {
    final rows = await db.query(
      'message_threads',
      orderBy: 'is_pinned DESC, updated_at DESC',
    );
    return rows.map(_mapThread).toList();
  }

  Future<ThreadRecord?> fetchThread(String id) async {
    final rows = await db.query(
      'message_threads',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapThread(rows.first);
  }

  Future<void> insertThreadMessage(ThreadMessageRecord message) async {
    await db.insert(
      'thread_messages',
      {
        'id': message.id,
        'thread_id': message.threadId,
        'sender_contact_id': message.senderContactId,
        'body': message.body,
        'sent_at': message.sentAt.toIso8601String(),
        'is_from_me': message.isFromMe ? 1 : 0,
        'status': message.status.name,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ThreadMessageRecord>> fetchThreadMessages(String threadId) async {
    final rows = await db.query(
      'thread_messages',
      where: 'thread_id = ?',
      whereArgs: [threadId],
      orderBy: 'sent_at ASC',
    );
    return rows.map(_mapThreadMessage).toList();
  }

  Future<void> insertCall(CallRecordRow call) async {
    await db.insert(
      'call_logs',
      {
        'id': call.id,
        'contact_id': call.contactId,
        'direction': call.direction.name,
        'kind': call.kind.name,
        'started_at': call.startedAt.toIso8601String(),
        'duration_seconds': call.durationSeconds,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCallDuration({
    required String callId,
    required int durationSeconds,
  }) async {
    await db.update(
      'call_logs',
      {'duration_seconds': durationSeconds},
      where: 'id = ?',
      whereArgs: [callId],
    );
  }

  Future<List<CallRecordRow>> fetchCalls() async {
    final rows = await db.query(
      'call_logs',
      orderBy: 'started_at DESC',
    );
    return rows.map(_mapCall).toList();
  }

  Future<Database> _openDatabase() async {
    return openDatabase(
      databasePath,
      version: 2,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        await _createV1Tables(database);
        await _createCommunicationTables(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createCommunicationTables(database);
        }
      },
    );
  }

  Future<void> _createV1Tables(Database database) async {
    await database.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_pinned INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        metadata_json TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE memory_entries (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        entry_key TEXT NOT NULL,
        entry_value TEXT NOT NULL,
        source_conversation_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value_json TEXT NOT NULL
      )
    ''');
    await database.execute(
      'CREATE INDEX idx_messages_conversation ON messages(conversation_id)',
    );
  }

  Future<void> _createCommunicationTables(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS contacts (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        phone_number TEXT NOT NULL,
        email TEXT,
        avatar_color INTEGER NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        notes TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS message_threads (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        participant_ids_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_message_preview TEXT NOT NULL DEFAULT '',
        unread_count INTEGER NOT NULL DEFAULT 0,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_muted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS thread_messages (
        id TEXT PRIMARY KEY,
        thread_id TEXT NOT NULL,
        sender_contact_id TEXT NOT NULL,
        body TEXT NOT NULL,
        sent_at TEXT NOT NULL,
        is_from_me INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        FOREIGN KEY (thread_id) REFERENCES message_threads(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS call_logs (
        id TEXT PRIMARY KEY,
        contact_id TEXT NOT NULL,
        direction TEXT NOT NULL,
        kind TEXT NOT NULL,
        started_at TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_thread_messages_thread ON thread_messages(thread_id)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_call_logs_started ON call_logs(started_at)',
    );
  }

  ConversationRecord _mapConversation(Map<String, Object?> row) {
    return ConversationRecord(
      id: row['id']! as String,
      title: row['title']! as String,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
      isPinned: (row['is_pinned']! as int) == 1,
    );
  }

  MessageRecord _mapMessage(Map<String, Object?> row) {
    return MessageRecord(
      id: row['id']! as String,
      conversationId: row['conversation_id']! as String,
      role: MessageRole.values.byName(row['role']! as String),
      content: row['content']! as String,
      createdAt: DateTime.parse(row['created_at']! as String),
      metadata:
          jsonDecode(row['metadata_json']! as String) as Map<String, Object?>,
    );
  }

  MemoryEntryRecord _mapMemoryEntry(Map<String, Object?> row) {
    return MemoryEntryRecord(
      id: row['id']! as String,
      category: MemoryCategory.values.byName(row['category']! as String),
      key: row['entry_key']! as String,
      value: row['entry_value']! as String,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
      sourceConversationId: row['source_conversation_id'] as String?,
    );
  }

  ContactRecord _mapContact(Map<String, Object?> row) {
    return ContactRecord(
      id: row['id']! as String,
      displayName: row['display_name']! as String,
      phoneNumber: row['phone_number']! as String,
      email: row['email'] as String?,
      avatarColor: row['avatar_color']! as int,
      isFavorite: (row['is_favorite']! as int) == 1,
      notes: row['notes'] as String?,
    );
  }

  ThreadRecord _mapThread(Map<String, Object?> row) {
    final participants = (jsonDecode(row['participant_ids_json']! as String)
            as List<dynamic>)
        .map((value) => value as String)
        .toList();
    return ThreadRecord(
      id: row['id']! as String,
      title: row['title']! as String,
      participantIds: participants,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
      lastMessagePreview: row['last_message_preview']! as String,
      unreadCount: row['unread_count']! as int,
      isPinned: (row['is_pinned']! as int) == 1,
      isMuted: (row['is_muted']! as int) == 1,
    );
  }

  ThreadMessageRecord _mapThreadMessage(Map<String, Object?> row) {
    return ThreadMessageRecord(
      id: row['id']! as String,
      threadId: row['thread_id']! as String,
      senderContactId: row['sender_contact_id']! as String,
      body: row['body']! as String,
      sentAt: DateTime.parse(row['sent_at']! as String),
      isFromMe: (row['is_from_me']! as int) == 1,
      status: ThreadMessageStatus.values.byName(row['status']! as String),
    );
  }

  CallRecordRow _mapCall(Map<String, Object?> row) {
    return CallRecordRow(
      id: row['id']! as String,
      contactId: row['contact_id']! as String,
      direction: CallDirection.values.byName(row['direction']! as String),
      kind: CallKind.values.byName(row['kind']! as String),
      startedAt: DateTime.parse(row['started_at']! as String),
      durationSeconds: row['duration_seconds']! as int,
    );
  }
}
