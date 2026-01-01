import 'package:cloud_firestore/cloud_firestore.dart';

/// Friend request status enum
enum FriendRequestStatus {
  pending,
  accepted,
  rejected,
}

/// Friend request model
class FriendRequestModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String receiverId;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  FriendRequestModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.receiverId,
    this.status = FriendRequestStatus.pending,
    required this.createdAt,
    this.respondedAt,
  });

  factory FriendRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    String statusString = data['status'] ?? 'pending';
    FriendRequestStatus status = FriendRequestStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusString,
      orElse: () => FriendRequestStatus.pending,
    );

    return FriendRequestModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Anonymous',
      senderPhotoUrl: data['senderPhotoUrl'],
      receiverId: data['receiverId'] ?? '',
      status: status,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      respondedAt: data['respondedAt'] != null
          ? (data['respondedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'receiverId': receiverId,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }

  FriendRequestModel accept() {
    return FriendRequestModel(
      id: id,
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      receiverId: receiverId,
      status: FriendRequestStatus.accepted,
      createdAt: createdAt,
      respondedAt: DateTime.now(),
    );
  }

  FriendRequestModel reject() {
    return FriendRequestModel(
      id: id,
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      receiverId: receiverId,
      status: FriendRequestStatus.rejected,
      createdAt: createdAt,
      respondedAt: DateTime.now(),
    );
  }

  bool get isPending => status == FriendRequestStatus.pending;
  bool get isAccepted => status == FriendRequestStatus.accepted;
  bool get isRejected => status == FriendRequestStatus.rejected;
}

/// Friend model (simplified user model for friends list)
class FriendModel {
  final String userId;
  final String displayName;
  final String? profilePicture;
  final int xp;
  final int level;
  final List<String> badges;
  final bool isOnline;
  final DateTime? lastActive;
  final DateTime friendsSince;

  FriendModel({
    required this.userId,
    required this.displayName,
    this.profilePicture,
    this.xp = 0,
    this.level = 1,
    this.badges = const [],
    this.isOnline = false,
    this.lastActive,
    required this.friendsSince,
  });

  factory FriendModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return FriendModel(
      userId: doc.id,
      displayName: data['displayName'] ?? 'Anonymous',
      profilePicture: data['profilePicture'],
      xp: data['xp'] ?? 0,
      level: data['level'] ?? 1,
      badges: List<String>.from(data['badges'] ?? []),
      isOnline: data['isOnline'] ?? false,
      lastActive: data['lastActive'] != null
          ? (data['lastActive'] as Timestamp).toDate()
          : null,
      friendsSince: data['friendsSince'] != null
          ? (data['friendsSince'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'profilePicture': profilePicture,
      'xp': xp,
      'level': level,
      'badges': badges,
      'isOnline': isOnline,
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      'friendsSince': Timestamp.fromDate(friendsSince),
    };
  }

  /// Convert to local database format
  Map<String, dynamic> toLocal() {
    return {
      'id': userId,
      'userId': userId,
      'userName': displayName,
      'userPhotoUrl': profilePicture,
      'status': 'active',
      'xpPoints': xp,
      'level': level,
      'cachedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Create from local database
  factory FriendModel.fromLocal(Map<String, dynamic> data) {
    return FriendModel(
      userId: data['userId'],
      displayName: data['userName'] ?? 'Anonymous',
      profilePicture: data['userPhotoUrl'],
      xp: data['xpPoints'] ?? 0,
      level: data['level'] ?? 1,
      friendsSince: DateTime.now(), // Default
    );
  }
}

