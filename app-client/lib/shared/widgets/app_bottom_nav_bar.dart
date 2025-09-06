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
    final currentIndex = path.startsWith('/history')
        ? 1
        : path.startsWith('/account')
            ? 2
            : path.startsWith('/settings')
                ? 3
                : 0;

    return NavigationBar(
      backgroundColor: const Color(0xFF024670),
      indicatorColor: Colors.white.withOpacity(0.15),
      height: 70,

      // FIX: Tambahkan properti ini untuk menyembunyikan semua label
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,

      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        if (currentIndex == index) return;
        switch (index) {
          case 0:
            context.go('/');
            break;
          case 1:
            context.go('/history');
            break;
          case 2:
            context.go('/account');
            break;
          case 3:
            context.go('/settings');
            break;
        }
      },
      // Menambahkan destinasi
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined, color: Colors.white70),
          selectedIcon: Icon(Icons.home, color: Colors.white),
          label: 'Home', // Label tetap wajib diisi, tapi tidak akan ditampilkan
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined, color: Colors.white70),
          selectedIcon: Icon(Icons.history, color: Colors.white),
          label: 'History',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outlined, color: Colors.white70),
          selectedIcon: Icon(Icons.person, color: Colors.white),
          label: 'Profile',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined, color: Colors.white70),
          selectedIcon: Icon(Icons.settings, color: Colors.white),
          label: 'Settings',
        ),
      ],
    );
  }
}
