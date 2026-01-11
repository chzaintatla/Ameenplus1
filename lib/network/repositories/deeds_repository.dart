import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_database.dart';
import '../../utils/xp_service.dart';
import '../../services/storage_service.dart';
import 'notification_repository.dart';
import '../../models/deed_model.dart';

class DeedsRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AppDatabase _localDb = AppDatabase.instance;
  final XPService _xpService = XPService();
  final NotificationRepository _notificationRepo = NotificationRepository();

  /// Create a deed/post - saved with isValidated: false initially
  /// Backend validation will update isValidated to true if content is valid
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
    // Note: isValidated should always be false when creating - backend will validate
    bool isValidated = false,
    String? validationReason,
    double? validationConfidence,
  }) async {
    try {
      String? imageUrl;
      List<String> mediaUrls = [];

      // Upload image to Supabase Storage
      if (imagePath != null && !imagePath.startsWith('http')) {
        final file = File(imagePath);
        if (await file.exists()) {
          if (await file.length() > 10 * 1024 * 1024) {
            throw Exception('Image must be less than 10MB');
          }
          final fileName = '${const Uuid().v4()}.jpg';
          final filePath = '$userId/$fileName';
          
          imageUrl = await StorageService.uploadFile(
            bucket: 'deeds',
            filePath: filePath,
            file: file,
            contentType: 'image/jpeg',
          );
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
          final filePath = '$userId/$fileName';
          
          final videoUrl = await StorageService.uploadFile(
            bucket: 'deeds',
            filePath: filePath,
            file: file,
            contentType: 'video/mp4',
          );
          mediaUrls.add(videoUrl);
        }
      }

      // Upload other files
      if (filePath != null && !filePath.startsWith('http')) {
        final file = File(filePath);
        if (await file.exists()) {
          final maxSize = mediaType == 'pdf' || mediaType == 'audio' ? 20 * 1024 * 1024 : 10 * 1024 * 1024;
          if (await file.length() > maxSize) {
            throw Exception('File must be less than ${maxSize ~/ (1024 * 1024)}MB');
          }
          
          String extension = filePath.split('.').last.toLowerCase();
          String contentType = 'application/octet-stream';
          if (extension == 'pdf') {
            contentType = 'application/pdf';
          } else if (['mp3', 'wav', 'm4a'].contains(extension)) {
            contentType = 'audio/$extension';
          } else if (['doc', 'docx'].contains(extension)) {
            contentType = 'application/msword';
          } else if (['xls', 'xlsx'].contains(extension)) {
            contentType = 'application/vnd.ms-excel';
          }
          
          final fileName = '${const Uuid().v4()}.$extension';
          final storagePath = '$userId/$fileName';
          
          final fileUrl = await StorageService.uploadFile(
            bucket: 'deeds',
            filePath: storagePath,
            file: file,
            contentType: contentType,
          );
          mediaUrls.add(fileUrl);
        }
      }

      final deedId = const Uuid().v4();
      final now = DateTime.now();

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
        isValidated: false, // Always false initially - backend will validate
        validationReason: null,
        validationConfidence: null,
        createdAt: now,
      );

      // Save to Supabase database - backend validation will update isValidated
      await _supabase
          .from(AppConstants.collectionDeeds)
          .insert(deed.toMap());

      await _localDb.cacheDeed(deed.toLocal());

      // Don't award XP yet - wait for backend validation
      // XP will be awarded when backend sets isValidated to true

      return deed;
    } catch (e) {
      throw Exception('Failed to create deed: $e');
    }
  }

  /// Get deeds feed - only returns validated posts
  Stream<List<DeedModel>> getDeedsFeed({int limit = 20}) {
    return _supabase
        .from(AppConstants.collectionDeeds)
        .stream(primaryKey: ['id'])
        .eq('is_validated', true) // Only show validated posts
        .order('created_at', ascending: false)
        .limit(limit)
        .map((data) => data.map((item) => DeedModel.fromMap(item)).toList());
  }

  /// Get user deeds - shows all posts (validated and pending) for the user
  Stream<List<DeedModel>> getUserDeeds(String userId, {int limit = 50}) {
    return _supabase
        .from(AppConstants.collectionDeeds)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit)
        .map((data) => data.map((item) => DeedModel.fromMap(item)).toList());
  }

  Future<void> likeDeed(String deedId, String userId) async {
    // Get current deed
    final deedData = await _supabase
        .from(AppConstants.collectionDeeds)
        .select()
        .eq('id', deedId)
        .maybeSingle();

    if (deedData == null) return;

    final likes = List<String>.from(deedData['likes'] ?? []);
    final isLiked = likes.contains(userId);

    if (isLiked) {
      likes.remove(userId);
    } else {
      likes.add(userId);
    }

    await _supabase
        .from(AppConstants.collectionDeeds)
        .update({'likes': likes})
        .eq('id', deedId);

    await _localDb.updateDeedLikeStatus(deedId, !isLiked, likes.length);

    if (!isLiked) {
      await _xpService.awardXPForLike(userId);

      final ownerId = deedData['user_id'] as String;

      if (ownerId != userId) {
        String likerName = 'Someone';
        try {
          final likerData = await _supabase
              .from(AppConstants.collectionUsers)
              .select()
              .eq('id', userId)
              .maybeSingle();
          
          if (likerData != null) {
            likerName = likerData['display_name'] as String? ?? 'Someone';
          }
        } catch (e) {
          // Fallback to 'Someone'
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
    final deedData = await _supabase
        .from(AppConstants.collectionDeeds)
        .select('shares_count')
        .eq('id', deedId)
        .maybeSingle();

    if (deedData != null) {
      final currentShares = deedData['shares_count'] ?? 0;
      await _supabase
          .from(AppConstants.collectionDeeds)
          .update({'shares_count': currentShares + 1})
          .eq('id', deedId);
    }

    await _xpService.awardXPForShare(userId);
  }

  Future<void> favoriteDeed(String deedId, String userId) async {
    final userData = await _supabase
        .from(AppConstants.collectionUsers)
        .select('favorites')
        .eq('id', userId)
        .maybeSingle();

    if (userData == null) return;

    final favorites = List<String>.from(userData['favorites'] ?? []);

    if (favorites.contains(deedId)) {
      favorites.remove(deedId);
    } else {
      favorites.add(deedId);
      await _xpService.awardXPForFavorite(userId);
    }

    await _supabase
        .from(AppConstants.collectionUsers)
        .update({'favorites': favorites})
        .eq('id', userId);
  }

  Stream<bool> watchIsFavorited(String deedId, String userId) {
    return _supabase
        .from(AppConstants.collectionUsers)
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((data) {
          if (data.isEmpty) return false;
          final favorites = List<String>.from(data.first['favorites'] ?? []);
          return favorites.contains(deedId);
        });
  }

  Future<void> deleteDeed(String deedId, String userId) async {
    final deedData = await _supabase
        .from(AppConstants.collectionDeeds)
        .select()
        .eq('id', deedId)
        .maybeSingle();

    if (deedData == null) return;

    if (deedData['user_id'] != userId) {
      throw Exception('Unauthorized');
    }

    // Delete media from Supabase Storage
    final imageUrl = deedData['image_url'];
    if (imageUrl != null && imageUrl.toString().contains('supabase')) {
      try {
        final uri = Uri.parse(imageUrl);
        final path = uri.pathSegments.last;
        await StorageService.deleteFile(bucket: 'deeds', filePath: path);
      } catch (e) {
        // Ignore storage deletion errors
      }
    }

    // Delete media URLs
    final mediaUrls = List<String>.from(deedData['media_urls'] ?? []);
    for (final url in mediaUrls) {
      if (url.contains('supabase')) {
        try {
          final uri = Uri.parse(url);
          final path = uri.pathSegments.last;
          await StorageService.deleteFile(bucket: 'deeds', filePath: path);
        } catch (e) {
          // Ignore storage deletion errors
        }
      }
    }

    await _supabase
        .from(AppConstants.collectionDeeds)
        .delete()
        .eq('id', deedId);
  }
}
