class CommunityModel {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final List<String> members;
  final List<String> admins;
  final String createdBy; // This is the 'creator_id' or 'created_by'
  final String category;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CommunityModel({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    this.members = const [],
    this.admins = const [],
    required this.createdBy,
    this.category = 'General',
    this.isPublic = true,
    required this.createdAt,
    this.updatedAt,
  });

  // Alias for backward compatibility or UI consistency
  String get creatorId => createdBy;

  factory CommunityModel.fromMap(Map<String, dynamic> data) {
    return CommunityModel(
      id: data['id']?.toString() ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['image_url'] ?? data['imageUrl'],
      members: List<String>.from(data['members'] ?? []),
      admins: List<String>.from(data['admins'] ?? data['admin_ids'] ?? []),
      createdBy: data['created_by'] ?? data['creator_id'] ?? data['createdBy'] ?? '',
      category: data['category'] ?? 'General',
      isPublic: (data['is_public'] ?? data['isPublic']) as bool? ?? true,
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
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'members': members,
      'admins': admins,
      'created_by': createdBy,
      'category': category,
      'is_public': isPublic,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
