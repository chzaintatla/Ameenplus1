import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_constants.dart';

/// Mood model for mood-based Islamic guidance
class MoodModel {
  final String id;
  final String userId;
  final String mood;
  final int intensity; // 1-10
  final String? notes;
  final DateTime timestamp;
  
  MoodModel({
    required this.id,
    required this.userId,
    required this.mood,
    this.intensity = 5,
    this.notes,
    required this.timestamp,
  });
  
  /// Create MoodModel from Firestore document
  factory MoodModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return MoodModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      mood: data['mood'] ?? '',
      intensity: data['intensity'] ?? 5,
      notes: data['notes'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
  
  /// Convert MoodModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'mood': mood,
      'intensity': intensity,
      'notes': notes,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
  
  /// Convert to local database format
  Map<String, dynamic> toLocal() {
    return {
      'id': id,
      'userId': userId,
      'mood': mood,
      'intensity': intensity,
      'notes': notes,
      'timestamp': timestamp.toIso8601String(),
      'syncStatus': 0,
   };
  }
  
  /// Create from local database
  factory MoodModel.fromLocal(Map<String, dynamic> data) {
    return MoodModel(
      id: data['id'],
      userId: data['userId'],
      mood: data['mood'],
      intensity: data['intensity'] ?? 5,
      notes: data['notes'],
      timestamp: DateTime.parse(data['timestamp']),
    );
  }
  
  /// Get mood emoji
  static String getMoodEmoji(String mood) {
    switch (mood) {
      case AppConstants.moodAngry:
        return '😠';
      case AppConstants.moodSad:
        return '😢';
      case AppConstants.moodHappy:
        return '😊';
      case AppConstants.moodStressed:
        return '😰';
      case AppConstants.moodDemotivated:
        return '😔';
      case AppConstants.moodLonely:
        return '😞';
      case AppConstants.moodRepent:
        return '😌';
      case AppConstants.moodLearn:
        return '🤓';
      case AppConstants.moodPeace:
        return '😇';
      default:
        return '😐';
    }
  }
  
  /// Get mood color
  static int getMoodColor(String mood) {
    switch (mood) {
      case AppConstants.moodAngry:
        return 0xFFD32F2F; // Red
      case AppConstants.moodSad:
        return 0xFF1976D2; // Blue
      case AppConstants.moodHappy:
        return 0xFFFFA726; // Orange
      case AppConstants.moodStressed:
        return 0xFF7B1FA2; // Purple
      case AppConstants.moodDemotivated:
        return 0xFF616161; // Gray
      case AppConstants.moodLonely:
        return 0xFF5E35B1; // Deep Purple
      case AppConstants.moodRepent:
        return 0xFF4CAF50; // Green
      case AppConstants.moodLearn:
        return 0xFF00ACC1; // Cyan
      case AppConstants.moodPeace:
        return 0xFF66BB6A; // Light Green
      default:
        return 0xFF9E9E9E; // Gray
    }
  }
  
  /// Get mood display name
  static String getMoodDisplayName(String mood) {
    switch (mood) {
      case AppConstants.moodAngry:
        return 'Angry';
      case AppConstants.moodSad:
        return 'Sad';
      case AppConstants.moodHappy:
        return 'Happy';
      case AppConstants.moodStressed:
        return 'Stressed';
      case AppConstants.moodDemotivated:
        return 'Demotivated';
      case AppConstants.moodLonely:
        return 'Lonely';
      case AppConstants.moodRepent:
        return 'Want to Repent';
      case AppConstants.moodLearn:
        return 'Want to Learn';
      case AppConstants.moodPeace:
        return 'Seeking Peace';
      default:
        return 'Unknown';
    }
  }
}

/// Islamic content suggestion based on mood
class MoodSuggestion {
  final String id;
  final String mood;
  final String contentType; // ayah, hadith, dua, quote, sunnah
  final String arabicText;
  final String translation;
  final String? transliteration;
  final String? reference;
  final String? category;
  
  MoodSuggestion({
    required this.id,
    required this.mood,
    required this.contentType,
    required this.arabicText,
    required this.translation,
    this.transliteration,
    this.reference,
    this.category,
  });
  
  /// Convert to local database format
  Map<String, dynamic> toLocal() {
    return {
      'id': id,
      'mood': mood,
      'contentType': contentType,
      'content': arabicText,
      'translation': translation,
      'reference': reference,
      'cachedAt': DateTime.now().toIso8601String(),
    };
  }
  
