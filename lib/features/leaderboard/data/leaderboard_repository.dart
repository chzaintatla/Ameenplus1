import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_ready_provider.dart';
import '../domain/leaderboard_user.dart';

abstract class LeaderboardRepository {
  Stream<List<LeaderboardUser>> watchTopUsers({int limit});
}

class FirebaseLeaderboardRepository implements LeaderboardRepository {
  FirebaseLeaderboardRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<LeaderboardUser>> watchTopUsers({int limit = 5}) async* {
    try {
      // Try leaderboard_public first
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
      // If leaderboard_public fails, try users collection
    }
    
    // Fallback to users collection
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
      // If both fail, return empty list
      yield <LeaderboardUser>[];
    }
  }
}

class DisabledLeaderboardRepository implements LeaderboardRepository {
  @override
  Stream<List<LeaderboardUser>> watchTopUsers({int limit = 5}) {
    // Return empty list immediately instead of empty stream
    return Stream.value(<LeaderboardUser>[]);
  }
}

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  final readyAsync = ref.watch(firebaseReadyProvider);
  return readyAsync.maybeWhen(
    data: (ready) =>
        ready ? FirebaseLeaderboardRepository(FirebaseFirestore.instance) : DisabledLeaderboardRepository(),
    orElse: () => DisabledLeaderboardRepository(),
  );
});

final top5LeaderboardProvider = StreamProvider<List<LeaderboardUser>>((ref) {
  final repo = ref.watch(leaderboardRepositoryProvider);
  return repo.watchTopUsers(limit: 5);
});
