class LeaderboardUser {
  const LeaderboardUser({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    required this.points,
  });

  final String uid;
  final String displayName;
  final String? photoUrl;
  final int points;

  factory LeaderboardUser.fromMap(String uid, Map<String, Object?> map) {
    return LeaderboardUser(
      uid: uid,
      displayName: (map['displayName'] as String?) ?? 'User',
      photoUrl: map['photoUrl'] as String?,
      points: (map['points'] as num?)?.toInt() ?? 0,
    );
  }
}

