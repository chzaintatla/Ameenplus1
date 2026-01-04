import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/interests_service.dart';

final interestsServiceProvider = Provider<InterestsService>((ref) {
  return InterestsService();
});

final trendingInterestsProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.read(interestsServiceProvider);
  return await service.getTrendingInterests(limit: 10);
});

