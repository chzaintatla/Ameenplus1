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

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['id'] ?? data['uid'] ?? '',
      displayName: data['display_name'] ?? data['displayName'],
      email: data['email'],
      phoneNumber: data['phone_number'] ?? data['phoneNumber'],
      profilePicture: data['profile_picture'] ?? data['profilePicture'] ?? data['photo_url'],
      xp: data['xp'] ?? 0,
      level: data['level'] ?? 1,
      badges: List<String>.from(data['badges'] ?? []),
      friends: List<String>.from((data['friends'] ?? []) as List),
      region: data['region'],
      interests: List<String>.from(data['interests'] ?? []),
      createdAt: data['created_at'] != null
          ? (data['created_at'] is String ? DateTime.parse(data['created_at']) : data['created_at'] as DateTime)
          : (data['createdAt'] is String ? DateTime.parse(data['createdAt']) : DateTime.now()),
      lastActive: data['last_active'] != null
          ? (data['last_active'] is String ? DateTime.parse(data['last_active']) : data['last_active'] as DateTime?)
          : (data['lastActive'] != null 
              ? (data['lastActive'] is String ? DateTime.parse(data['lastActive']) : data['lastActive'] as DateTime?)
              : null),
      isOnline: data['is_online'] ?? data['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': uid,
      'display_name': displayName,
      'email': email,
      'phone_number': phoneNumber,
      'profile_picture': profilePicture,
      'xp': xp,
      'level': level,
      'badges': badges,
      'friends': friends,
      'region': region,
      'interests': interests,
      'created_at': createdAt.toIso8601String(),
      'last_active': lastActive?.toIso8601String(),
      'is_online': isOnline,
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
