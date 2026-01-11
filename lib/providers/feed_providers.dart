import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/deed_model.dart';
import 'deeds_providers.dart';

final deedsFeedProvider = StreamProvider<List<DeedModel>>((ref) {
  final repository = ref.watch(deedsRepositoryProvider);
  return repository.getDeedsFeed(limit: 20);
});

