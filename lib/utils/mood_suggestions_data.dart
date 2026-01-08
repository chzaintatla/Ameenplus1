import '../models/mood_model.dart';
import 'app_constants.dart';

class MoodSuggestionsData {
  static List<MoodSuggestion> getSuggestions(String mood) {
    if (_suggestions.containsKey(mood)) {
      return _suggestions[mood]!;
    }
    return [
      MoodSuggestion(
        mood: mood,
        contentType: 'ayah',
        arabicText: 'Ø¥ÙÙ†ÙŽÙ‘ Ù…ÙŽØ¹ÙŽ Ø§Ù„Ù’Ø¹ÙØ³Ù’Ø±Ù ÙŠÙØ³Ù’Ø±Ù‹Ø§',
        translation: 'Indeed, with hardship [will be] ease.',
        reference: 'Quran 94:6',
      )
    ];
  }

  static final Map<String, List<MoodSuggestion>> _suggestions = {
    AppConstants.moodAngry: [
      MoodSuggestion(
        mood: AppConstants.moodAngry,
        contentType: 'hadith',
        arabicText: 'Ù„ÙŽÙŠÙ’Ø³ÙŽ Ø§Ù„Ø´ÙŽÙ‘Ø¯ÙÙŠØ¯Ù Ø¨ÙØ§Ù„ØµÙÙ‘Ø±ÙŽØ¹ÙŽØ©ÙØŒ Ø¥ÙÙ†ÙŽÙ‘Ù…ÙŽØ§ Ø§Ù„Ø´ÙŽÙ‘Ø¯ÙÙŠØ¯Ù Ø§Ù„ÙŽÙ‘Ø°ÙÙŠ ÙŠÙŽÙ…Ù’Ù„ÙÙƒÙ Ù†ÙŽÙÙ’Ø³ÙŽÙ‡Ù Ø¹ÙÙ†Ù’Ø¯ÙŽ Ø§Ù„Ù’ØºÙŽØ¶ÙŽØ¨Ù',
        translation: 'The strong is not the one who overcomes the people by his strength, but the strong is the one who controls himself while in anger.',
        reference: 'Sahih Bukhari',
      ),
      MoodSuggestion(
        mood: AppConstants.moodAngry,
        contentType: 'dua',
        arabicText: 'Ø£ÙŽØ¹ÙÙˆØ°Ù Ø¨ÙØ§Ù„Ù„Ù‡Ù Ù…ÙÙ†ÙŽ Ø§Ù„Ø´Ù‘ÙŽÙŠÙ’Ø·ÙŽØ§Ù†Ù Ø§Ù„Ø±Ù‘ÙŽØ¬ÙÙŠÙ…Ù',
        translation: 'I seek refuge in Allah from Shaitan, the accursed.',
        reference: 'Sunan Abi Dawud',
      ),
    ],
    AppConstants.moodSad: [
      MoodSuggestion(
        mood: AppConstants.moodSad,
        contentType: 'ayah',
        arabicText: 'Ù„ÙŽØ§ ØªÙŽØ­Ù’Ø²ÙŽÙ†Ù’ Ø¥ÙÙ†ÙŽÙ‘ Ø§Ù„Ù„ÙŽÙ‘Ù‡ÙŽ Ù…ÙŽØ¹ÙŽÙ†ÙŽØ§',
        translation: 'Do not grieve; indeed Allah is with us.',
        reference: 'Quran 9:40',
      ),
      MoodSuggestion(
        mood: AppConstants.moodSad,
        contentType: 'ayah',
        arabicText: 'ÙˆÙŽÙ„ÙŽØ³ÙŽÙˆÙ’ÙÙŽ ÙŠÙØ¹Ù’Ø·ÙÙŠÙƒÙŽ Ø±ÙŽØ¨ÙÙ‘ÙƒÙŽ ÙÙŽØªÙŽØ±Ù’Ø¶ÙŽÙ‰Ù°',
        translation: 'And your Lord is going to give you, and you will be satisfied.',
        reference: 'Quran 93:5',
      ),
    ],
    AppConstants.moodHappy: [
      MoodSuggestion(
        mood: AppConstants.moodHappy,
        contentType: 'ayah',
        arabicText: 'Ù„ÙŽØ¦ÙÙ† Ø´ÙŽÙƒÙŽØ±Ù’ØªÙÙ…Ù’ Ù„ÙŽØ£ÙŽØ²ÙÙŠØ¯ÙŽÙ†ÙŽÙ‘ÙƒÙÙ…Ù’',
        translation: 'If you are grateful, I will surely increase you [in favor].',
        reference: 'Quran 14:7',
      ),
      MoodSuggestion(
        mood: AppConstants.moodHappy,
        contentType: 'dua',
        arabicText: 'Ø§Ù„Ù’Ø­ÙŽÙ…Ù’Ø¯Ù Ù„ÙÙ„ÙŽÙ‘Ù‡Ù Ø§Ù„ÙŽÙ‘Ø°ÙÙŠ Ø¨ÙÙ†ÙØ¹Ù’Ù…ÙŽØªÙÙ‡Ù ØªÙŽØªÙÙ…ÙÙ‘ Ø§Ù„ØµÙŽÙ‘Ø§Ù„ÙØ­ÙŽØ§ØªÙ',
        translation: 'All praise is due to Allah by whose grace good deeds are completed.',
        reference: 'Ibn Majah',
      ),
    ],
    // Add more moods as needed
  };
}
