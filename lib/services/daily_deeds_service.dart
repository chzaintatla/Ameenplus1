import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import 'groq_api_service.dart';

class DailyDeedsService {
  final GroqApiService _groqService = GroqApiService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _prefKeyLastDeedDate = 'last_daily_deed_date';
  static const String _prefKeyLastDeed = 'last_daily_deed';

  Future<DailyDeed> getTodaysDeed(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    
    final lastDate = prefs.getString(_prefKeyLastDeedDate);
    
    if (lastDate == todayKey) {
      final cachedDeed = prefs.getString(_prefKeyLastDeed);
      if (cachedDeed != null) {
        return DailyDeed.fromJson(cachedDeed);
      }
    }

    final deed = await _generateDeed(profile);
    
    await prefs.setString(_prefKeyLastDeedDate, todayKey);
    await prefs.setString(_prefKeyLastDeed, deed.toJson());

    await _firestore
        .collection('daily_deeds')
        .doc(profile.uid)
        .collection('deeds')
        .add({
      'date': todayKey,
      'deed': deed.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return deed;
  }

  Future<DailyDeed> _generateDeed(UserProfile profile) async {
    final profession = profile.profession ?? 'General';
    final interests = profile.interests.isNotEmpty 
        ? profile.interests 
        : ['Islamic Learning', 'Spirituality'];
    
    final activityLevel = profile.points < 100 
        ? 1 
        : profile.points < 500 
            ? 2 
            : profile.points < 1000 
                ? 3 
                : 4;

    final aiResponse = await _groqService.generateDailyDeed(
      profession: profession,
      interests: interests,
      activityLevel: activityLevel,
    );

    return _parseDeedResponse(aiResponse, profession, interests);
  }

  DailyDeed _parseDeedResponse(String response, String profession, List<String> interests) {
    final lines = response.split('\n');
    String name = 'Perform a Good Deed';
    String description = 'Do something beneficial for yourself and others today.';
    String connection = 'This deed aligns with your interests and profession.';
    String benefit = 'You will earn rewards and improve your spiritual well-being.';

    for (final line in lines) {
      if (line.contains('Deed Name') || line.contains('Name:')) {
        name = line.split(':').last.trim();
      } else if (line.contains('Description') || line.contains('description')) {
        description = line.split(':').last.trim();
      } else if (line.contains('Connection') || line.contains('connection')) {
        connection = line.split(':').last.trim();
      } else if (line.contains('Benefit') || line.contains('benefit')) {
        benefit = line.split(':').last.trim();
      }
    }

    if (response.contains(' - ')) {
      final parts = response.split(' - ');
      if (parts.length >= 4) {
        name = parts[0].trim();
        description = parts[1].trim();
        connection = parts[2].trim();
        benefit = parts[3].trim();
      }
    }

    return DailyDeed(
      name: name,
      description: description,
      connection: connection,
      benefit: benefit,
      profession: profession,
      interests: interests,
    );
  }

  Future<List<DailyDeed>> getDeedHistory(String userId, {int limit = 30}) async {
    final snapshot = await _firestore
        .collection('daily_deeds')
        .doc(userId)
        .collection('deeds')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => DailyDeed.fromMap(doc.data()['deed'] as Map<String, dynamic>))
        .toList();
  }
}

class DailyDeed {
  final String name;
  final String description;
  final String connection;
  final String benefit;
  final String profession;
  final List<String> interests;

  DailyDeed({
    required this.name,
    required this.description,
    required this.connection,
    required this.benefit,
    required this.profession,
    required this.interests,
  });

  factory DailyDeed.fromMap(Map<String, dynamic> map) {
    return DailyDeed(
      name: map['name'] as String,
      description: map['description'] as String,
      connection: map['connection'] as String,
      benefit: map['benefit'] as String,
      profession: map['profession'] as String,
      interests: List<String>.from(map['interests'] as List),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'connection': connection,
      'benefit': benefit,
      'profession': profession,
      'interests': interests,
    };
  }

  factory DailyDeed.fromJson(String json) {
    // Simple JSON parsing - in production use proper JSON
    return DailyDeed(
      name: 'Daily Deed',
      description: json,
      connection: '',
      benefit: '',
      profession: '',
      interests: [],
    );
  }

  String toJson() {
    return '$name|$description|$connection|$benefit|$profession|${interests.join(",")}';
  }
}

