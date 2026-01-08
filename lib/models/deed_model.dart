
class DeedModel {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String deedType;
  final String content;
  final String? arabicText;
  final String? translation;
  final String? reference;
  final String? category;
  final String? imageUrl;
  final List<String> mediaUrls; // Support multiple media types
  final String? mediaType; // 'image', 'video', 'pdf', 'audio', 'document'
  final List<String> interests; // Post interest tags
  final bool isValidated; // AI validation status
  final String? validationReason;
  final double? validationConfidence;
  final List<String> likes;
  final int commentsCount;
  final int sharesCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DeedModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.deedType,
    required this.content,
    this.arabicText,
    this.translation,
    this.reference,
    this.category,
    this.imageUrl,
    this.mediaUrls = const [],
    this.mediaType,
    this.interests = const [],
    this.isValidated = false,
    this.validationReason,
    this.validationConfidence,
    this.likes = const [],
    this.commentsCount = 0,
    this.sharesCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory DeedModel.fromMap(Map<String, dynamic> data) {
    return DeedModel(
      id: data['id']?.toString() ?? '',
      userId: data['user_id'] ?? data['userId'] ?? '',
      userName: data['user_name'] ?? data['userName'] ?? 'Anonymous',
      userPhotoUrl: data['user_photo_url'] ?? data['userPhotoUrl'],
      deedType: data['deed_type'] ?? data['deedType'] ?? 'general',
      content: data['content'] ?? '',
      arabicText: data['arabic_text'] ?? data['arabicText'],
      translation: data['translation'],
      reference: data['reference'],
      category: data['category'],
      imageUrl: data['image_url'] ?? data['imageUrl'],
      mediaUrls: List<String>.from(data['media_urls'] ?? data['mediaUrls'] ?? []),
      mediaType: data['media_type'] as String? ?? data['mediaType'] as String?,
      interests: List<String>.from(data['interests'] ?? []),
      isValidated: (data['is_validated'] ?? data['isValidated']) as bool? ?? false,
      validationReason: data['validation_reason'] ?? data['validationReason'] as String?,
      validationConfidence: (data['validation_confidence'] ?? data['validationConfidence'] as num?)?.toDouble(),
      likes: List<String>.from(data['likes'] ?? []),
      commentsCount: data['comments_count'] ?? data['commentsCount'] ?? 0,
      sharesCount: data['shares_count'] ?? data['sharesCount'] ?? 0,
      createdAt: data['created_at'] != null
          ? (data['created_at'] is String ? DateTime.parse(data['created_at']) : data['created_at'] as DateTime)
          : (data['createdAt'] is String ? DateTime.parse(data['createdAt']) : DateTime.now()),
      updatedAt: data['updated_at'] != null
          ? (data['updated_at'] is String ? DateTime.parse(data['updated_at']) : data['updated_at'] as DateTime?)
          : (data['updatedAt'] != null 
              ? (data['updatedAt'] is String ? DateTime.parse(data['updatedAt']) : data['updatedAt'] as DateTime?)
              : null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'deed_type': deedType,
      'content': content,
      'likes': likes,
      'comments_count': commentsCount,
      'shares_count': sharesCount,
      'created_at': createdAt.toIso8601String(),
      'user_photo_url': userPhotoUrl,
      'arabic_text': arabicText,
      'translation': translation,
      'reference': reference,
      'category': category,
      'image_url': imageUrl,
      'media_urls': mediaUrls,
      'media_type': mediaType,
      'interests': interests,
      'is_validated': isValidated,
      'validation_reason': validationReason,
      'validation_confidence': validationConfidence,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toLocal() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'deedType': deedType,
      'content': content,
      'category': category,
      'imageUrl': imageUrl,
      'likesCount': likes.length,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'isLiked': 0,
      'createdAt': createdAt.toIso8601String(),
      'cachedAt': DateTime.now().toIso8601String(),
    };
  }

  factory DeedModel.fromLocal(Map<String, dynamic> data) {
    return DeedModel(
      id: data['id'],
      userId: data['userId'],
      userName: data['userName'] ?? 'Anonymous',
      userPhotoUrl: data['userPhotoUrl'],
      deedType: data['deedType'],
      content: data['content'],
      category: data['category'],
      imageUrl: data['imageUrl'],
      likes: [],
      commentsCount: data['commentsCount'] ?? 0,
      sharesCount: data['sharesCount'] ?? 0,
      createdAt: DateTime.parse(data['createdAt']),
    );
  }

  bool isLikedBy(String userId) {
    return likes.contains(userId);
  }

  int get likesCount => likes.length;

  DeedModel copyWith({
    String? userName,
    String? userPhotoUrl,
    String? content,
    String? arabicText,
    String? translation,
    String? reference,
    String? category,
    String? imageUrl,
    List<String>? mediaUrls,
    String? mediaType,
    List<String>? interests,
    bool? isValidated,
    String? validationReason,
    double? validationConfidence,
    List<String>? likes,
    int? commentsCount,
    int? sharesCount,
    DateTime? updatedAt,
  }) {
    return DeedModel(
      id: id,
      userId: userId,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      deedType: deedType,
      content: content ?? this.content,
      arabicText: arabicText ?? this.arabicText,
      translation: translation ?? this.translation,
      reference: reference ?? this.reference,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaType: mediaType ?? this.mediaType,
      interests: interests ?? this.interests,
      isValidated: isValidated ?? this.isValidated,
      validationReason: validationReason ?? this.validationReason,
      validationConfidence: validationConfidence ?? this.validationConfidence,
      likes: likes ?? this.likes,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
