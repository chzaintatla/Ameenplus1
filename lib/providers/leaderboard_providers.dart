import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_ready_provider.dart';
import '../models/leaderboard_user.dart';
import '../network/repositories/leaderboard_repository.dart';

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

