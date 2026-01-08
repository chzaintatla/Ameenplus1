class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String? body;
  final String? actionId;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.body,
    this.actionId,
    this.read = false,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> data) {
    return NotificationModel(
      id: data['id']?.toString() ?? '',
      userId: data['user_id'] ?? data['userId'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      body: data['body'],
      actionId: data['action_id'] ?? data['actionId'],
      read: data['read'] ?? false,
      createdAt: data['created_at'] != null
          ? (data['created_at'] is String ? DateTime.parse(data['created_at']) : data['created_at'] as DateTime)
          : (data['createdAt'] is String ? DateTime.parse(data['createdAt']) : DateTime.now()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'title': title,
      'body': body,
      'action_id': actionId,
      'read': read,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    bool? read,
  }) {
    return NotificationModel(
      id: id,
      userId: userId,
      type: type,
      title: title,
      body: body,
      actionId: actionId,
      read: read ?? this.read,
      createdAt: createdAt,
    );
  }
}
