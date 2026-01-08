class FriendModel {
  final String id;
  final String userId;
  final String friendId;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  FriendModel({
    required this.id,
    required this.userId,
    required this.friendId,
    this.status = 'pending',
    required this.createdAt,
    this.updatedAt,
  });

  factory FriendModel.fromMap(Map<String, dynamic> data) {
    return FriendModel(
      id: data['id']?.toString() ?? '',
      userId: data['user_id'] ?? data['userId'] ?? '',
      friendId: data['friend_id'] ?? data['friendId'] ?? '',
      status: data['status'] ?? 'pending',
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
      'friend_id': friendId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
}
