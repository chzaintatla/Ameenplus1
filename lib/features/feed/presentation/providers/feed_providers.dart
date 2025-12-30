import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../deeds/data/deeds_repository.dart';
import '../../../deeds/models/deed_model.dart';

final deedsRepositoryProvider = Provider<DeedsRepository>((ref) {
  return DeedsRepository();
});

final deedsFeedProvider = StreamProvider<List<DeedModel>>((ref) {
  final repository = ref.watch(deedsRepositoryProvider);
  return repository.getDeedsFeed(limit: 20);
});
