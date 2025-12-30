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

  factory UserProfile.fromMap(String uid, Map<String, Object?> map) {
    return UserProfile(
      uid: uid,
      displayName: (map['displayName'] as String?) ?? 'User',
      photoUrl: map['photoUrl'] as String?,
      points: (map['points'] as num?)?.toInt() ?? 0,
      isProfilePublic: (map['isProfilePublic'] as bool?) ?? true,
      interests: map['interests'] != null 
          ? List<String>.from(map['interests'] as List)
          : <String>[],
      email: map['email'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      bio: map['bio'] as String?,
      age: map['age'] != null ? (map['age'] as num).toInt() : null,
      gender: map['gender'] as String?,
      isEmailPublic: (map['isEmailPublic'] as bool?) ?? false,
      isPhonePublic: (map['isPhonePublic'] as bool?) ?? false,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'displayName': displayName,
      'photoUrl': photoUrl,
      'points': points,
      'isProfilePublic': isProfilePublic,
      'interests': interests,
      'email': email,
      'phoneNumber': phoneNumber,
      'bio': bio,
      'age': age,
      'gender': gender,
      'isEmailPublic': isEmailPublic,
      'isPhonePublic': isPhonePublic,
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
    );
  }
}
