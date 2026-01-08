class DailyDeed {
  final String name;
  final String description;
  final String connection;
  final String benefit;
  final List<String> interests;

  DailyDeed({
    required this.name,
    required this.description,
    required this.connection,
    required this.benefit,
    required this.interests,
  });

  factory DailyDeed.fromMap(Map<String, dynamic> map) {
    return DailyDeed(
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      connection: map['connection'] ?? '',
      benefit: map['benefit'] ?? '',
      interests: List<String>.from(map['interests'] ?? []),
    );
  }
}
