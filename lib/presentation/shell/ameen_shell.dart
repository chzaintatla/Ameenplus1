import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/notification_providers.dart';

class AmeenShell extends ConsumerWidget {
  const AmeenShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _titles = <String>[
    'Home',
    'Tools Hub',
    '',
    'Profile',
  ];

  void _onTap(int index, StatefulNavigationShell navigationShell) {
    // Map display index to actual branch index
    // Display: 0=Home, 1=Tools, 2=Add, 3=Community, 4=Profile
    // Branches: 0=Feed, 1=Tools, 2=Community, 3=Profile (no Add branch)
    int actualIndex;
    if (index < 2) {
      actualIndex = index; // Home=0, Tools=1
    } else if (index == 2) {
      // Add button - handled separately
      return;
    } else if (index == 3) {
      actualIndex = 2; // Community
    } else {
      actualIndex = 3; // Profile
    }
    
    if (actualIndex >= 0 && actualIndex < 4) {
      navigationShell.goBranch(actualIndex, initialLocation: actualIndex == navigationShell.currentIndex);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Map actual index to display index (accounting for Add button)
    final actualIndex = navigationShell.currentIndex;
    final displayIndex = actualIndex >= 2 ? actualIndex + 1 : actualIndex;
    final unreadCountAsync = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: (actualIndex == 1 || actualIndex == 2 || actualIndex == 3) ? null : AppBar(
        title: Text(_titles[actualIndex]),
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : Colors.green.shade900,
        foregroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.black
            : Colors.white,
        actions: <Widget>[
          if (actualIndex == 0)
            Stack(
              children: [
                IconButton(
                  onPressed: () {
                    context.push('/notifications');
                  },
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                unreadCountAsync.maybeWhen(
                  data: (count) {
                    if (count == 0) return const SizedBox.shrink();
                    return Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count > 99 ? '99+' : count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
        ],
      ),
      body: navigationShell,
      floatingActionButton: (actualIndex == 0) 
          ? FloatingActionButton(
              onPressed: () {
                // Open AI Chatbot
                context.push('/ai-chatbot');
              },
              backgroundColor: Theme.of(context).brightness == Brightness.light
                  ? Colors.white
                  : Theme.of(context).colorScheme.secondary,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.black87,
                  BlendMode.srcIn,
                ),
                child: Image.asset(
                  'assets/images/chatbot.png',
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                ),
              ),
              tooltip: 'AI Islamic Assistant',
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: displayIndex,
        onDestinationSelected: (index) {
          if (index == 2) {
            // Add button - open camera screen
            context.push('/camera');
          } else {
            _onTap(index, navigationShell);
          }
        },
        indicatorColor: Theme.of(context).brightness == Brightness.light
            ? Colors.green.shade800
            : Colors.green.shade800,
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : Colors.green.shade900,
        destinations: <NavigationDestination>[
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Tools',
          ),
          NavigationDestination(
            icon: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
            selectedIcon: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
            label: '',
          ),
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Community',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

