import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? displayName;
  final String? email;
  final String? phoneNumber;
  final String? profilePicture;
  final int xp;
  final int level;
  final List<String> badges;
  final List<String> friends;
  final String? region;
  final List<String> interests;
  final DateTime createdAt;
  final DateTime? lastActive;
  final bool isOnline;

  UserModel({
    required this.uid,
    this.displayName,
    this.email,
    this.phoneNumber,
    this.profilePicture,
    this.xp = 0,
    this.level = 1,
    this.badges = const [],
    this.friends = const [],
    this.region,
    this.interests = const [],
    required this.createdAt,
    this.lastActive,
    this.isOnline = false,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UserModel(
      uid: doc.id,
      displayName: data['displayName'],
      email: data['email'],
      phoneNumber: data['phoneNumber'],
      profilePicture: data['profilePicture'],
      xp: data['xp'] ?? 0,
      level: data['level'] ?? 1,
      badges: List<String>.from(data['badges'] ?? []),
      friends: List<String>.from(data['friends'] ?? []),
      region: data['region'],
      interests: List<String>.from(data['interests'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastActive: data['lastActive'] != null
          ? (data['lastActive'] as Timestamp).toDate()
          : null,
      isOnline: data['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'phoneNumber': phoneNumber,
      'profilePicture': profilePicture,
      'xp': xp,
      'level': level,
      'badges': badges,
      'friends': friends,
      'region': region,
      'interests': interests,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      'isOnline': isOnline,
    };
  }

  UserModel copyWith({
    String? displayName,
    String? email,
    String? phoneNumber,
    String? profilePicture,
    int? xp,
    int? level,
    List<String>? badges,
    List<String>? friends,
    String? region,
    List<String>? interests,
    DateTime? lastActive,
    bool? isOnline,
  }) {
    return UserModel(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePicture: profilePicture ?? this.profilePicture,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      badges: badges ?? this.badges,
      friends: friends ?? this.friends,
      region: region ?? this.region,
      interests: interests ?? this.interests,
      createdAt: createdAt,
      lastActive: lastActive ?? this.lastActive,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  static int calculateLevel(int xp) {
    if (xp < 100) return 1;
    return (xp / 100).floor() + 1;
  }

  int get xpForNextLevel {
    final nextLevel = level + 1;
    return (nextLevel * nextLevel * 100) - xp;
  }

  double get levelProgress {
    final currentLevelXP = level * level * 100;
    final nextLevelXP = (level + 1) * (level + 1) * 100;
    final xpInCurrentLevel = xp - currentLevelXP;
    final xpNeededForLevel = nextLevelXP - currentLevelXP;

    return (xpInCurrentLevel / xpNeededForLevel).clamp(0.0, 1.0);
  }
}