  /// Create from local database
  factory MoodSuggestion.fromLocal(Map<String, dynamic> data) {
    return MoodSuggestion(
      id: data['id'],
      mood: data['mood'],
      contentType: data['contentType'],
      arabicText: data['content'],
      translation: data['translation'],
      reference: data['reference'],
    );
  }
}

/// Predefined mood suggestions data
class MoodSuggestionsData {
  /// Get suggestions for a specific mood
  static List<MoodSuggestion> getSuggestions(String mood) {
    switch (mood) {
      case AppConstants.moodAngry:
        return _angrySuggestions;
      case AppConstants.moodSad:
        return _sadSuggestions;
      case AppConstants.moodHappy:
        return _happySuggestions;
      case AppConstants.moodStressed:
        return _stressedSuggestions;
      case AppConstants.moodDemotivated:
        return _demotivatedSuggestions;
      case AppConstants.moodLonely:
        return _lonelySuggestions;
      case AppConstants.moodRepent:
        return _repentSuggestions;
      case AppConstants.moodLearn:
        return _learnSuggestions;
      case AppConstants.moodPeace:
        return _peaceSuggestions;
      default:
        return [];
    }
  }
  
  static final List<MoodSuggestion> _angrySuggestions = [
    MoodSuggestion(
      id: '1',
      mood: AppConstants.moodAngry,
      contentType: 'hadith',
      arabicText: 'لَا تَغْضَبْ',
      translation: 'Do not get angry.',
      reference: 'Sahih Bukhari 6116',
      category: 'anger',
    ),
    MoodSuggestion(
      id: '2',
      mood: AppConstants.moodAngry,
      contentType: 'ayah',
      arabicText: 'وَالْكَاظِمِينَ الْغَيْظَ وَالْعَافِينَ عَنِ النَّاسِ',
      translation: 'Those who restrain anger and pardon people - and Allah loves the doers of good.',
      reference: 'Quran 3:134',
      category: 'patience',
    ),
    MoodSuggestion(
      id: '3',
      mood: AppConstants.moodAngry,
      contentType: 'sunnah',
      arabicText: 'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ',
      translation: 'Seek refuge in Allah from Satan when angry, and perform wudu.',
      reference: 'Abu Dawud 4784',
      category: 'remedy',
    ),
  ];
  
  static final List<MoodSuggestion> _sadSuggestions = [
    MoodSuggestion(
      id: '4',
      mood: AppConstants.moodSad,
      contentType: 'ayah',
      arabicText: 'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا',
      translation: 'Indeed, with hardship comes ease.',
      reference: 'Quran 94:5',
      category: 'hope',
    ),
    MoodSuggestion(
      id: '5',
      mood: AppConstants.moodSad,
      contentType: 'dua',
      arabicText: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ',
      translation: 'O Allah, I seek refuge in You from worry and grief.',
      reference: 'Sahih Bukhari 6369',
      category: 'relief',
    ),
    MoodSuggestion(
      id: '5a',
      mood: AppConstants.moodSad,
      contentType: 'ayah',
      arabicText: 'وَلَا تَحْزَنْ إِنَّ اللَّهَ مَعَنَا',
      translation: 'And do not grieve; indeed Allah is with us.',
      reference: 'Quran 9:40',
      category: 'comfort',
    ),
    MoodSuggestion(
      id: '5b',
      mood: AppConstants.moodSad,
      contentType: 'hadith',
      arabicText: 'مَا يُصِيبُ الْمُسْلِمَ مِنْ نَصَبٍ وَلَا وَصَبٍ وَلَا هَمٍّ وَلَا حُزْنٍ إِلَّا كُفِّرَ عَنْهُ',
      translation: 'No fatigue, disease, sorrow, sadness, or hurt befalls a Muslim, even if it were the prick of a thorn, except that Allah expiates some of his sins.',
      reference: 'Sahih Bukhari 5641',
      category: 'reward',
    ),
  ];
  
