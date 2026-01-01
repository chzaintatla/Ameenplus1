import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'userId': userId,
      'userName': userName,
      'deedType': deedType,
      'content': content,
      'likes': likes,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };

    if (userPhotoUrl != null) {
      map['userPhotoUrl'] = userPhotoUrl;
    }
    if (arabicText != null) {
      map['arabicText'] = arabicText;
    }
    if (translation != null) {
      map['translation'] = translation;
    }
    if (reference != null) {
      map['reference'] = reference;
    }
    if (category != null) {
      map['category'] = category;
    }
    if (imageUrl != null) {
      map['imageUrl'] = imageUrl;
    }
    if (updatedAt != null) {
      map['updatedAt'] = Timestamp.fromDate(updatedAt!);
    }

    return map;
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
}
