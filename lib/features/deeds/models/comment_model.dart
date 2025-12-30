import 'package:cloud_firestore/cloud_firestore.dart';

/// Comment model for deed comments
class CommentModel {
  final String id;
  final String deedId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String content;
  final List<String> likes;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.deedId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.content,
    this.likes = const [],
    required this.createdAt,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CommentModel(
      id: doc.id,
      deedId: data['deedId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userPhotoUrl: data['userPhotoUrl'],
      content: data['content'] ?? '',
      likes: List<String>.from(data['likes'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deedId': deedId,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'content': content,
      'likes': likes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  bool isLikedBy(String userId) {
    return likes.contains(userId);
  }

  int get likesCount => likes.length;
}
