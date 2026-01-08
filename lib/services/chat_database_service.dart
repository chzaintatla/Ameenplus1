import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class ChatMessage {
  final int? id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? mediaPath;
  final String? mediaType;

  ChatMessage({
    this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.mediaPath,
    this.mediaType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
      'mediaPath': mediaPath,
      'mediaType': mediaType,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int?,
      text: map['text'] as String,
      isUser: (map['isUser'] as int) == 1,
      timestamp: DateTime.parse(map['timestamp'] as String),
      mediaPath: map['mediaPath'] as String?,
      mediaType: map['mediaType'] as String?,
    );
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, text: $text, isUser: $isUser, timestamp: $timestamp, mediaPath: $mediaPath, mediaType: $mediaType)';
  }
}

class ChatDatabaseService {
  static final ChatDatabaseService _instance = ChatDatabaseService._internal();
  factory ChatDatabaseService() => _instance;
  ChatDatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'chat_messages_v2.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE chat_messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            text TEXT NOT NULL,
            isUser INTEGER NOT NULL,
            timestamp TEXT NOT NULL,
            mediaPath TEXT,
            mediaType TEXT
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_timestamp ON chat_messages(timestamp)
        ''');
      },
    );
  }

  Future<int> insertMessage(ChatMessage message) async {
    final db = await database;
    return await db.insert('chat_messages', message.toMap());
  }

  Future<List<ChatMessage>> getAllMessages({int? limit}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = limit != null
        ? await db.query(
            'chat_messages',
            orderBy: 'timestamp DESC',
            limit: limit,
          )
        : await db.query(
            'chat_messages',
            orderBy: 'timestamp ASC',
          );

    return List.generate(maps.length, (i) => ChatMessage.fromMap(maps[i]));
  }

  Future<List<ChatMessage>> getRecentMessages({int limit = 50}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_messages',
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    final messages = List.generate(
      maps.length,
      (i) => ChatMessage.fromMap(maps[i]),
    );

    return messages.reversed.toList();
  }

  Future<int> deleteMessage(int id) async {
    final db = await database;
    return await db.delete(
      'chat_messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllMessages() async {
    final db = await database;
    return await db.delete('chat_messages');
  }

  Future<int> getMessageCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM chat_messages');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
