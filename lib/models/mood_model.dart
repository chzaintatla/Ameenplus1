class MoodModel {
  final String id;
  final String userId;
  final String mood;
  final String? note;
  final DateTime createdAt;

  MoodModel({
    required this.id,
    required this.userId,
    required this.mood,
    this.note,
    required this.createdAt,
  });

  factory MoodModel.fromMap(Map<String, dynamic> data) {
    return MoodModel(
      id: data['id']?.toString() ?? '',
      userId: data['userId'] ?? '',
      mood: data['mood'] ?? 'neutral',
      note: data['note'],
      createdAt: data['createdAt'] is String
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'mood': mood,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class MoodSuggestion {
  final String mood;
  final String contentType; // ayah, hadith, dua
  final String arabicText;
  final String translation;
  final String? reference;

  MoodSuggestion({
    required this.mood,
    required this.contentType,
    required this.arabicText,
    required this.translation,
    this.reference,
  });
}
