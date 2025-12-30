/// Core constants for the Ameen+ application
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Ameen+';
  static const String appNameArabic = 'آمین پلس';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Your Islamic Companion';

  // API Keys (Replace with actual keys)
  static const String firebaseApiKey = 'YOUR_FIREBASE_API_KEY';
  
  // Database
  static const String localDatabaseName = 'ameen_local.db';
  static const int localDatabaseVersion = 1;
  
  // Storage Keys
  static const String keyUserId = 'user_id';
  static const String keyUserToken = 'user_token';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyPrayerNotifications = 'prayer_notifications';
  
  // Pagination
  static const int postsPerPage = 20;
  static const int commentsPerPage = 10;
  static const int friendsPerPage = 50;
  static const int communitiesPerPage = 20;
  
  // Upload Limits
  static const int maxImageSizeMB = 5;
  static const int maxVideoSizeMB = 50;
  static const int maxProfileImageSizeMB = 2;
  
  // XP & Gamification
  static const int xpPerDeedPost = 10;
  static const int xpPerComment = 2;
  static const int xpPerLike = 1;
  static const int xpPerHabitComplete = 15;
  static const int xpPerStreakDay = 5;
  static const int xpPerFriend = 5;
  static const int xpPerCommunityPost = 10;
  static const int xpDailyLoginBonus = 10;
  
  // Streak Penalties
  static const int streakMissedPenaltyDays = 1;
  
  // Habit Types
  static const String habitTasbeeh = 'tasbeeh';
  static const String habitSalah = 'salah';
  static const String habitQuran = 'quran';
  static const String habitFasting = 'fasting';
  static const String habitSadaqah = 'sadaqah';
  static const String habitDua = 'dua';
  static const String habitTahajjud = 'tahajjud';
  static const String habitZikr = 'zikr';
  static const String habitCharity = 'charity';
  static const String habitLearning = 'learning';
  static const String habitGratitude = 'gratitude';
  static const String habitPatience = 'patience';
  static const String habitKindness = 'kindness';
  static const String habitCustom = 'custom';
  
  // Deed Types
  static const String deedAyah = 'ayah';
  static const String deedHadith = 'hadith';
  static const String deedQuote = 'quote';
  static const String deedTask = 'task';
  static const String deedGeneral = 'general';
  
  // Mood Types
  static const String moodAngry = 'angry';
  static const String moodSad = 'sad';
  static const String moodHappy = 'happy';
  static const String moodStressed = 'stressed';
  static const String moodDemotivated = 'demotivated';
  static const String moodLonely = 'lonely';
  static const String moodRepent = 'repent';
  static const String moodLearn = 'learn';
  static const String moodPeace = 'peace';
  
  // Deed Categories
  static const List<String> deedCategories = [
    'Charity',
    'Patience',
    'Salah',
    'Family',
    'Knowledge',
    'Gratitude',
    'Kindness',
    'Quran',
    'Dua',
    'Zikr',
    'Fasting',
    'Good Character',
  ];
  
  // Badge Types
  static const String badgeSalahChamp = 'salah_champ';
  static const String badgeSadaqahStar = 'sadaqah_star';
  static const String badgeZikrMaster = 'zikr_master';
  static const String badgeQuranLover = 'quran_lover';
  static const String badgePatience = 'patience_master';
  static const String badgeStreakWarrior = 'streak_warrior';
  static const String badgeCommunityBuilder = 'community_builder';
  static const String badgeFriendlyMumin = 'friendly_mumin';
  
  // Leaderboard Periods
  static const String leaderboardWeekly = 'weekly';
  static const String leaderboardMonthly = 'monthly';
  static const String leaderboardYearly = 'yearly';
  static const String leaderboardAllTime = 'all_time';
  
  // Leaderboard Regions
  static const String regionGlobal = 'global';
  static const String regionPakistan = 'pakistan';
  static const String regionFriends = 'friends';
  
  // Prayer Times
  static const List<String> prayerNames = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];
  
  // Notification Channels
  static const String channelChat = 'chat_messages';
  static const String channelFriends = 'friend_requests';
  static const String channelCommunity = 'community_updates';
  static const String channelReminders = 'deed_reminders';
  static const String channelPrayer = 'prayer_times';
  
  // Error Messages
  static const String errorNetwork = 'No internet connection';
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorAuth = 'Authentication failed';
  static const String errorPermission = 'Permission denied';
  
  // Success Messages
  static const String successDeedPosted = 'Deed shared successfully!';
  static const String successHabitCompleted = 'Habit marked as complete!';
  static const String successFriendRequest = 'Friend request sent!';
  static const String successCommunityCreated = 'Community created successfully!';
  
  // Firebase Collections
  static const String collectionUsers = 'users';
  static const String collectionDeeds = 'deeds';
  static const String collectionHabits = 'habits';
  static const String collectionMoods = 'moods';
  static const String collectionCommunities = 'communities';
  static const String collectionChats = 'chats';
  static const String collectionMessages = 'messages';
  static const String collectionFriendRequests = 'friend_requests';
  static const String collectionNotifications = 'notifications';
  static const String collectionLeaderboard = 'leaderboard';
  static const String collectionBadges = 'badges';
  
  // Routes
  static const String routeSplash = '/';
  static const String routeOnboarding = '/onboarding';
  static const String routeAuth = '/auth';
  static const String routeHome = '/home';
  static const String routeFeed = '/feed';
  static const String routeHabits = '/habits';
  static const String routeMood = '/mood';
  static const String routeLeaderboard = '/leaderboard';
  static const String routeCommunities = '/communities';
  static const String routeProfile = '/profile';
  static const String routeChat = '/chat';
  static const String routeSettings = '/settings';
  static const String routePrayerTimes = '/prayer-times';
  static const String routeQibla = '/qibla';
}
