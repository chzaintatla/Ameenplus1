class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    required this.points,
    required this.isProfilePublic,
    this.interests = const [],
    this.email,
    this.phoneNumber,
    this.bio,
    this.age,
    this.gender,
    this.isEmailPublic = false,
    this.isPhonePublic = false,
    this.profession,
    this.badges = const [],
    this.rank,
    this.negativePoints = 0,
    this.accountBlockedUntil,
    this.moderationLogs = const [],
  });

  final String uid;
  final String displayName;
  final String? photoUrl;
  final int points;
  final bool isProfilePublic;
  final List<String> interests;
  final String? email;
  final String? phoneNumber;
  final String? bio;
  final int? age;
  final String? gender; // 'male', 'female', 'prefer_not_to_say'
  final bool isEmailPublic;
  final bool isPhonePublic;
  final String? profession;
  final List<String> badges;
  final String? rank;
  final int negativePoints;
  final DateTime? accountBlockedUntil;
  final List<ModerationLog> moderationLogs;

  factory UserProfile.fromMap(String uid, Map<String, Object?> map) {
    return UserProfile(
      uid: uid,
      displayName: (map['display_name'] ?? map['displayName'] ?? 'User') as String,
      photoUrl: (map['profile_picture'] ?? map['photo_url'] ?? map['photoUrl']) as String?,
      points: (map['points'] as num?)?.toInt() ?? 0,
      isProfilePublic: (map['is_profile_public'] ?? map['isProfilePublic']) as bool? ?? true,
      interests: map['interests'] != null 
          ? List<String>.from(map['interests'] as List)
          : <String>[],
      email: map['email'] as String?,
      phoneNumber: (map['phone_number'] ?? map['phoneNumber']) as String?,
      bio: map['bio'] as String?,
      age: map['age'] != null ? (map['age'] as num).toInt() : null,
      gender: map['gender'] as String?,
      isEmailPublic: (map['is_email_public'] ?? map['isEmailPublic']) as bool? ?? false,
      isPhonePublic: (map['is_phone_public'] ?? map['isPhonePublic']) as bool? ?? false,
      profession: map['profession'] as String?,
      badges: map['badges'] != null 
          ? List<String>.from(map['badges'] as List)
          : <String>[],
      rank: map['rank'] as String?,
      negativePoints: ((map['negative_points'] ?? map['negativePoints']) as num?)?.toInt() ?? 0,
      accountBlockedUntil: (map['account_blocked_until'] ?? map['accountBlockedUntil']) != null
          ? DateTime.parse((map['account_blocked_until'] ?? map['accountBlockedUntil']) as String)
          : null,
      moderationLogs: (map['moderation_logs'] ?? map['moderationLogs']) != null
          ? ((map['moderation_logs'] ?? map['moderationLogs']) as List)
              .map((e) => ModerationLog.fromMap(e as Map<String, dynamic>))
              .toList()
          : <ModerationLog>[],
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'display_name': displayName,
      'photo_url': photoUrl,
      'points': points,
      'is_profile_public': isProfilePublic,
      'interests': interests,
      'email': email,
      'phone_number': phoneNumber,
      'bio': bio,
      'age': age,
      'gender': gender,
      'is_email_public': isEmailPublic,
      'is_phone_public': isPhonePublic,
      'profession': profession,
      'badges': badges,
      'rank': rank,
      'negative_points': negativePoints,
      'account_blocked_until': accountBlockedUntil?.toIso8601String(),
      'moderation_logs': moderationLogs.map((e) => e.toMap()).toList(),
    };
  }
  
  UserProfile copyWith({
    String? displayName,
    String? photoUrl,
    int? points,
    bool? isProfilePublic,
    List<String>? interests,
    String? email,
    String? phoneNumber,
    String? bio,
    int? age,
    String? gender,
    bool? isEmailPublic,
    bool? isPhonePublic,
    String? profession,
    List<String>? badges,
    String? rank,
    int? negativePoints,
    DateTime? accountBlockedUntil,
    List<ModerationLog>? moderationLogs,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      points: points ?? this.points,
      isProfilePublic: isProfilePublic ?? this.isProfilePublic,
      interests: interests ?? this.interests,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bio: bio ?? this.bio,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      isEmailPublic: isEmailPublic ?? this.isEmailPublic,
      isPhonePublic: isPhonePublic ?? this.isPhonePublic,
      profession: profession ?? this.profession,
      badges: badges ?? this.badges,
      rank: rank ?? this.rank,
      negativePoints: negativePoints ?? this.negativePoints,
      accountBlockedUntil: accountBlockedUntil ?? this.accountBlockedUntil,
      moderationLogs: moderationLogs ?? this.moderationLogs,
    );
  }
}

class ModerationLog {
  final DateTime timestamp;
  final String reason;
  final int pointsAdded;
  final String? postId;

  ModerationLog({
    required this.timestamp,
    required this.reason,
    required this.pointsAdded,
    this.postId,
  });

  factory ModerationLog.fromMap(Map<String, dynamic> map) {
    return ModerationLog(
      timestamp: DateTime.parse(map['timestamp'] as String),
      reason: map['reason'] as String,
      pointsAdded: (map['points_added'] ?? map['pointsAdded'] as num).toInt(),
      postId: (map['post_id'] ?? map['postId']) as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'reason': reason,
      'points_added': pointsAdded,
      'post_id': postId,
    };
  }
}
