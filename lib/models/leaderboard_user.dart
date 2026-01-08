class LeaderboardUser {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final int points;
  final int level;
  final String? region;

  LeaderboardUser({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.points,
    this.level = 1,
    this.region,
  });

  factory LeaderboardUser.fromMap(Map<String, dynamic> data) {
    return LeaderboardUser(
      uid: data['id'] ?? data['uid'] ?? '',
      displayName: data['display_name'] ?? data['displayName'] ?? 'User',
      photoUrl: data['profile_picture'] ?? data['photo_url'] ?? data['photoUrl'] ?? data['profilePicture'],
      points: data['points'] ?? 0,
      level: data['level'] ?? 1,
      region: data['region'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': uid,
      'display_name': displayName,
      'profile_picture': photoUrl,
      'points': points,
      'level': level,
      'region': region,
    };
  }
}
