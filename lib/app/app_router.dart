import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_providers.dart';
import '../features/communities/presentation/communities_page.dart';
import '../features/feed/presentation/feed_page.dart';
import '../features/habits/presentation/habits_page.dart';
import '../features/admin/presentation/admin_page.dart';
import '../features/leaderboard/presentation/leaderboard_page.dart';
import '../features/mood/presentation/mood_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/deeds/presentation/screens/create_deed_screen.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';
import '../features/communities/presentation/screens/community_detail_screen.dart';
import '../features/communities/presentation/screens/community_members_screen.dart';
import '../features/chat/presentation/screens/chat_screen.dart';
import '../features/prayer_times/presentation/prayer_times_screen.dart';
import '../features/hijri_calendar/presentation/hijri_calendar_screen.dart';
import '../features/qibla/presentation/qibla_screen.dart';
import 'shell/ameen_shell.dart';

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
      
      // If user is authenticated and on auth screen, redirect to feed
      if (isAuthenticated && isAuthRoute && state.matchedLocation == '/auth') {
        return '/feed';
      }
      
      // If user is not authenticated and trying to access protected route, redirect to auth
      if (!isAuthenticated && isProtectedRoute) {
        return '/auth';
      }
      
      return null; // No redirect needed
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
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ameen+')),
        body: Center(child: Text(state.error.toString())),
      );
    },
  );
});
