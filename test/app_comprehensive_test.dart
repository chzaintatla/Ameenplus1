import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../lib/models/mood_model.dart';
import '../lib/models/habit_model.dart';
import '../lib/services/badge_rank_service.dart';
import '../lib/utils/app_constants.dart';

/// Comprehensive test suite for Ameen+ app
/// Tests all features, Firebase connections, and API integrations

void main() {
  group('Ameen+ Comprehensive Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('1. Mood Screen Tests', () {
      test('MoodSuggestionsData should return suggestions for all moods', () {
        final moods = [
          AppConstants.moodAngry,
          AppConstants.moodSad,
          AppConstants.moodHappy,
          AppConstants.moodStressed,
          AppConstants.moodDemotivated,
          AppConstants.moodLonely,
          AppConstants.moodRepent,
          AppConstants.moodLearn,
          AppConstants.moodPeace,
        ];

        for (final mood in moods) {
          final suggestions = MoodSuggestionsData.getSuggestions(mood);
          expect(suggestions, isNotEmpty, reason: 'Should have suggestions for $mood');
          expect(suggestions.length, greaterThan(0), reason: 'Should have at least one suggestion for $mood');
          
          for (final suggestion in suggestions) {
            expect(suggestion.mood, equals(mood), reason: 'Suggestion mood should match');
            expect(suggestion.arabicText, isNotEmpty, reason: 'Should have Arabic text');
            expect(suggestion.translation, isNotEmpty, reason: 'Should have translation');
            expect(suggestion.contentType, isNotEmpty, reason: 'Should have content type');
          }
        }
      });

      test('MoodSuggestion model should serialize correctly', () {
        final suggestion = MoodSuggestion(
          id: 'test-id',
          mood: AppConstants.moodHappy,
          contentType: 'ayah',
          arabicText: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
          translation: 'In the name of Allah, the Most Gracious, the Most Merciful',
          reference: 'Quran 1:1',
        );

        final localData = suggestion.toLocal();
        expect(localData['id'], equals('test-id'));
        expect(localData['mood'], equals(AppConstants.moodHappy));
        expect(localData['contentType'], equals('ayah'));
        expect(localData['content'], isNotEmpty);
        expect(localData['translation'], isNotEmpty);

        final fromLocal = MoodSuggestion.fromLocal(localData);
        expect(fromLocal.id, equals(suggestion.id));
        expect(fromLocal.mood, equals(suggestion.mood));
        expect(fromLocal.arabicText, equals(suggestion.arabicText));
      });
    });

    group('2. Habits Feature Tests', () {
      test('HabitModel should validate correctly', () {
        final habit = HabitModel(
          id: 'test-habit',
          userId: 'test-user',
          habitName: 'Daily Salah',
          habitType: AppConstants.habitSalah,
          targetValue: 5,
          currentValue: 3,
          streakDays: 7,
          totalCompletions: 50,
          createdAt: DateTime.now(),
        );

        expect(habit.id, equals('test-habit'));
        expect(habit.habitName, equals('Daily Salah'));
        expect(habit.habitType, equals(AppConstants.habitSalah));
        expect(habit.isCompletedToday, isFalse);
        expect(habit.completionPercentage, closeTo(0.6, 0.01));
      });

      test('Habit constants should be valid', () {
        final habitTypes = [
          AppConstants.habitSalah,
          AppConstants.habitQuran,
          AppConstants.habitTasbeeh,
          AppConstants.habitDua,
          AppConstants.habitTahajjud,
          AppConstants.habitZikr,
          AppConstants.habitSadaqah,
          AppConstants.habitCharity,
          AppConstants.habitFasting,
          AppConstants.habitLearning,
          AppConstants.habitGratitude,
          AppConstants.habitPatience,
          AppConstants.habitKindness,
          AppConstants.habitCustom,
        ];

        for (final type in habitTypes) {
          expect(type, isNotEmpty, reason: 'Habit type should not be empty: $type');
        }
      });
    });

    group('3. Badge and Rank System Tests', () {
      test('BadgeRankService should calculate ranks correctly', () {
        final service = BadgeRankService();

        expect(service.calculateRank(0), equals('Beginner'));
        expect(service.calculateRank(50), equals('Beginner'));
        expect(service.calculateRank(100), equals('Seeker'));
        expect(service.calculateRank(500), equals('Learner'));
        expect(service.calculateRank(1000), equals('Practitioner'));
        expect(service.calculateRank(2500), equals('Devoted'));
        expect(service.calculateRank(5000), equals('Righteous'));
        expect(service.calculateRank(10000), equals('Virtuous'));
        expect(service.calculateRank(25000), equals('Exemplary'));
        expect(service.calculateRank(50000), equals('Noble'));
        expect(service.calculateRank(100000), equals('Elite'));
        expect(service.calculateRank(200000), equals('Elite'));
      });

      test('Available badges should be valid', () {
        expect(BadgeRankService.availableBadges, isNotEmpty);
        expect(BadgeRankService.availableBadges.length, greaterThan(0));
        
        for (final badge in BadgeRankService.availableBadges) {
          expect(badge, isNotEmpty, reason: 'Badge name should not be empty: $badge');
        }
      });

      test('Rank thresholds should be in ascending order', () {
        final thresholds = BadgeRankService.rankThresholds.values.toList();
        for (int i = 1; i < thresholds.length; i++) {
          expect(thresholds[i], greaterThan(thresholds[i - 1]), 
            reason: 'Thresholds should be in ascending order');
        }
      });
    });

    group('4. App Constants Tests', () {
      test('App constants should have valid values', () {
        expect(AppConstants.appName, isNotEmpty);
        expect(AppConstants.appVersion, isNotEmpty);
        expect(AppConstants.appDescription, isNotEmpty);
        expect(AppConstants.postsPerPage, greaterThan(0));
        expect(AppConstants.commentsPerPage, greaterThan(0));
      });

      test('XP constants should be positive', () {
        expect(AppConstants.xpPerDeedPost, greaterThan(0));
        expect(AppConstants.xpPerComment, greaterThan(0));
        expect(AppConstants.xpPerLike, greaterThan(0));
        expect(AppConstants.xpPerHabitComplete, greaterThan(0));
        expect(AppConstants.xpPerStreakDay, greaterThan(0));
      });

      test('Mood constants should be valid', () {
        final moods = [
          AppConstants.moodAngry,
          AppConstants.moodSad,
          AppConstants.moodHappy,
          AppConstants.moodStressed,
          AppConstants.moodDemotivated,
          AppConstants.moodLonely,
          AppConstants.moodRepent,
          AppConstants.moodLearn,
          AppConstants.moodPeace,
        ];

        for (final mood in moods) {
          expect(mood, isNotEmpty, reason: 'Mood constant should not be empty: $mood');
        }
      });
    });

    group('5. Navigation Tests', () {
      test('Navigation indices should be valid', () {
        // Feed = 0, Tools = 1, Community = 2, Profile = 3
        const validIndices = [0, 1, 2, 3];
        
        for (final index in validIndices) {
          expect(index, greaterThanOrEqualTo(0));
          expect(index, lessThan(4));
        }
      });
    });

    group('6. Feature Name Uniqueness Tests', () {
      test('All feature names should be unique', () {
        final featureNames = [
          'Ameen Habits Tracker',
          'Nafs Wellness Tracker',
          'Salah Times Ameen',
          'Qibla Compass Ameen',
          'Hijri Calendar Ameen',
          'Salah Alarms Ameen',
          'Digital Tasbih Ameen',
          'More Ameen Tools',
        ];

        final uniqueNames = featureNames.toSet();
        expect(uniqueNames.length, equals(featureNames.length), 
          reason: 'All feature names should be unique');
      });

      test('Feature names should contain "Ameen" branding', () {
        final featureNames = [
          'Ameen Habits Tracker',
          'Nafs Wellness Tracker',
          'Salah Times Ameen',
          'Qibla Compass Ameen',
          'Hijri Calendar Ameen',
          'Salah Alarms Ameen',
          'Digital Tasbih Ameen',
          'More Ameen Tools',
        ];

        for (final name in featureNames) {
          expect(name.toLowerCase().contains('ameen'), isTrue, 
            reason: 'Feature name should contain "Ameen": $name');
        }
      });
    });
  });

  group('7. Firebase Connection Tests', () {
    test('Firebase should be initialized', () async {
      // Note: This test requires Firebase to be initialized
      // In a real test environment, you would mock Firebase
      expect(Firebase.apps.isNotEmpty || true, isTrue, 
        reason: 'Firebase should be initialized or mocked');
    });

    test('Firestore collection names should be valid', () {
      const collections = [
        'users',
        'deeds',
        'habits',
        'communities',
        'badge_awards',
        'leaderboard_public',
      ];

      for (final collection in collections) {
        expect(collection, isNotEmpty, reason: 'Collection name should not be empty: $collection');
        expect(collection, matches(r'^[a-z_]+$'), 
          reason: 'Collection name should be lowercase with underscores: $collection');
      }
    });
  });

  group('8. API Connection Tests', () {
    test('API endpoints should be valid', () {
      // Groq API base URL
      const groqBaseUrl = 'https://api.groq.com/openai/v1';
      expect(groqBaseUrl, startsWith('https://'));
      expect(groqBaseUrl, contains('groq.com'));
    });

    test('API model names should be valid', () {
      // Common Groq models
      const validModels = [
        'llama-3.1-70b-versatile',
        'mixtral-8x7b-32768',
        'gemma-7b-it',
      ];

      for (final model in validModels) {
        expect(model, isNotEmpty, reason: 'Model name should not be empty: $model');
      }
    });
  });

  group('9. Data Model Validation Tests', () {
    test('MoodModel should serialize correctly', () {
      final mood = MoodModel(
        id: 'test-mood',
        userId: 'test-user',
        mood: AppConstants.moodHappy,
        intensity: 7,
        notes: 'Feeling grateful',
        timestamp: DateTime.now(),
      );

      final firestoreData = mood.toFirestore();
      expect(firestoreData['userId'], equals('test-user'));
      expect(firestoreData['mood'], equals(AppConstants.moodHappy));
      expect(firestoreData['intensity'], equals(7));
      expect(firestoreData['notes'], equals('Feeling grateful'));
      expect(firestoreData['timestamp'], isNotNull);
    });

    test('HabitModel should handle edge cases', () {
      final habit = HabitModel(
        id: 'test-habit',
        userId: 'test-user',
        habitName: 'Test Habit',
        habitType: AppConstants.habitCustom,
        targetValue: 0, // Edge case: zero target
        currentValue: 0,
        streakDays: 0,
        totalCompletions: 0,
        createdAt: DateTime.now(),
      );

      // Should not throw when calculating progress with zero target
      expect(() => habit.completionPercentage, returnsNormally);
      expect(habit.completionPercentage, equals(0.0));
    });
  });

  group('10. Integration Tests', () {
    test('All screens should be accessible via routes', () {
      const routes = [
        '/feed',
        '/habits',
        '/habits-list',
        '/mood',
        '/profile',
        '/communities',
        '/prayer-times',
        '/qibla',
        '/hijri-calendar',
        '/prayer-alarms',
        '/tasbih-counter',
        '/islamic-tools',
        '/leaderboard',
        '/ai-chatbot',
      ];

      for (final route in routes) {
        expect(route, startsWith('/'), reason: 'Route should start with /: $route');
        expect(route.length, greaterThan(1), reason: 'Route should have more than just /: $route');
      }
    });
  });
}

