class IslamicRAGService {
  /// Basic knowledge base - In production, this would be in a vector DB
  /// This is a simplified example with key Islamic concepts
  static const Map<String, List<String>> _knowledgeBase = {
    'salah': [
      'Quran 2:3 - "Who believe in the unseen, establish prayer, and spend out of what We have provided for them"',
      'Sahih Bukhari - The Prophet (PBUH) said: "The first matter that the slave will be brought to account for on the Day of Judgment is the prayer. If it is sound, then the rest of his deeds will be sound."',
    ],
    'zakat': [
      'Quran 2:43 - "And establish prayer and give zakah and bow with those who bow"',
      'Sahih Muslim - The Prophet (PBUH) said: "Charity does not decrease wealth."',
    ],
    'ramadan': [
      'Quran 2:185 - "The month of Ramadan [is that] in which was revealed the Qur\'an, a guidance for the people"',
      'Sahih Bukhari - The Prophet (PBUH) said: "When Ramadan enters, the gates of Paradise are opened."',
    ],
    'hajj': [
      'Quran 3:97 - "And [due] to Allah from the people is a pilgrimage to the House - for whoever is able to find thereto a way"',
      'Sahih Muslim - The Prophet (PBUH) said: "Whoever performs Hajj and does not commit any obscenity or transgression will return [free from sins] as the day his mother gave birth to him."',
    ],
    'dua': [
      'Quran 40:60 - "And your Lord says, \'Call upon Me; I will respond to you.\'"',
      'Sahih Muslim - The Prophet (PBUH) said: "Dua is the essence of worship."',
    ],
    'dhikr': [
      'Quran 33:41-42 - "O you who have believed, remember Allah with much remembrance. And exalt Him morning and afternoon."',
      'Sahih Bukhari - The Prophet (PBUH) said: "The example of the one who remembers Allah and the one who does not is like that of the living and the dead."',
    ],
  };

  /// Retrieve relevant Islamic context for a query
  /// Returns context string to inject into prompt
  static String retrieveContext(String query) {
    final lowerQuery = query.toLowerCase();
    final contexts = <String>[];
    
    // Simple keyword matching (in production, use semantic search)
    for (final entry in _knowledgeBase.entries) {
      if (lowerQuery.contains(entry.key)) {
        contexts.addAll(entry.value);
      }
    }
    
    // If no specific match, return general Islamic guidance
    if (contexts.isEmpty) {
      return '''
Context from Islamic sources:
- Always refer to Quran and authentic Hadith
- If unsure, say "Allah knows best"
- Maintain respectful and accurate Islamic guidance
''';
    }
    
    return '''
Relevant Islamic Context:
${contexts.join('\n\n')}

Use this context to provide accurate Islamic guidance. If the question is not fully answered by this context, say "Allah knows best" for matters not explicitly covered.
''';
  }

  /// Check if query is about Islamic topics
  static bool isIslamicTopic(String query) {
    final lowerQuery = query.toLowerCase();
    
    final islamicKeywords = [
      'islam',
      'muslim',
      'quran',
      'qur\'an',
      'hadith',
      'sunnah',
      'salah',
      'prayer',
      'zakah',
      'zakat',
      'ramadan',
      'hajj',
      'umrah',
      'dua',
      'dhikr',
      'islamic',
      'halal',
      'haram',
      'prophet',
      'muhammad',
      'allah',
      'deen',
      'iman',
      'taqwa',
    ];
    
    return islamicKeywords.any((keyword) => lowerQuery.contains(keyword));
  }
}

