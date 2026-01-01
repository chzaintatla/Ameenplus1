import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_database.dart';
import '../../utils/xp_service.dart';
import 'notification_repository.dart';
import '../../models/deed_model.dart';

class DeedsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AppDatabase _localDb = AppDatabase.instance;
  final XPService _xpService = XPService();
  final NotificationRepository _notificationRepo = NotificationRepository();

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

      if (imagePath != null && !imagePath.startsWith('http')) {
        final file = File(imagePath);

        if (!await file.exists()) {
          throw Exception('Image file not found');
        }

        if (await file.length() > 10 * 1024 * 1024) {
          throw Exception('Image must be less than 10MB');
        }

        final fileName = '${const Uuid().v4()}.jpg';

        final ref = _storage
            .ref()
            .child('deeds')
            .child(userId)
            .child(fileName);

        try {
          await ref.putFile(
            file,
            SettableMetadata(contentType: 'image/jpeg'),
          );

          imageUrl = await ref.getDownloadURL();
        } on FirebaseException catch (e) {
          if (e.code == 'object-not-found' || e.code == '-13010') {
            throw Exception('Storage rules not deployed or permission denied. Please ensure Storage rules are deployed in Firebase Console.');
          } else if (e.code == 'unauthorized' || e.code == 'permission-denied') {
            throw Exception('Permission denied. Please check your Storage rules allow authenticated uploads.');
          } else if (e.code == 'quota-exceeded') {
            throw Exception('Storage quota exceeded. Please contact support.');
          } else if (e.code == 'unauthenticated') {
            throw Exception('Please sign in to upload images.');
          }
          throw Exception('Upload failed: ${e.message ?? e.code}');
        } catch (e) {
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('404') || errorStr.contains('not found') || errorStr.contains('object-not-found')) {
            throw Exception('Storage service unavailable. Please ensure Storage rules are deployed in Firebase Console.');
          } else if (errorStr.contains('permission') || errorStr.contains('denied')) {
            throw Exception('Permission denied. Please check your Storage rules allow authenticated uploads.');
          } else if (errorStr.contains('network') || errorStr.contains('connection')) {
            throw Exception('Network error. Please check your internet connection and try again.');
          }
          rethrow;
        }
      }

      final deedId = const Uuid().v4();

      final deed = DeedModel(
        id: deedId,
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

      await _firestore
          .collection(AppConstants.collectionDeeds)
          .doc(deedId)
          .set(deed.toFirestore());

      await _localDb.cacheDeed(deed.toLocal());

      await _xpService.awardXPForDeed(userId);

      return deed;
    } catch (e) {
      throw Exception('Failed to create deed: $e');
    }
  }

  Stream<List<DeedModel>> getDeedsFeed({int limit = 20}) {
    return _firestore
        .collection(AppConstants.collectionDeeds)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => DeedModel.fromFirestore(d)).toList());
  }

  Stream<List<DeedModel>> getUserDeeds(String userId, {int limit = 50}) {
    return _firestore
        .collection(AppConstants.collectionDeeds)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => DeedModel.fromFirestore(d)).toList());
  }

  Future<void> likeDeed(String deedId, String userId) async {
    final ref = _firestore.collection(AppConstants.collectionDeeds).doc(deedId);

    await _firestore.runTransaction((t) async {
      final snap = await t.get(ref);
      if (!snap.exists) return;

      final data = snap.data()!;
      final likes = List<String>.from(data['likes'] ?? []);

      likes.contains(userId) ? likes.remove(userId) : likes.add(userId);

      t.update(ref, {'likes': likes});
    });

    final snap = await ref.get();
    if (!snap.exists) return;

    final deed = DeedModel.fromFirestore(snap);

    await _localDb.updateDeedLikeStatus(
      deedId,
      deed.isLikedBy(userId),
      deed.likesCount,
    );

    if (deed.isLikedBy(userId)) {
      await _xpService.awardXPForLike(userId);

      final data = snap.data()!;
      final ownerId = data['userId'] as String;

      if (ownerId != userId) {
        // Get the liker's name (current user who clicked like)
        String likerName = 'Someone';
        try {
          final likerDoc = await _firestore.collection(AppConstants.collectionUsers).doc(userId).get();
          if (likerDoc.exists) {
            final likerData = likerDoc.data()!;
            likerName = likerData['displayName'] as String? ?? likerData['userName'] as String? ?? 'Someone';
          }
        } catch (e) {
          // Fallback to 'Someone' if user lookup fails
        }

        await _notificationRepo.createNotification(
          userId: ownerId,
          type: 'deed_like',
          title: 'New Like',
          body: '$likerName liked your post',
          actionId: deedId,
        );
      }
    }
  }

  Future<void> shareDeed(String deedId, String userId) async {
    await _firestore
        .collection(AppConstants.collectionDeeds)
        .doc(deedId)
        .update({'sharesCount': FieldValue.increment(1)});

    await _xpService.awardXPForShare(userId);
  }

  Future<void> favoriteDeed(String deedId, String userId) async {
    final ref = _firestore.collection(AppConstants.collectionUsers).doc(userId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final favorites = List<String>.from(snap.data()?['favorites'] ?? []);

    if (favorites.contains(deedId)) {
      favorites.remove(deedId);
    } else {
      favorites.add(deedId);
      await _xpService.awardXPForFavorite(userId);
    }

    await ref.update({'favorites': favorites});
  }

  Stream<bool> watchIsFavorited(String deedId, String userId) {
    return _firestore
        .collection(AppConstants.collectionUsers)
        .doc(userId)
        .snapshots()
        .map((s) {
      if (!s.exists) return false;
      final favorites = List<String>.from(s.data()?['favorites'] ?? []);
      return favorites.contains(deedId);
    });
  }

  Future<void> deleteDeed(String deedId, String userId) async {
    final ref = _firestore.collection(AppConstants.collectionDeeds).doc(deedId);
    final snap = await ref.get();
    if (!snap.exists) return;

    if (snap.data()!['userId'] != userId) {
      throw Exception('Unauthorized');
    }

    final imageUrl = snap.data()!['imageUrl'];
    if (imageUrl != null) {
      await _storage.refFromURL(imageUrl).delete();
    }

    await ref.delete();
  }
}
