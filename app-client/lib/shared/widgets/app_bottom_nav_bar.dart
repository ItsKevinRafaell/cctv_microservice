import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final currentNavIndexProvider = StateProvider<int>((ref) => 0);

class AppBottomNavBar extends ConsumerWidget {
  const AppBottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Derive selected index from current route, do not modify providers during build
    final path = GoRouterState.of(context).uri.path;
    final currentIndex = path.startsWith('/cameras')
        ? 1
        : path.startsWith('/history')
            ? 2
            : path.startsWith('/account')
                ? 3
                : path.startsWith('/settings')
                    ? 4
                    : 0;

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        if (currentIndex == index) return;
        switch (index) {
          case 0:
            context.go('/');
            break;
          case 1:
            context.go('/cameras');
            break;
          case 2:
            context.go('/history');
            break;
          case 3:
            context.go('/account');
            break;
          case 4:
            context.go('/settings');
            break;
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.video_camera_front_outlined),
          selectedIcon: Icon(Icons.video_camera_front_rounded),
          label: 'Cameras',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_none),
          selectedIcon: Icon(Icons.notifications),
          label: 'Alerts',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
}
