import 'package:anomeye/app/di.dart';
import 'package:anomeye/features/anomalies/presentation/screens/anomaly_detail_screen.dart';
import 'package:anomeye/features/anomalies/presentation/screens/anomaly_history_screen.dart';
import 'package:anomeye/features/auth/presentation/screens/account_screen.dart';
import 'package:anomeye/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:anomeye/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:anomeye/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:anomeye/features/cameras/presentation/screens/camera_detail_screen.dart';
import 'package:anomeye/features/cameras/presentation/screens/home_dashboard_screen.dart';
import 'package:anomeye/features/settings/presentation/settings_screen.dart';
import 'package:anomeye/features/streaming/presentation/live_player_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:anomeye/features/recordings/presentation/recordings_screen.dart';

CustomTransitionPage<T> _slidePage<T>({
  required GoRouterState state,
  required Widget child,
  Duration duration = const Duration(milliseconds: 280),
  Curve curve = Curves.easeOutCubic,
}) {
  final tween = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
      .chain(CurveTween(curve: curve));
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondary, child) =>
        SlideTransition(position: animation.drive(tween), child: child),
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: '/sign-in',
    routes: [
      GoRoute(
          path: '/sign-in',
          name: 'sign-in',
          pageBuilder: (_, s) => const NoTransitionPage(child: SignInScreen())),
      GoRoute(
          path: '/',
          name: 'home',
          pageBuilder: (_, s) =>
              const NoTransitionPage(child: HomeDashboard())),
      GoRoute(
        path: '/camera/:id',
        name: 'camera-detail',
        pageBuilder: (_, s) {
          final id = s.pathParameters['id']!;
          return _slidePage(state: s, child: CameraDetailScreen(cameraId: id));
        },
      ),
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
          path: '/sign-up',
          name: 'sign-up',
          pageBuilder: (_, s) => const NoTransitionPage(child: SignUpScreen())),
      GoRoute(
          path: '/history',
          name: 'history',
          pageBuilder: (_, s) =>
              const NoTransitionPage(child: AnomalyHistoryScreen())),
      GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (_, __) => const SettingsScreen()),
      GoRoute(
          path: '/account',
          name: 'account',
          pageBuilder: (_, s) =>
              const NoTransitionPage(child: AccountScreen())),
      GoRoute(
        path: '/cameras/:id/recordings',
        name: 'recordings',
        builder: (context, state) =>
            RecordingsScreen(cameraId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/live/:id',
        name: 'live',
        builder: (context, state) =>
            LivePlayerScreen(cameraId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/anomalies/:id',
        name: 'anomaly-detail',
        pageBuilder: (_, s) {
          final id = s.pathParameters['id']!;
          return _slidePage(
              state: s, child: AnomalyDetailScreen(anomalyId: id));
        },
      ),
    ],
    redirect: (context, state) {
      final loggingIn =
          state.fullPath == '/sign-in' || state.fullPath == '/sign-up';

      final authed = auth.maybeWhen(
        authenticated: (_, __) => true,
        orElse: () => false,
      );

      if (!authed && !loggingIn) return '/sign-in';
      if (authed && loggingIn) return '/';
      return null;
    },
  );
});
