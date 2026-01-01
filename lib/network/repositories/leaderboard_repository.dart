import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/leaderboard_user.dart';

abstract class LeaderboardRepository {
  Stream<List<LeaderboardUser>> watchTopUsers({int limit});
}

class FirebaseLeaderboardRepository implements LeaderboardRepository {
  FirebaseLeaderboardRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<LeaderboardUser>> watchTopUsers({int limit = 5}) async* {
    try {
      await for (final snapshot in _firestore
          .collection('leaderboard_public')
          .orderBy('points', descending: true)
          .limit(limit)
          .snapshots()) {
        if (snapshot.docs.isNotEmpty) {
          yield snapshot.docs
              .map((d) => LeaderboardUser.fromMap(d.id, d.data()))
              .toList(growable: false);
          return;
        }
      }
    } catch (e) {
    }

    try {
      await for (final snapshot in _firestore
          .collection('users')
          .where('isProfilePublic', isEqualTo: true)
          .orderBy('xp', descending: true)
          .limit(limit)
          .snapshots()) {
        yield snapshot.docs.map((d) {
          final data = d.data();
          return LeaderboardUser(
            uid: d.id,
            displayName: data['displayName'] ?? 'User',
            photoUrl: data['profilePicture'],
            points: data['xp'] ?? 0,
          );
        }).toList(growable: false);
      }
    } catch (e) {
      yield <LeaderboardUser>[];
    }
  }
}

class DisabledLeaderboardRepository implements LeaderboardRepository {
  @override
  Stream<List<LeaderboardUser>> watchTopUsers({int limit = 5}) {
    return Stream.value(<LeaderboardUser>[]);
  }
}
