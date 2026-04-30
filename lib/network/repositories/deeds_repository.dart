import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_database.dart';
import '../../utils/xp_service.dart';
import '../../utils/points_service.dart';
import '../../services/storage_service.dart';
import '../../services/ai_validation_service.dart';
import 'notification_repository.dart';
import '../../models/deed_model.dart';

class DeedsRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AppDatabase _localDb = AppDatabase.instance;
  final XPService _xpService = XPService();
  final PointsService _pointsService = PointsService();
  final NotificationRepository _notificationRepo = NotificationRepository();
  final AIContentValidationService _validationService = AIContentValidationService();

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

      String? mediaPath;
      if (imagePath != null && !imagePath.startsWith('http')) {
        mediaPath = imagePath;
      } else if (videoPath != null && !videoPath.startsWith('http')) {
        mediaPath = videoPath;
      } else if (filePath != null && !filePath.startsWith('http')) {
        mediaPath = filePath;
      }

      final validationResult = await _validationService.validatePost(
        text: content,
        mediaPath: mediaPath,
        mediaType: mediaType,
      );

      if (!validationResult.isValid) {
        throw Exception('Content validation failed: ${validationResult.reason}. Only authentic Islamic content is allowed.');
      }

      final validatedDeed = DeedModel(
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
        isValidated: true,
        validationReason: validationResult.reason,
        validationConfidence: validationResult.confidence,
        createdAt: now,
      );

      await _supabase
          .from(AppConstants.collectionDeeds)
          .insert(validatedDeed.toMap());

      await _localDb.cacheDeed(validatedDeed.toLocal());

      await _pointsService.addDeedPoints(
        userId: userId,
        points: 5.0,
      );

      return validatedDeed;
    } catch (e) {
      throw Exception('Failed to create deed: $e');
    }
  }

  /// Get deeds feed - only returns validated posts with content
  /// Uses real-time subscription for live updates
  /// Deduplication happens ONCE here - UI should NEVER dedupe realtime data
  Stream<List<DeedModel>> getDeedsFeed({int limit = 20}) {
    return _supabase
        .from(AppConstants.collectionDeeds)
        .stream(primaryKey: ['id'])
        .eq('is_validated', true) // Only show validated posts
        .order('created_at', ascending: false)
        .limit(limit) // Query only what we need - no double limiting
        .map((data) {
          // CRITICAL: Deduplicate by ID using LinkedHashMap to preserve insertion order
          // Use LinkedHashMap to ensure consistent ordering
          final map = <String, DeedModel>{};
          
          for (final row in data) {
            try {
              // Validate ID before parsing
              final rowIdValue = row['id'];
              if (rowIdValue == null) {
                // Skip rows with null IDs
                if (kDebugMode) {
                  debugPrint('Skipping deed with null ID: $row');
                }
                continue;
              }
              
              final rowId = rowIdValue.toString().trim();
              if (rowId.isEmpty) {
                // Skip rows with empty IDs
                if (kDebugMode) {
                  debugPrint('Skipping deed with empty ID: $row');
                }
                continue;
              }
              
              final deed = DeedModel.fromMap(row);
              // Double-check ID after parsing
              if (deed.id.isNotEmpty && deed.id.trim().isNotEmpty && deed.id == rowId) {
                // Always use the latest version (overwrite if exists)
                map[deed.id] = deed;
              }
            } catch (e) {
              // Skip invalid entries silently
              if (kDebugMode) {
                debugPrint('Error parsing deed in feed: $e');
              }
            }
          }
          
          // Convert to list maintaining order (Map.values preserves insertion order)
          final list = map.values.toList();
          
          // Final sort to ensure newest first (data from Supabase should already be sorted, but double-check)
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          // Final safety check: ensure no duplicates in the final list
          final seenIds = <String>{};
          final finalList = <DeedModel>[];
          for (final deed in list) {
            if (!seenIds.contains(deed.id)) {
              seenIds.add(deed.id);
              finalList.add(deed);
            }
          }
          
          return finalList;
        });
  }

  /// Get user deeds - shows all posts (validated and pending) for the user
  /// Uses real-time subscription for live updates
  Stream<List<DeedModel>> getUserDeeds(String userId, {int limit = 50}) {
    return _supabase
        .from(AppConstants.collectionDeeds)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit)
        .map((data) => data.map((item) => DeedModel.fromMap(item)).toList());
  }

  /// Watch if a deed is liked by a user (real-time)
  Stream<bool> watchIsLiked(String deedId, String userId) {
    return _supabase
        .from('likes')
        .stream(primaryKey: ['id'])
        .map((data) {
          return data.any((item) => 
            item['deed_id'] == deedId && item['user_id'] == userId
          );
        });
  }

  Future<void> likeDeed(String deedId, String userId) async {
    final deedData = await _supabase
        .from(AppConstants.collectionDeeds)
        .select()
        .eq('id', deedId)
        .maybeSingle();

    if (deedData == null) return;

    // Check if already liked
    final existingLike = await _supabase
        .from('likes')
        .select()
        .eq('deed_id', deedId)
        .eq('user_id', userId)
        .maybeSingle();

    final isLiked = existingLike != null;

    if (isLiked) {
      // Unlike: delete from likes table
      await _supabase
          .from('likes')
          .delete()
          .eq('deed_id', deedId)
          .eq('user_id', userId);
    } else {
      // Like: insert into likes table
      await _supabase
          .from('likes')
          .insert({
            'id': const Uuid().v4(),
            'deed_id': deedId,
            'user_id': userId,
            'created_at': DateTime.now().toIso8601String(),
          });

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
          // Silently fail - use default name if unable to fetch liker data
          if (kDebugMode) {
            debugPrint('Error fetching liker data: $e');
          }
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

    // Get updated like count
    final likesCount = await _supabase
        .from('likes')
        .select('id')
        .eq('deed_id', deedId);
    
    await _localDb.updateDeedLikeStatus(deedId, !isLiked, likesCount.length);
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
    // Check if already favorited
    final existingFavorite = await _supabase
        .from('favorites')
        .select()
        .eq('deed_id', deedId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existingFavorite != null) {
      // Unfavorite: delete from favorites table
      await _supabase
          .from('favorites')
          .delete()
          .eq('deed_id', deedId)
          .eq('user_id', userId);
    } else {
      // Favorite: insert into favorites table
      await _supabase
          .from('favorites')
          .insert({
            'id': const Uuid().v4(),
            'deed_id': deedId,
            'user_id': userId,
            'created_at': DateTime.now().toIso8601String(),
          });
      await _xpService.awardXPForFavorite(userId);
    }
  }

  Stream<bool> watchIsFavorited(String deedId, String userId) {
    return _supabase
        .from('favorites')
        .stream(primaryKey: ['id'])
        .map((data) {
          return data.any((item) => 
            item['deed_id'] == deedId && item['user_id'] == userId
          );
        });
  }

  Stream<List<String>> getFavoriteIdsStream(String userId) {
    return _supabase
        .from('favorites')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((data) {
          return data.map((item) => item['deed_id'] as String).toList();
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

    final imageUrl = deedData['image_url'];
    if (imageUrl != null && imageUrl.toString().contains('supabase')) {
      try {
        final uri = Uri.parse(imageUrl);
        final path = uri.pathSegments.last;
        await StorageService.deleteFile(bucket: 'deeds', filePath: path);
      } catch (e) {
        // Silently fail - continue deletion even if image deletion fails
        if (kDebugMode) {
          debugPrint('Error deleting image: $e');
        }
      }
    }

    final mediaUrls = List<String>.from(deedData['media_urls'] ?? []);
    for (final url in mediaUrls) {
      if (url.contains('supabase')) {
        try {
          final uri = Uri.parse(url);
          final path = uri.pathSegments.last;
          await StorageService.deleteFile(bucket: 'deeds', filePath: path);
        } catch (e) {
          // Silently fail - continue deletion even if media deletion fails
          if (kDebugMode) {
            debugPrint('Error deleting media: $e');
          }
        }
      }
    }

    await _supabase
        .from(AppConstants.collectionDeeds)
        .delete()
        .eq('id', deedId);
  }
}
