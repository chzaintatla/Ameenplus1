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
    // Try leaderboard_public first
    try {
      await for (final snapshot in _firestore
          .collection('leaderboard_public')
          .orderBy('points', descending: true)
          .limit(limit)
          .snapshots()) {
        if (snapshot.docs.isNotEmpty) {
          final users = snapshot.docs
              .map((d) => LeaderboardUser.fromMap(d.id, d.data()))
              .where((u) => u.points > 0) // Only show users with points
              .toList();
          if (users.isNotEmpty) {
            yield users;
            return;
          }
        }
      }
    } catch (e) {
      // Continue to fallback
    }

    // Fallback to users collection
    yield* _getUsersFallback(limit);
  }

  Stream<List<LeaderboardUser>> _getUsersFallback(int limit) async* {
    try {
      // Try with isProfilePublic filter and orderBy
      try {
        await for (final snapshot in _firestore
            .collection('users')
            .where('isProfilePublic', isEqualTo: true)
            .orderBy('xp', descending: true)
            .limit(limit)
            .snapshots()) {
          final users = snapshot.docs.map((d) {
            final data = d.data();
            final xp = (data['xp'] as num?)?.toInt() ?? 0;
            return LeaderboardUser(
              uid: d.id,
              displayName: data['displayName'] as String? ?? 
                          data['name'] as String? ?? 
                          'User',
              photoUrl: data['profilePicture'] as String? ?? 
                       data['photoUrl'] as String?,
              points: xp,
            );
          }).where((u) => u.points > 0).toList();
          
          if (users.isNotEmpty) {
            yield users;
            return;
          }
        }
      } catch (e) {
        // Index might not exist, try without orderBy
      }

      // Get all users and sort in memory
      try {
        await for (final snapshot in _firestore
            .collection('users')
            .limit(50) // Get more to ensure we have enough with points
            .snapshots()) {
          final users = snapshot.docs.map((d) {
            final data = d.data();
            final xp = (data['xp'] as num?)?.toInt() ?? 0;
            return LeaderboardUser(
              uid: d.id,
              displayName: data['displayName'] as String? ?? 
                          data['name'] as String? ?? 
                          'User',
              photoUrl: data['profilePicture'] as String? ?? 
                       data['photoUrl'] as String?,
              points: xp,
            );
          })
          .where((u) => u.points > 0) // Only users with points
          .toList();
          
          // Sort by points descending
          users.sort((a, b) => b.points.compareTo(a.points));
          
          // Take top limit
          yield users.take(limit).toList();
        }
      } catch (e) {
        // If all fails, return empty list
        yield <LeaderboardUser>[];
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
