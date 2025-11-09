import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final currentNavIndexProvider = StateProvider<int>((ref) => 0);

Color _withOpacity(Color color, double opacity) =>
    color.withAlpha((opacity.clamp(0, 1) * 255).round());

class AppBottomNavBar extends ConsumerWidget {
  const AppBottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Derive selected index from current route, do not modify providers during build
    final path = GoRouterState.of(context).uri.path;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final currentIndex = path.startsWith('/history')
        ? 1
        : path.startsWith('/stats')
            ? 2
            : 0;

    final gradientColors = isDark
        ? [
            _withOpacity(const Color(0xFF0F152C), 0.8),
            _withOpacity(const Color(0xFF0A0F21), 0.75),
          ]
        : [
            _withOpacity(Colors.white, 0.8),
            _withOpacity(Colors.white, 0.65),
          ];
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              indicatorColor:
                  _withOpacity(scheme.primary, isDark ? 0.35 : 0.22),
              height: 70,
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
                    context.go('/stats');
                    break;
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_active_outlined),
                  selectedIcon: Icon(Icons.notifications_active),
                  label: 'History',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_graph_outlined),
                  selectedIcon: Icon(Icons.auto_graph_rounded),
                  label: 'Statistics',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
