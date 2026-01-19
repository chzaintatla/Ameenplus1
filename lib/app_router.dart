import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/app_constants.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/feed_page.dart';
import 'presentation/screens/habits_page.dart';
import 'presentation/screens/habits_list_page.dart';
import 'presentation/screens/tasbih_counter_screen.dart';
import 'presentation/screens/leaderboard_screen.dart';
import 'presentation/screens/habits_history_screen.dart';
import 'presentation/screens/mood_page.dart';
import 'presentation/screens/profile_page.dart';
import 'presentation/screens/edit_profile_screen.dart';
import 'presentation/screens/create_deed_screen.dart';
import 'presentation/screens/notifications_screen.dart';
import 'presentation/screens/communities_page.dart';
import 'presentation/screens/community_detail_screen.dart';
import 'presentation/screens/community_members_screen.dart';
import 'presentation/screens/chat_screen.dart';
import 'presentation/screens/prayer_times_screen.dart';
import 'presentation/screens/hijri_calendar_screen.dart';
import 'presentation/screens/qibla_screen.dart';
import 'presentation/screens/islamic_tools_screen.dart';
import 'presentation/screens/followers_following_screen.dart';
import 'presentation/screens/user_profile_preview_screen.dart';
import 'presentation/screens/ai_chatbot_screen.dart';
import 'presentation/screens/prayer_alarms_screen.dart';
import 'presentation/screens/daily_deed_screen.dart';
import 'presentation/screens/camera_screen.dart';
import 'presentation/screens/add_member_screen.dart';
import 'presentation/screens/favorites_screen.dart';
import 'presentation/shell/ameen_shell.dart';

GoRouter getGoRouter({void Function(ThemeMode)? onThemeModeChanged}) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final guestMode = prefs.getBool(AppConstants.keyGuestMode) ?? false;

      final isAuthenticated = user != null || guestMode;
      final isAuthRoute = state.matchedLocation == '/auth' || state.matchedLocation == '/';
      final isProtectedRoute = !isAuthRoute && state.matchedLocation != '/create-deed';

      if (isAuthenticated && isAuthRoute && state.matchedLocation == '/auth') {
        return '/feed';
      }

      if (!isAuthenticated && isProtectedRoute) {
        return '/auth';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/camera',
        name: 'camera',
        builder: (context, state) => const CameraScreen(),
      ),
      GoRoute(
        path: '/create-deed',
        name: 'create-deed',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CreateDeedScreen(
            initialMediaPath: extra?['mediaPath'] as String?,
            initialMediaType: extra?['mediaType'] as String?,
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AmeenShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/feed',
                name: 'feed',
                builder: (context, state) => const FeedPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/habits',
                name: 'habits',
                builder: (context, state) => const HabitsPage(),
              ),
              GoRoute(
                path: '/habits-list',
                name: 'habits-list',
                builder: (context, state) => const HabitsListPage(),
              ),
              GoRoute(
                path: '/tasbih-counter',
                name: 'tasbih-counter',
                builder: (context, state) => const TasbihCounterScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/communities',
                name: 'communities',
                builder: (context, state) => const CommunitiesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/leaderboard',
        name: 'leaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/habits-history',
        name: 'habits-history',
        builder: (context, state) => const HabitsHistoryScreen(),
      ),
      // GoRoute(
      //   path: '/admin',
      //   name: 'admin',
      //   builder: (context, state) => const AdminPage(),
      // ),
      GoRoute(
        path: '/profile/edit',
        name: 'edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/communities/:id',
        name: 'community-detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CommunityDetailScreen(communityId: id);
        },
      ),
      GoRoute(
        path: '/communities/:id/members',
        name: 'community-members',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CommunityMembersScreen(communityId: id);
        },
      ),
      GoRoute(
        path: '/favorites',
        name: 'favorites',
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: '/chat/:chatId',
        name: 'chat',
        builder: (context, state) {
          final chatId = state.pathParameters['chatId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return ChatScreen(
            chatId: chatId,
            otherUserName: extra?['otherUserName'] as String?,
            isCommunityChat: extra?['isCommunityChat'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: '/islamic-tools',
        name: 'islamic-tools',
        builder: (context, state) => const IslamicToolsScreen(),
      ),
      GoRoute(
        path: '/prayer-times',
        name: 'prayer-times',
        builder: (context, state) => const PrayerTimesScreen(),
      ),
      GoRoute(
        path: '/hijri-calendar',
        name: 'hijri-calendar',
        builder: (context, state) => const HijriCalendarScreen(),
      ),
      GoRoute(
        path: '/qibla',
        name: 'qibla',
        builder: (context, state) => const QiblaScreen(),
      ),
      GoRoute(
        path: '/ai-chatbot',
        name: 'ai-chatbot',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AIChatbotScreen(
            initialMessage: extra?['initialMessage'] as String?,
            mediaPath: extra?['mediaPath'] as String?,
            mediaType: extra?['mediaType'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/prayer-alarms',
        name: 'prayer-alarms',
        builder: (context, state) => const PrayerAlarmsScreen(),
      ),
      GoRoute(
        path: '/daily-deed',
        name: 'daily-deed',
        builder: (context, state) => const DailyDeedScreen(),
      ),
      GoRoute(
        path: '/mood',
        name: 'mood',
        builder: (context, state) => const MoodPage(),
      ),
      GoRoute(
        path: '/followers-following/:userId',
        name: 'followers-following',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return FollowersFollowingScreen(
            userId: userId,
            initialTab: extra?['initialTab'] as int? ?? 0,
          );
        },
      ),
      GoRoute(
        path: '/user-profile/:userId',
        name: 'user-profile-preview',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return UserProfilePreviewScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/add-member',
        name: 'add-member',
        builder: (context, state) => const AddMemberScreen(),
      ),
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ameen+')),
        body: Center(child: Text(state.error.toString())),
      );
    },
  );
}
