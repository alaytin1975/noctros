import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/constants/noctros_constants.dart';
import '../../../domain/entities/noctros_enums.dart';

class ConversationRecord {
  ConversationRecord({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.isPinned,
    required this.isFavorite,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final bool isFavorite;
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

class NoctrosDatabase {
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
    bool isFavorite = false,
  }) async {
    await db.insert(
      'conversations',
      {
        'id': id,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_pinned': isPinned ? 1 : 0,
        'is_favorite': isFavorite ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ConversationRecord>> fetchConversations({
    String? query,
    bool favoritesOnly = false,
  }) async {
    final where = <String>[];
    final args = <Object?>[];

    if (favoritesOnly) {
      where.add('is_favorite = 1');
    }
    if (query != null && query.trim().isNotEmpty) {
      where.add('(title LIKE ? OR id IN (SELECT conversation_id FROM messages WHERE content LIKE ?))');
      final like = '%${query.trim()}%';
      args.addAll([like, like]);
    }

    final rows = await db.query(
      'conversations',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'is_pinned DESC, updated_at DESC',
    );
    return rows.map(_mapConversation).toList();
  }

  Future<void> deleteConversation(String id) async {
    await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
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
    await db.update(
      'conversations',
      {'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<void> updateMessage({
    required String id,
    required String content,
    Map<String, Object?> metadata = const {},
  }) async {
    await db.update(
      'messages',
      {
        'content': content,
        'metadata_json': jsonEncode(metadata),
      },
      where: 'id = ?',
      whereArgs: [id],
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
    await db.delete('memory_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllMemoryEntries() async {
    await db.delete('memory_entries');
  }

  Future<void> upsertSetting(String key, Map<String, Object?> value) async {
    await db.insert(
      'settings',
      {'key': key, 'value_json': jsonEncode(value)},
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

  Future<Database> _openDatabase() async {
    final directory = await getApplicationSupportDirectory();
    final path = p.join(directory.path, NoctrosConstants.databaseName);
    return openDatabase(
      path,
      version: 3,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        await _createV1(database);
        await _upgradeToV2(database);
        await _upgradeToV3(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _upgradeToV2(database);
        }
        if (oldVersion < 3) {
          await _upgradeToV3(database);
        }
      },
    );
  }

  Future<void> _createV1(Database database) async {
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

  Future<void> _upgradeToV2(Database database) async {
    final columns = await database.rawQuery('PRAGMA table_info(conversations)');
    final names = columns.map((row) => row['name'] as String).toSet();
    if (!names.contains('is_favorite')) {
      await database.execute(
        'ALTER TABLE conversations ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
      );
    }
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_messages_content ON messages(content)',
    );
  }

  Future<void> _upgradeToV3(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS action_logs (
        id TEXT PRIMARY KEY,
        action_type TEXT NOT NULL,
        summary TEXT NOT NULL,
        success INTEGER NOT NULL DEFAULT 1,
        raw_command TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_action_logs_created ON action_logs(created_at)',
    );
  }

  Future<void> insertActionLog({
    required String id,
    required String actionType,
    required String summary,
    required bool success,
    required DateTime createdAt,
    String? rawCommand,
  }) async {
    await db.insert(
      'action_logs',
      {
        'id': id,
        'action_type': actionType,
        'summary': summary,
        'success': success ? 1 : 0,
        'raw_command': rawCommand,
        'created_at': createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> fetchActionLogs({int limit = 20}) async {
    return db.query(
      'action_logs',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<void> clearActionLogs() async {
    await db.delete('action_logs');
  }

  Future<void> clearConversationsAndMessages() async {
    await db.delete('messages');
    await db.delete('conversations');
  }

  ConversationRecord _mapConversation(Map<String, Object?> row) {
    return ConversationRecord(
      id: row['id']! as String,
      title: row['title']! as String,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
      isPinned: (row['is_pinned']! as int) == 1,
      isFavorite: ((row['is_favorite'] as int?) ?? 0) == 1,
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
}
