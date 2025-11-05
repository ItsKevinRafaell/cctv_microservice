import 'package:anomeye/app/di.dart';
import 'package:anomeye/features/notifications/presentation/fcm_controller.dart';
import 'package:anomeye/shared/widgets/app_bottom_nav_bar.dart';
import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  bool autoRecord = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentNavIndexProvider.notifier).state = 4;
      _checkAndUpdatePermissionStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkAndUpdatePermissionStatus();
    }
  }

  Future<void> _checkAndUpdatePermissionStatus() async {
    final status = await Permission.notification.status;
    if (status.isGranted) {
      await ref.read(fcmControllerProvider.notifier).registerIfPossible();
    }
  }

  Future<void> _handleNotificationPermission(bool value) async {
    if (value) {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        await ref.read(fcmControllerProvider.notifier).registerIfPossible();
      } else if (status.isPermanentlyDenied && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission required'),
            content: const Text(
              'Enable notification permission in system settings to receive alerts.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
                child: const Text('Open settings'),
              ),
            ],
          ),
        );
      }
    } else {
      await openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fcmState = ref.watch(fcmControllerProvider);
    final hasNotificationPermission = fcmState.permissionGranted;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              'Settings',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              title: 'Notifications',
              subtitle: 'Control how AnomEye sends you alerts.',
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Push notifications'),
                    subtitle: Text(
                      hasNotificationPermission
                          ? 'Enabled'
                          : 'Disabled - enable to receive anomaly alerts.',
                    ),
                    value: hasNotificationPermission,
                    onChanged: _handleNotificationPermission,
                    secondary: const Icon(Icons.notifications_active_outlined),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.send_outlined),
                    title: const Text('Send test notification'),
                    subtitle: const Text(
                      'Trigger the latest anomaly alert to verify delivery.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final dio = ref.read(dioProvider);
                      try {
                        final res = await dio.post('/api/notifications/test');
                        if (!mounted) return;
                        final id = res.data['anomaly_id'] ?? '-';
                        final cnt = res.data['tokens_count'] ?? 'unknown';
                        messenger
                          ..clearSnackBars()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                'Test push queued (anomaly $id, tokens $cnt)',
                              ),
                            ),
                          );
                      } on DioException catch (e) {
                        if (!mounted) return;
                        final code = e.response?.statusCode;
                        final data = e.response?.data;
                        final msg = data is String
                            ? data
                            : (data is Map && data['error'] is String
                                ? data['error']
                                : e.message ?? 'unknown error');
                        messenger
                          ..clearSnackBars()
                          ..showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFFD92D20),
                              content: Text('Failed ($code): $msg'),
                            ),
                          );
                      } catch (e) {
                        if (!mounted) return;
                        messenger
                          ..clearSnackBars()
                          ..showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFFD92D20),
                              content: Text('Failed to send test push: $e'),
                            ),
                          );
                      }
                    },
                  ),
                  if (fcmState.token != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.vpn_key_outlined),
                      title: const Text('FCM token'),
                      subtitle: Text(
                        fcmState.token!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy_outlined),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await Clipboard.setData(
                            ClipboardData(text: fcmState.token!),
                          );
                          if (!mounted) return;
                          messenger
                            ..clearSnackBars()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text('Token copied to clipboard'),
                              ),
                            );
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SettingsCard(
              title: 'Camera automation',
              subtitle: 'Experimental tools for incident response.',
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto record on anomaly'),
                    subtitle: const Text('Coming soon'),
                    value: autoRecord,
                    onChanged: null,
                    secondary: const Icon(Icons.videocam_outlined),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.camera_alt_outlined),
                    title: const Text('Manage cameras'),
                    subtitle: const Text(
                      'Modify stream keys, naming, and coverage details.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/cameras'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SettingsCard(
              title: 'About AnomEye',
              subtitle: 'Build information and legal details.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AboutListTile(
                    dense: true,
                    icon: Icon(Icons.info_outline),
                    applicationName: 'AnomEye',
                    applicationVersion: '0.1.0',
                    aboutBoxChildren: [
                      SizedBox(height: 8),
                      Text(
                        'Integrated AI security monitoring for enterprise environments.',
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Text(
                    '© ${DateTime.now().year} AnomEye Secure Systems. All rights reserved.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: const Color(0xFF667085)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: const Color(0xFF667085)),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
