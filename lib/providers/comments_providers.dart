import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment_model.dart';
import '../network/repositories/comments_repository.dart';

final commentsRepositoryProvider = Provider<CommentsRepository>((ref) {
  return CommentsRepository();
});

final commentsProvider = StreamProvider.family<List<CommentModel>, String>((ref, deedId) {
  final repository = ref.read(commentsRepositoryProvider);
  return repository.getComments(deedId);
});

