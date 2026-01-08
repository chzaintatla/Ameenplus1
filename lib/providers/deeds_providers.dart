import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/repositories/deeds_repository.dart';
import '../models/deed_model.dart';

final deedsRepositoryProvider = Provider<DeedsRepository>((ref) {
  return DeedsRepository();
});

final isFavoritedProvider = StreamProvider.family<bool, Map<String, String>>((ref, params) {
  final repository = ref.read(deedsRepositoryProvider);
  return repository.watchIsFavorited(
    params['deedId']!,
    params['userId']!,
  );
});

final userDeedsProvider = StreamProvider.family<List<DeedModel>, String>((ref, userId) {
  final repository = ref.read(deedsRepositoryProvider);
  return repository.getUserDeeds(userId);
});
