import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../utils/app_constants.dart';
import '../../utils/xp_service.dart';
import 'notification_repository.dart';
import '../../models/comment_model.dart';

/// Repository for managing comments on deeds
class CommentsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final XPService _xpService = XPService();
  final NotificationRepository _notificationRepo = NotificationRepository();

  /// Add a comment to a deed
  Future<CommentModel> addComment({
    required String deedId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required String content,
  }) async {
    try {
      final comment = CommentModel(
        id: const Uuid().v4(),
        deedId: deedId,
        userId: userId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        content: content,
        createdAt: DateTime.now(),
      );

      // Save comment
      await _firestore
          .collection(AppConstants.collectionDeeds)
          .doc(deedId)
          .collection('comments')
          .doc(comment.id)
          .set(comment.toFirestore());

      // Update comment count on deed
      await _firestore
          .collection(AppConstants.collectionDeeds)
          .doc(deedId)
          .update({
        'commentsCount': FieldValue.increment(1),
      });

      // Award XP for commenting
      await _xpService.awardXPForComment(userId);

      // Send notification to deed owner
      final deedDoc = await _firestore
          .collection(AppConstants.collectionDeeds)
          .doc(deedId)
          .get();
      
      if (deedDoc.exists) {
        final deedData = deedDoc.data()!;
        final deedOwnerId = deedData['userId'] as String;
        
        if (deedOwnerId != userId) {
          await _notificationRepo.createNotification(
            userId: deedOwnerId,
            type: 'deed_comment',
            title: 'New Comment',
            body: '$userName commented on your deed',
            actionId: deedId,
          );
        }
      }

      return comment;
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  /// Get comments for a deed
  Stream<List<CommentModel>> getComments(String deedId, {int limit = 10}) {
    return _firestore
        .collection(AppConstants.collectionDeeds)
        .doc(deedId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Delete a comment
  Future<void> deleteComment(String deedId, String commentId, String userId) async {
    try {
      final commentDoc = await _firestore
          .collection(AppConstants.collectionDeeds)
          .doc(deedId)
          .collection('comments')
          .doc(commentId)
          .get();

      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final data = commentDoc.data()!;
      if (data['userId'] != userId) {
        throw Exception('Not authorized to delete this comment');
      }

      await _firestore
          .collection(AppConstants.collectionDeeds)
          .doc(deedId)
          .collection('comments')
          .doc(commentId)
          .delete();

      // Decrement comment count
      await _firestore
          .collection(AppConstants.collectionDeeds)
          .doc(deedId)
          .update({
        'commentsCount': FieldValue.increment(-1),
      });
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }

  /// Like a comment
  Future<void> likeComment(String deedId, String commentId, String userId) async {
    try {
      final commentRef = _firestore
          .collection(AppConstants.collectionDeeds)
          .doc(deedId)
          .collection('comments')
          .doc(commentId);

      await _firestore.runTransaction((transaction) async {
        final commentDoc = await transaction.get(commentRef);
        if (!commentDoc.exists) return;

        final data = commentDoc.data()!;
        final likes = List<String>.from(data['likes'] ?? []);

        if (likes.contains(userId)) {
          likes.remove(userId);
        } else {
          likes.add(userId);
        }

        transaction.update(commentRef, {'likes': likes});
      });
    } catch (e) {
      throw Exception('Failed to like comment: $e');
    }
  }
}

