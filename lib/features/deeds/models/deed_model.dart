import 'package:cloud_firestore/cloud_firestore.dart';

/// Deed model representing a shared Islamic deed (Ayah, Hadith, Quote, Task)
class DeedModel {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String deedType; // ayah, hadith, quote, task, general
  final String content;
  final String? arabicText;
  final String? translation;
  final String? reference;
  final String? category;
  final String? imageUrl;
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
    this.likes = const [],
    this.commentsCount = 0,
    this.sharesCount = 0,
    required this.createdAt,
    this.updatedAt,
  });
  
  /// Create DeedModel from Firestore document
  factory DeedModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return DeedModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userPhotoUrl: data['userPhotoUrl'],
      deedType: data['deedType'] ?? 'general',
      content: data['content'] ?? '',
      arabicText: data['arabicText'],
      translation: data['translation'],
      reference: data['reference'],
      category: data['category'],
      imageUrl: data['imageUrl'],
      likes: List<String>.from(data['likes'] ?? []),
      commentsCount: data['commentsCount'] ?? 0,
      sharesCount: data['sharesCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
  
  /// Convert DeedModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'deedType': deedType,
      'content': content,
      'arabicText': arabicText,
      'translation': translation,
      'reference': reference,
      'category': category,
      'imageUrl': imageUrl,
      'likes': likes,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
  
  /// Convert to local database format
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
  
  /// Create from local database
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
      likes: [], // Likes not stored fully in local cache
      commentsCount: data['commentsCount'] ?? 0,
      sharesCount: data['sharesCount'] ?? 0,
      createdAt: DateTime.parse(data['createdAt']),
    );
  }
  
  /// Create a copy with updated fields
  DeedModel copyWith({
    String? userName,
    String? userPhotoUrl,
    String? content,
    String? arabicText,
    String? translation,
    String? reference,
    String? category,
    String? imageUrl,
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
      likes: likes ?? this.likes,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  /// Check if user has liked this deed
  bool isLikedBy(String userId) {
    return likes.contains(userId);
  }
  
  /// Get likes count
  int get likesCount => likes.length;
}
