import 'dart:async';
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
    String? videoPath,
    String? filePath,
    String? mediaType,
    List<String> interests = const [],
    bool isValidated = false,
    String? validationReason,
    double? validationConfidence,
  }) async {
    try {
      String? imageUrl;
      List<String> mediaUrls = [];

      // Upload image
      if (imagePath != null && !imagePath.startsWith('http')) {
        final file = File(imagePath);
        if (await file.exists()) {
          if (await file.length() > 10 * 1024 * 1024) {
            throw Exception('Image must be less than 10MB');
          }
          final fileName = '${const Uuid().v4()}.jpg';
          final ref = _storage.ref().child('deeds').child(userId).child(fileName);
          await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
          imageUrl = await ref.getDownloadURL();
          mediaUrls.add(imageUrl);
        }
      }

      // Upload video
      if (videoPath != null && !videoPath.startsWith('http')) {
        final file = File(videoPath);
        if (await file.exists()) {
          if (await file.length() > 50 * 1024 * 1024) {
            throw Exception('Video must be less than 50MB');
          }
          final fileName = '${const Uuid().v4()}.mp4';
          final ref = _storage.ref().child('deeds').child(userId).child(fileName);
          await ref.putFile(file, SettableMetadata(contentType: 'video/mp4'));
          final videoUrl = await ref.getDownloadURL();
          mediaUrls.add(videoUrl);
        }
      }

      // Upload other files (PDF, Audio, Word, Excel)
      if (filePath != null && !filePath.startsWith('http')) {
        final file = File(filePath);
        if (await file.exists()) {
          final maxSize = mediaType == 'pdf' || mediaType == 'audio' ? 20 * 1024 * 1024 : 10 * 1024 * 1024;
          if (await file.length() > maxSize) {
            throw Exception('File must be less than ${maxSize ~/ (1024 * 1024)}MB');
          }
          
          String extension = filePath.split('.').last.toLowerCase();
          String contentType = 'application/octet-stream';
          if (extension == 'pdf') contentType = 'application/pdf';
          else if (['mp3', 'wav', 'm4a'].contains(extension)) contentType = 'audio/$extension';
          else if (['doc', 'docx'].contains(extension)) contentType = 'application/msword';
          else if (['xls', 'xlsx'].contains(extension)) contentType = 'application/vnd.ms-excel';
          
          final fileName = '${const Uuid().v4()}.$extension';
          final ref = _storage.ref().child('deeds').child(userId).child(fileName);
          await ref.putFile(file, SettableMetadata(contentType: contentType));
          final fileUrl = await ref.getDownloadURL();
          mediaUrls.add(fileUrl);
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
        mediaUrls: mediaUrls,
        mediaType: mediaType,
        interests: interests,
        isValidated: isValidated,
        validationReason: validationReason,
        validationConfidence: validationConfidence,
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
    final controller = StreamController<List<DeedModel>>();
    StreamSubscription? subscription;
    bool fallbackUsed = false;
    
    subscription = _firestore
        .collection(AppConstants.collectionDeeds)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => DeedModel.fromFirestore(d)).toList())
        .listen(
          (deeds) {
            if (!fallbackUsed) {
              controller.add(deeds);
            }
          },
          onError: (error) {
            final errorStr = error.toString();
            if ((errorStr.contains('index') || errorStr.contains('FAILED_PRECONDITION')) && !fallbackUsed) {
              fallbackUsed = true;
              subscription?.cancel();
              _getUserDeedsFallback(userId, limit).listen(
                (deeds) => controller.add(deeds),
                onError: (e) => controller.addError(e),
                onDone: () => controller.close(),
                cancelOnError: false,
              );
            } else {
              controller.addError(error);
            }
          },
          onDone: () {
            if (!fallbackUsed) {
              controller.close();
            }
          },
          cancelOnError: false,
        );
    
    controller.onCancel = () {
      subscription?.cancel();
    };
    
    return controller.stream;
  }

  Stream<List<DeedModel>> _getUserDeedsFallback(String userId, int limit) async* {
    try {
      await for (final snapshot in _firestore
          .collection(AppConstants.collectionDeeds)
          .where('userId', isEqualTo: userId)
          .limit(limit * 2)
          .snapshots()) {
        final deeds = snapshot.docs.map((d) => DeedModel.fromFirestore(d)).toList();
        deeds.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        yield deeds.take(limit).toList();
      }
    } catch (e) {
      yield <DeedModel>[];
    }
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
