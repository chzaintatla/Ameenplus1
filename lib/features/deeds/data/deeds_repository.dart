import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/local/app_database.dart';
import '../../../core/services/xp_service.dart';
import '../../notifications/data/notification_repository.dart';
import '../models/deed_model.dart';

/// Repository for managing deeds (posts)
class DeedsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AppDatabase _localDb = AppDatabase.instance;
  final XPService _xpService = XPService();
  final NotificationRepository _notificationRepo = NotificationRepository();

  /// Create a new deed
  Future<DeedModel> createDeed({
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required String deedType,
    required String content,
    String? arabicText,
    String? translation,
    String? reference,
    String? category,
    String? imagePath,
  }) async {
    try {
      String? imageUrl;
      
      // Upload image if provided
      if (imagePath != null) {
        try {
          // Check if it's already a URL
          if (imagePath.startsWith('http')) {
            imageUrl = imagePath;
          } else {
            // It's a local file path, upload it
            final file = File(imagePath);
            if (await file.exists()) {
              final imageRef = _storage
                  .ref()
                  .child('deeds')
                  .child('${const Uuid().v4()}.jpg');
              
              await imageRef.putFile(file);
              imageUrl = await imageRef.getDownloadURL();
            }
          }
        } catch (e) {
          // If image upload fails, continue without image
          // Don't fail the whole deed creation
        }
      }

      final deed = DeedModel(
        id: const Uuid().v4(),
        userId: userId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        deedType: deedType,
        content: content,
        arabicText: arabicText,
        translation: translation,
        reference: reference,
        category: category,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      await _firestore
          .collection(AppConstants.collectionDeeds)
          .doc(deed.id)
          .set(deed.toFirestore());

      // Cache locally
      await _localDb.cacheDeed(deed.toLocal());

      // Award XP for posting deed
      await _xpService.awardXPForDeed(userId);

      return deed;
    } catch (e) {
      throw Exception('Failed to create deed: $e');
    }
  }

  /// Get deeds feed
  Stream<List<DeedModel>> getDeedsFeed({int limit = 20}) {
    return _firestore
        .collection(AppConstants.collectionDeeds)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DeedModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Get cached deeds (offline)
  Future<List<DeedModel>> getCachedDeeds({int limit = 20}) async {
    final cached = await _localDb.getCachedDeeds(limit: limit);
    return cached.map((data) => DeedModel.fromLocal(data)).toList();
  }

  /// Like a deed
  Future<void> likeDeed(String deedId, String userId) async {
    try {
      final deedRef = _firestore
          .collection(AppConstants.collectionDeeds)
          .doc(deedId);

      await _firestore.runTransaction((transaction) async {
        final deedDoc = await transaction.get(deedRef);
        if (!deedDoc.exists) return;

        final data = deedDoc.data()!;
        final likes = List<String>.from(data['likes'] ?? []);
        
        if (likes.contains(userId)) {
          likes.remove(userId);
        } else {
          likes.add(userId);
        }

        transaction.update(deedRef, {'likes': likes});
      });

      // Update local cache - get fresh data after transaction
      final deedDoc = await deedRef.get();
      if (deedDoc.exists) {
        final deed = DeedModel.fromFirestore(deedDoc);
        final isNowLiked = deed.isLikedBy(userId);
        
        await _localDb.updateDeedLikeStatus(
          deedId,
          isNowLiked,
          deed.likesCount,
        );

        // Award XP only when liking (not unliking)
        if (isNowLiked) {
          await _xpService.awardXPForLike(userId);
          
          // Send notification to deed owner
          final deedData = deedDoc.data()!;
          final deedOwnerId = deedData['userId'] as String;
          final deedOwnerName = deedData['userName'] as String;
          
          if (deedOwnerId != userId) {
            await _notificationRepo.createNotification(
              userId: deedOwnerId,
              type: 'deed_like',
              title: 'New Like',
              body: 'Someone liked your deed',
              actionId: deedId,
            );
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to like deed: $e');
    }
  }

  /// Delete a deed
  Future<void> deleteDeed(String deedId, String userId) async {
    try {
      final deedDoc = await _firestore
          .collection(AppConstants.collectionDeeds)
          .doc(deedId)
          .get();

      if (!deedDoc.exists) {
        throw Exception('Deed not found');
      }

      final data = deedDoc.data()!;
      if (data['userId'] != userId) {
        throw Exception('Not authorized to delete this deed');
      }

      // Delete image if exists
      final imageUrl = data['imageUrl'] as String?;
      if (imageUrl != null) {
        try {
          await _storage.refFromURL(imageUrl).delete();
        } catch (_) {
          // Ignore image deletion errors
        }
      }

      await _firestore
          .collection(AppConstants.collectionDeeds)
          .doc(deedId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete deed: $e');
    }
  }
}

