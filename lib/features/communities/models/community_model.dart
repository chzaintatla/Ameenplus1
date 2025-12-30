import 'package:cloud_firestore/cloud_firestore.dart';

/// Community model for Islamic community groups
class CommunityModel {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String creatorId;
  final List<String> members;
  final List<String> admins;
  final String category;
  final bool isPublic;
  final int postsCount;
  final int eventsCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CommunityModel({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.creatorId,
    this.members = const [],
    this.admins = const [],
    this.category = 'General',
    this.isPublic = true,
    this.postsCount = 0,
    this.eventsCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory CommunityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CommunityModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      creatorId: data['creatorId'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      admins: List<String>.from(data['admins'] ?? []),
      category: data['category'] ?? 'General',
      isPublic: data['isPublic'] ?? true,
      postsCount: data['postsCount'] ?? 0,
      eventsCount: data['eventsCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'creatorId': creatorId,
      'members': members,
      'admins': admins,
      'category': category,
      'isPublic': isPublic,
      'postsCount': postsCount,
      'eventsCount': eventsCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  bool isMember(String userId) {
    return members.contains(userId);
  }

  bool isAdmin(String userId) {
    return admins.contains(userId);
  }

  int get membersCount => members.length;
}

/// Community Event model
class CommunityEvent {
  final String id;
  final String communityId;
  final String title;
  final String description;
  final DateTime scheduledAt;
  final String? link;
  final String? location;
  final List<String> attendees;
  final DateTime createdAt;

  CommunityEvent({
    required this.id,
    required this.communityId,
    required this.title,
    required this.description,
    required this.scheduledAt,
    this.link,
    this.location,
    this.attendees = const [],
    required this.createdAt,
  });

  factory CommunityEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CommunityEvent(
      id: doc.id,
      communityId: data['communityId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      scheduledAt: (data['scheduledAt'] as Timestamp).toDate(),
      link: data['link'],
      location: data['location'],
      attendees: List<String>.from(data['attendees'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'communityId': communityId,
      'title': title,
      'description': description,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'link': link,
      'location': location,
      'attendees': attendees,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  bool isAttending(String userId) {
    return attendees.contains(userId);
  }

  int get attendeesCount => attendees.length;
}
