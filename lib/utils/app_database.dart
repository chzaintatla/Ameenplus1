import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'app_constants.dart';

/// Local database for offline storage and caching
class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  static Database? _database;
  
  AppDatabase._internal();
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    final Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, AppConstants.localDatabaseName);
    
    return await openDatabase(
      path,
      version: AppConstants.localDatabaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
  
  // ============ Create Tables ============
  
  Future<void> _onCreate(Database db, int version) async {
    // Habits Table
    await db.execute('''
      CREATE TABLE habits (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        habitType TEXT NOT NULL,
        habitName TEXT,
        targetValue INTEGER DEFAULT 1,
        currentValue INTEGER DEFAULT 0,
        lastCompleted TEXT,
        streakDays INTEGER DEFAULT 0,
        totalCompletions INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL,
        syncStatus INTEGER DEFAULT 0,
        lastSyncAt TEXT,
        durationDays INTEGER,
        endDate TEXT,
        autoRemoveAfterCompletion INTEGER DEFAULT 0
      )
    ''');
    
    // Habit Completions Table (for history)
    await db.execute('''
      CREATE TABLE habit_completions (
        id TEXT PRIMARY KEY,
        habitId TEXT NOT NULL,
        completedAt TEXT NOT NULL,
        value INTEGER DEFAULT 1,
        notes TEXT,
        syncStatus INTEGER DEFAULT 0,
        FOREIGN KEY (habitId) REFERENCES habits(id) ON DELETE CASCADE
      )
    ''');
    
    // Mood History Table
    await db.execute('''
      CREATE TABLE mood_history (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        mood TEXT NOT NULL,
        intensity INTEGER DEFAULT 5,
        notes TEXT,
        timestamp TEXT NOT NULL,
        syncStatus INTEGER DEFAULT 0
      )
    ''');
    
    // Mood Suggestions Cache
    await db.execute('''
      CREATE TABLE mood_suggestions (
        id TEXT PRIMARY KEY,
        mood TEXT NOT NULL,
        contentType TEXT NOT NULL,
        content TEXT NOT NULL,
        translation TEXT,
        reference TEXT,
        cachedAt TEXT NOT NULL
      )
    ''');
    
    // Cached Deeds Table
    await db.execute('''
      CREATE TABLE cached_deeds (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        userName TEXT,
        userPhotoUrl TEXT,
        deedType TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT,
        imageUrl TEXT,
        likesCount INTEGER DEFAULT 0,
        commentsCount INTEGER DEFAULT 0,
        sharesCount INTEGER DEFAULT 0,
        isLiked INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL,
        cachedAt TEXT NOT NULL
      )
    ''');
    
    // Cached Comments Table
    await db.execute('''
      CREATE TABLE cached_comments (
        id TEXT PRIMARY KEY,
        deedId TEXT NOT NULL,
        userId TEXT NOT NULL,
        userName TEXT,
        userPhotoUrl TEXT,
        content TEXT NOT NULL,
        likesCount INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL,
        cachedAt TEXT NOT NULL,
        FOREIGN KEY (deedId) REFERENCES cached_deeds(id) ON DELETE CASCADE
      )
    ''');
    
    // User Settings Table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    
    // Prayer Times Cache
    await db.execute('''
      CREATE TABLE prayer_times (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        fajr TEXT NOT NULL,
        dhuhr TEXT NOT NULL,
        asr TEXT NOT NULL,
        maghrib TEXT NOT NULL,
        isha TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        cachedAt TEXT NOT NULL
      )
    ''');
    
    // Notifications Queue (for offline notifications)
    await db.execute('''
      CREATE TABLE notifications_queue (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        scheduledAt TEXT NOT NULL,
        delivered INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');
    
    // Islamic Content Cache (Ayahs, Hadiths, Duas)
    await db.execute('''
      CREATE TABLE islamic_content (
        id TEXT PRIMARY KEY,
        contentType TEXT NOT NULL,
        arabicText TEXT NOT NULL,
        translation TEXT,
        transliteration TEXT,
        reference TEXT,
        category TEXT,
        tags TEXT,
        cachedAt TEXT NOT NULL
      )
    ''');
    
    // User XP and Achievements (for offline tracking)
    await db.execute('''
      CREATE TABLE user_xp (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        xpPoints INTEGER DEFAULT 0,
        level INTEGER DEFAULT 1,
        badges TEXT,
        lastXpEarned TEXT,
        syncStatus INTEGER DEFAULT 0
      )
    ''');
    
    // Friends Cache
    await db.execute('''
      CREATE TABLE cached_friends (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        userName TEXT NOT NULL,
        userPhotoUrl TEXT,
        status TEXT NOT NULL,
        xpPoints INTEGER DEFAULT 0,
        level INTEGER DEFAULT 1,
        cachedAt TEXT NOT NULL
      )
    ''');
    
    // Communities Cache
    await db.execute('''
      CREATE TABLE cached_communities (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        imageUrl TEXT,
        membersCount INTEGER DEFAULT 0,
        postsCount INTEGER DEFAULT 0,
        isJoined INTEGER DEFAULT 0,
        cachedAt TEXT NOT NULL
      )
    ''');
    
    // Create Indices for Performance
    await _createIndices(db);
  }
  
  Future<void> _createIndices(Database db) async {
    // Habits indices
    await db.execute('CREATE INDEX idx_habits_userId ON habits(userId)');
    await db.execute('CREATE INDEX idx_habits_syncStatus ON habits(syncStatus)');
    
    // Mood history indices
    await db.execute('CREATE INDEX idx_mood_userId ON mood_history(userId)');
    await db.execute('CREATE INDEX idx_mood_timestamp ON mood_history(timestamp)');
    
    // Cached deeds indices
    await db.execute('CREATE INDEX idx_deeds_userId ON cached_deeds(userId)');
    await db.execute('CREATE INDEX idx_deeds_createdAt ON cached_deeds(createdAt)');
    
    // Prayer times indices
    await db.execute('CREATE INDEX idx_prayer_date ON prayer_times(date)');
    
    // Friends indices
    await db.execute('CREATE INDEX idx_friends_userId ON cached_friends(userId)');
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE habits ADD COLUMN durationDays INTEGER');
      } catch (e) {
      }
      try {
        await db.execute('ALTER TABLE habits ADD COLUMN endDate TEXT');
      } catch (e) {
      }
      try {
        await db.execute('ALTER TABLE habits ADD COLUMN autoRemoveAfterCompletion INTEGER DEFAULT 0');
      } catch (e) {
      }
    }
  }
  
  // ============ Habits Methods ============
  
  Future<int> insertHabit(Map<String, dynamic> habit) async {
    final db = await database;
    return await db.insert('habits', habit, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  Future<List<Map<String, dynamic>>> getHabits(String userId) async {
    final db = await database;
    return await db.query(
      'habits',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );
  }
  
  Future<int> updateHabit(String id, Map<String, dynamic> habit) async {
    final db = await database;
    return await db.update(
      'habits',
      habit,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<int> deleteHabit(String id) async {
    final db = await database;
    return await db.delete(
      'habits',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<int> insertHabitCompletion(Map<String, dynamic> completion) async {
    final db = await database;
    return await db.insert('habit_completions', completion);
  }
  
  Future<List<Map<String, dynamic>>> getHabitCompletions(String habitId, {int? limit}) async {
    final db = await database;
    return await db.query(
      'habit_completions',
      where: 'habitId = ?',
      whereArgs: [habitId],
      orderBy: 'completedAt DESC',
      limit: limit,
    );
  }
  
  // ============ Mood Methods ============
  
  Future<int> insertMood(Map<String, dynamic> mood) async {
    final db = await database;
    return await db.insert('mood_history', mood);
  }
  
  Future<List<Map<String, dynamic>>> getMoodHistory(String userId, {int? limit}) async {
    final db = await database;
    return await db.query(
      'mood_history',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }
  
  Future<int> cacheMoodSuggestion(Map<String, dynamic> suggestion) async {
    final db = await database;
    return await db.insert('mood_suggestions', suggestion, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  Future<List<Map<String, dynamic>>> getMoodSuggestions(String mood) async {
    final db = await database;
    return await db.query(
      'mood_suggestions',
      where: 'mood = ?',
      whereArgs: [mood],
    );
  }
  
  // ============ Deeds Cache Methods ============
  
  Future<int> cacheDeed(Map<String, dynamic> deed) async {
    final db = await database;
    return await db.insert('cached_deeds', deed, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  Future<List<Map<String, dynamic>>> getCachedDeeds({int? limit}) async {
    final db = await database;
    return await db.query(
      'cached_deeds',
      orderBy: 'createdAt DESC',
      limit: limit ?? 50,
    );
  }
  
  Future<int> updateDeedLikeStatus(String deedId, bool isLiked, int likesCount) async {
    final db = await database;
    return await db.update(
      'cached_deeds',
      {
        'isLiked': isLiked ? 1 : 0,
        'likesCount': likesCount,
      },
      where: 'id = ?',
      whereArgs: [deedId],
    );
  }
  
  // ============ Settings Methods ============
  
  Future<int> setSetting(String key, String value) async {
    final db = await database;
    return await db.insert(
      'settings',
      {
        'key': key,
        'value': value,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    
    if (results.isNotEmpty) {
      return results.first['value'] as String;
    }
    return null;
  }
  
  // ============ Prayer Times Methods ============
  
  Future<int> cachePrayerTimes(Map<String, dynamic> prayerTimes) async {
    final db = await database;
    return await db.insert('prayer_times', prayerTimes, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  Future<Map<String, dynamic>?> getPrayerTimes(String date) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'prayer_times',
      where: 'date = ?',
      whereArgs: [date],
    );
    
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }
  
  // ============ Islamic Content Methods ============
  
  Future<int> cacheIslamicContent(Map<String, dynamic> content) async {
    final db = await database;
    return await db.insert('islamic_content', content, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  Future<List<Map<String, dynamic>>> getIslamicContent({
    String? contentType,
    String? category,
    int? limit,
  }) async {
    final db = await database;
    
    String? whereClause;
    List<dynamic>? whereArgs;
    
    if (contentType != null) {
      whereClause = 'contentType = ?';
      whereArgs = [contentType];
    }
    
    return await db.query(
      'islamic_content',
      where: whereClause,
      whereArgs: whereArgs,
      limit: limit,
    );
  }
  
  // ============ XP and Achievements Methods ============
  
  Future<int> updateUserXP(String userId, int xpPoints, int level, String badges) async {
    final db = await database;
    return await db.insert(
      'user_xp',
      {
        'id': userId,
        'userId': userId,
        'xpPoints': xpPoints,
        'level': level,
        'badges': badges,
        'lastXpEarned': DateTime.now().toIso8601String(),
        'syncStatus': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<Map<String, dynamic>?> getUserXP(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'user_xp',
      where: 'userId = ?',
      whereArgs: [userId],
    );
    
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }
  
  // ============ Utility Methods ============
  
  /// Get all items that need to be synced
  Future<List<Map<String, dynamic>>> getUnsyncedItems(String tableName) async {
    final db = await database;
    return await db.query(
      tableName,
      where: 'syncStatus = ?',
      whereArgs: [0],
    );
  }
  
  /// Mark items as synced
  Future<int> markAsSynced(String tableName, String id) async {
    final db = await database;
    return await db.update(
      tableName,
      {
        'syncStatus': 1,
        'lastSyncAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  /// Clear all cached data
  Future<void> clearAllCache() async {
    final db = await database;
    await db.delete('cached_deeds');
    await db.delete('cached_comments');
    await db.delete('cached_friends');
    await db.delete('cached_communities');
  }
  
  /// Clear old cache (older than X days)
  Future<void> clearOldCache({int daysOld = 7}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld)).toIso8601String();
    
    await db.delete('cached_deeds', where: 'cachedAt < ?', whereArgs: [cutoffDate]);
    await db.delete('cached_comments', where: 'cachedAt < ?', whereArgs: [cutoffDate]);
  }
  
  /// Get database size
  Future<int> getDatabaseSize() async {
    final Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, AppConstants.localDatabaseName);
    final File file = File(path);
    
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }
  
  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}