  static final List<MoodSuggestion> _happySuggestions = [
    MoodSuggestion(
      id: '6',
      mood: AppConstants.moodHappy,
      contentType: 'ayah',
      arabicText: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
      translation: 'All praise is due to Allah, Lord of the worlds.',
      reference: 'Quran 1:2',
      category: 'gratitude',
    ),
    MoodSuggestion(
      id: '6a',
      mood: AppConstants.moodHappy,
      contentType: 'hadith',
      arabicText: 'مَنْ لَمْ يَشْكُرِ النَّاسَ لَمْ يَشْكُرِ اللَّهَ',
      translation: 'He who does not thank people, does not thank Allah.',
      reference: 'Tirmidhi 1954',
      category: 'gratitude',
    ),
    MoodSuggestion(
      id: '6b',
      mood: AppConstants.moodHappy,
      contentType: 'ayah',
      arabicText: 'وَإِن تَعُدُّوا نِعْمَةَ اللَّهِ لَا تُحْصُوهَا',
      translation: 'And if you should count the favors of Allah, you could not enumerate them.',
      reference: 'Quran 16:18',
      category: 'blessings',
    ),
  ];
  
  static final List<MoodSuggestion> _stressedSuggestions = [
    MoodSuggestion(
      id: '7',
      mood: AppConstants.moodStressed,
      contentType: 'ayah',
      arabicText: 'لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا',
      translation: 'Allah does not burden a soul beyond what it can bear.',
      reference: 'Quran 2:286',
      category: 'relief',
    ),
    MoodSuggestion(
      id: '7a',
      mood: AppConstants.moodStressed,
      contentType: 'dua',
      arabicText: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ وَالْعَجْزِ وَالْكَسَلِ',
      translation: 'O Allah, I seek refuge in You from worry, grief, incapacity, laziness.',
      reference: 'Sahih Bukhari 6369',
      category: 'protection',
    ),
    MoodSuggestion(
      id: '7b',
      mood: AppConstants.moodStressed,
      contentType: 'ayah',
      arabicText: 'وَمَن يَتَّقِ اللَّهَ يَجْعَل لَّهُ مَخْرَجًا',
      translation: 'And whoever fears Allah - He will make for him a way out.',
      reference: 'Quran 65:2',
      category: 'relief',
    ),
  ];
  
  static final List<MoodSuggestion> _demotivatedSuggestions = [
    MoodSuggestion(
      id: '8',
      mood: AppConstants.moodDemotivated,
      contentType: 'hadith',
      arabicText: 'وَأَخِّرُوا الْمَكْرُوهَ بِحَسَنَةٍ تَمْحُوهَا',
      translation: 'And follow up a bad deed with a good deed and it will wipe it out.',
      reference: 'Tirmidhi 1987',
      category: 'motivation',
    ),
    MoodSuggestion(
      id: '8a',
      mood: AppConstants.moodDemotivated,
      contentType: 'ayah',
      arabicText: 'وَلَا تَهِنُوا وَلَا تَحْزَنُوا وَأَنتُمُ الْأَعْلَوْنَ إِن كُنتُم مُّؤْمِنِينَ',
      translation: 'So do not weaken and do not grieve, and you will be superior if you are believers.',
      reference: 'Quran 3:139',
      category: 'strength',
    ),
    MoodSuggestion(
      id: '8b',
      mood: AppConstants.moodDemotivated,
      contentType: 'hadith',
      arabicText: 'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ',
      translation: 'Actions are but by intention.',
      reference: 'Sahih Bukhari 1',
      category: 'intention',
    ),
  ];
  
  static final List<MoodSuggestion> _lonelySuggestions = [
    MoodSuggestion(
      id: '9',
      mood: AppConstants.moodLonely,
      contentType: 'ayah',
      arabicText: 'وَهُوَ مَعَكُمْ أَيْنَ مَا كُنتُمْ',
      translation: 'And He is with you wherever you are.',
      reference: 'Quran 57:4',
      category: 'companionship',
    ),
    MoodSuggestion(
      id: '9a',
      mood: AppConstants.moodLonely,
      contentType: 'ayah',
      arabicText: 'أَلَا إِنَّ أَوْلِيَاءَ اللَّهِ لَا خَوْفٌ عَلَيْهِمْ وَلَا هُمْ يَحْزَنُونَ',
      translation: 'Unquestionably, the friends of Allah have no fear, nor will they grieve.',
      reference: 'Quran 10:62',
      category: 'comfort',
    ),
    MoodSuggestion(
      id: '9b',
      mood: AppConstants.moodLonely,
      contentType: 'hadith',
      arabicText: 'الْمُؤْمِنُ لِلْمُؤْمِنِ كَالْبُنْيَانِ يَشُدُّ بَعْضُهُ بَعْضًا',
      translation: 'A believer to another believer is like a building whose different parts enforce each other.',
      reference: 'Sahih Bukhari 481',
      category: 'brotherhood',
    ),
  ];
  
