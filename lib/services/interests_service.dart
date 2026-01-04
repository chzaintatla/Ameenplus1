import 'package:cloud_firestore/cloud_firestore.dart';

class InterestsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const List<String> trendingInterests = [
    'Quran',
    'Hadith',
    'Salah',
    'Dhikr',
    'Dua',
    'Islamic Learning',
    'Charity',
    'Hajj & Umrah',
    'Ramadan',
    'Islamic History',
  ];

  Future<List<String>> getTrendingInterests({int limit = 10}) async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final postsSnapshot = await _firestore
          .collection('deeds')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final interestCounts = <String, int>{};

      for (final doc in postsSnapshot.docs) {
        final data = doc.data();
        final interests = List<String>.from(data['interests'] ?? []);
        for (final interest in interests) {
          interestCounts[interest] = (interestCounts[interest] ?? 0) + 1;
        }
      }

      final sortedInterests = interestCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final trending = sortedInterests
          .take(limit)
          .map((e) => e.key)
          .toList();

      final defaultInterests = trendingInterests
          .where((interest) => !trending.contains(interest))
          .take(limit - trending.length)
          .toList();

      return [...trending, ...defaultInterests].take(limit).toList();
    } catch (e) {
      return trendingInterests.take(limit).toList();
    }
  }

  Future<void> incrementInterestCount(String interest) async {
    try {
      await _firestore
          .collection('interests')
          .doc(interest.toLowerCase().replaceAll(' ', '_'))
          .set({
        'name': interest,
        'count': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Handle error silently
    }
  }

  Future<List<String>> searchInterests(String query) async {
    try {
      if (query.isEmpty) {
        return trendingInterests;
      }

      final queryLower = query.toLowerCase();
      return trendingInterests
          .where((interest) => interest.toLowerCase().contains(queryLower))
          .toList();
    } catch (e) {
      return [];
    }
  }
}

