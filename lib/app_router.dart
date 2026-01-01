import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_providers.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/feed_page.dart';
import 'presentation/screens/habits_page.dart';
import 'presentation/screens/admin_page.dart';
import 'presentation/screens/leaderboard_page.dart';
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
import 'presentation/shell/ameen_shell.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final guestMode = ref.read(guestModeProvider);

      final isAuthenticated = authState.maybeWhen(
        data: (user) => user != null || guestMode,
        orElse: () => false,
      );

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
        path: '/create-deed',
        name: 'create-deed',
        builder: (context, state) => const CreateDeedScreen(),
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
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/mood',
                name: 'mood',
                builder: (context, state) => const MoodPage(),
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
        builder: (context, state) => const LeaderboardPage(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminPage(),
      ),
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
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ameen+')),
        body: Center(child: Text(state.error.toString())),
      );
    },
  );
});
