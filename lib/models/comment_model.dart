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

  bool isLikedBy(String userId) => likes.contains(userId);
  int get likesCount => likes.length;

  factory CommentModel.fromMap(Map<String, dynamic> data) {
    return CommentModel(
      id: data['id']?.toString() ?? '',
      deedId: data['deed_id'] ?? data['deedId'] ?? '',
      userId: data['user_id'] ?? data['userId'] ?? '',
      userName: data['user_name'] ?? data['userName'] ?? 'Anonymous',
      userPhotoUrl: data['user_photo_url'] ?? data['userPhotoUrl'],
      content: data['content'] ?? '',
      likes: List<String>.from(data['likes'] ?? []),
      createdAt: data['created_at'] != null
          ? (data['created_at'] is String ? DateTime.parse(data['created_at']) : data['created_at'] as DateTime)
          : (data['createdAt'] is String ? DateTime.parse(data['createdAt']) : DateTime.now()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deed_id': deedId,
      'user_id': userId,
      'user_name': userName,
      'user_photo_url': userPhotoUrl,
      'content': content,
      'likes': likes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
