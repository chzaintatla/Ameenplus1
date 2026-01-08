import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/app_constants.dart';
import '../../models/comment_model.dart';
import 'notification_repository.dart';

class CommentsRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationRepository _notificationRepo = NotificationRepository();

  Future<void> addComment({
    required String deedId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required String content,
  }) async {
    await _supabase.from(AppConstants.collectionComments).insert({
      'deed_id': deedId,
      'user_id': userId,
      'user_name': userName,
      'user_photo_url': userPhotoUrl,
      'content': content,
      'likes': [],
      'created_at': DateTime.now().toIso8601String(),
    });

    // Update comment count on deed
    final deedData = await _supabase
        .from(AppConstants.collectionDeeds)
        .select('comments_count, user_id')
        .eq('id', deedId)
        .maybeSingle();

    if (deedData != null) {
      final currentCount = (deedData['comments_count'] as num?)?.toInt() ?? 0;
      await _supabase
          .from(AppConstants.collectionDeeds)
          .update({'comments_count': currentCount + 1})
          .eq('id', deedId);

      // Notify deed owner
      final ownerId = deedData['user_id'];
      if (ownerId != userId) {
        await _notificationRepo.createNotification(
          userId: ownerId,
          type: 'deed_comment',
          title: 'New Comment',
          body: '$userName commented on your post',
          actionId: deedId,
        );
      }
    }
  }

  Stream<List<CommentModel>> getComments(String deedId) {
    return _supabase
        .from(AppConstants.collectionComments)
        .stream(primaryKey: ['id'])
        .eq('deed_id', deedId)
        .order('created_at', ascending: true)
        .map((data) => data.map((item) => CommentModel.fromMap(item)).toList());
  }

  Future<void> deleteComment(String commentId, String userId) async {
    final commentData = await _supabase
        .from(AppConstants.collectionComments)
        .select()
        .eq('id', commentId)
        .maybeSingle();

    if (commentData == null || (commentData['user_id'] ?? commentData['userId']) != userId) {
      throw Exception('Unauthorized');
    }

    await _supabase
        .from(AppConstants.collectionComments)
        .delete()
        .eq('id', commentId);

    // Update comment count
    final deedId = commentData['deed_id'] ?? commentData['deedId'];
    final deedData = await _supabase
        .from(AppConstants.collectionDeeds)
        .select('comments_count')
        .eq('id', deedId)
        .maybeSingle();

    if (deedData != null) {
      final currentCount = (deedData['comments_count'] as num?)?.toInt() ?? 0;
      await _supabase
          .from(AppConstants.collectionDeeds)
          .update({'comments_count': (currentCount - 1).clamp(0, 999999)})
          .eq('id', deedId);
    }
  }

  Future<void> likeComment(String commentId, String userId) async {
    final commentData = await _supabase
        .from(AppConstants.collectionComments)
        .select('likes, user_id, deed_id')
        .eq('id', commentId)
        .maybeSingle();

    if (commentData != null) {
      final likes = List<String>.from(commentData['likes'] ?? []);
      if (!likes.contains(userId)) {
        likes.add(userId);
        await _supabase
            .from(AppConstants.collectionComments)
            .update({'likes': likes})
            .eq('id', commentId);

        // Notify comment owner
        final ownerId = commentData['user_id'];
        if (ownerId != userId) {
          await _notificationRepo.createNotification(
            userId: ownerId,
            type: 'comment_like',
            title: 'Comment Liked',
            body: 'Someone liked your comment',
            actionId: commentData['deed_id'],
          );
        }
      }
    }
  }

  Future<void> unlikeComment(String commentId, String userId) async {
    final commentData = await _supabase
        .from(AppConstants.collectionComments)
        .select('likes')
        .eq('id', commentId)
        .maybeSingle();

    if (commentData != null) {
      final likes = List<String>.from(commentData['likes'] ?? []);
      if (likes.contains(userId)) {
        likes.remove(userId);
        await _supabase
            .from(AppConstants.collectionComments)
            .update({'likes': likes})
            .eq('id', commentId);
      }
    }
  }
}