  static final List<MoodSuggestion> _repentSuggestions = [
    MoodSuggestion(
      id: '10',
      mood: AppConstants.moodRepent,
      contentType: 'ayah',
      arabicText: 'قُلْ يَا عِبَادِيَ الَّذِينَ أَسْرَفُوا عَلَىٰ أَنفُسِهِمْ لَا تَقْنَطُوا مِن رَّحْمَةِ اللَّهِ',
      translation: 'Say, O My servants who have transgressed against themselves, do not despair of the mercy of Allah.',
      reference: 'Quran 39:53',
      category: 'forgiveness',
    ),
    MoodSuggestion(
      id: '10a',
      mood: AppConstants.moodRepent,
      contentType: 'dua',
      arabicText: 'رَبِّ إِنِّي ظَلَمْتُ نَفْسِي فَاغْفِرْ لِي',
      translation: 'My Lord, indeed I have wronged myself, so forgive me.',
      reference: 'Quran 28:16',
      category: 'repentance',
    ),
    MoodSuggestion(
      id: '10b',
      mood: AppConstants.moodRepent,
      contentType: 'hadith',
      arabicText: 'التَّائِبُ مِنَ الذَّنْبِ كَمَنْ لَا ذَنْبَ لَهُ',
      translation: 'The one who repents from sin is like one who has no sin.',
      reference: 'Ibn Majah 4250',
      category: 'forgiveness',
    ),
  ];
  
  static final List<MoodSuggestion> _learnSuggestions = [
    MoodSuggestion(
      id: '11',
      mood: AppConstants.moodLearn,
      contentType: 'ayah',
      arabicText: 'وَقُل رَّبِّ زِدْنِي عِلْمًا',
      translation: 'And say, My Lord, increase me in knowledge.',
      reference: 'Quran 20:114',
      category: 'knowledge',
    ),
    MoodSuggestion(
      id: '11a',
      mood: AppConstants.moodLearn,
      contentType: 'hadith',
      arabicText: 'طَلَبُ الْعِلْمِ فَرِيضَةٌ عَلَى كُلِّ مُسْلِمٍ',
      translation: 'Seeking knowledge is obligatory upon every Muslim.',
      reference: 'Ibn Majah 224',
      category: 'obligation',
    ),
    MoodSuggestion(
      id: '11b',
      mood: AppConstants.moodLearn,
      contentType: 'ayah',
      arabicText: 'يَرْفَعِ اللَّهُ الَّذِينَ آمَنُوا مِنكُمْ وَالَّذِينَ أُوتُوا الْعِلْمَ دَرَجَاتٍ',
      translation: 'Allah will raise those who have believed among you and those who were given knowledge by degrees.',
      reference: 'Quran 58:11',
      category: 'reward',
    ),
  ];
  
  static final List<MoodSuggestion> _peaceSuggestions = [
    MoodSuggestion(
      id: '12',
      mood: AppConstants.moodPeace,
      contentType: 'ayah',
      arabicText: 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
      translation: 'Verily, in the remembrance of Allah do hearts find rest.',
      reference: 'Quran 13:28',
      category: 'peace',
    ),
    MoodSuggestion(
      id: '12a',
      mood: AppConstants.moodPeace,
      contentType: 'ayah',
      arabicText: 'هُوَ اللَّهُ الَّذِي لَا إِلَٰهَ إِلَّا هُوَ الْمَلِكُ الْقُدُّوسُ السَّلَامُ',
      translation: 'He is Allah, other than whom there is no deity, the Sovereign, the Pure, the Perfection.',
      reference: 'Quran 59:23',
      category: 'divine',
    ),
    MoodSuggestion(
      id: '12b',
      mood: AppConstants.moodPeace,
      contentType: 'dua',
      arabicText: 'اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ',
      translation: 'O Allah, You are Peace and from You comes peace.',
      reference: 'Sahih Muslim 592',
      category: 'supplication',
    ),
  ];
}

