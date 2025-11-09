import 'dart:io';

import 'package:anomeye/app/di.dart';
import 'package:anomeye/app/theme/theme_controller.dart';
import 'package:anomeye/features/notifications/presentation/fcm_controller.dart';
import 'package:anomeye/features/notifications/presentation/notification_preferences_controller.dart';
import 'package:anomeye/shared/styles/app_spacing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart' show DioException;

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
            title: const Text('Permission Required'),
            content: const Text(
              'To receive alerts, please enable notification permissions in your device settings.',
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
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    } else {
      await openAppSettings();
    }
  }

  Future<void> _pickCustomSound(NotificationSoundController controller) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = result?.files.single.path;
    if (path != null) {
      await controller.setCustomPath(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Custom alert sound set to ${File(path).uri.pathSegments.last}')),
      );
    }
  }

  Future<void> _clearCustomSound(NotificationSoundController controller) async {
    await controller.setCustomPath(null);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alert sound reset to default chime')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fcmState = ref.watch(fcmControllerProvider);
    final hasNotificationPermission = fcmState.permissionGranted;
    final themeMode = ref.watch(themeModeControllerProvider);
    final themeController = ref.read(themeModeControllerProvider.notifier);
    final theme = Theme.of(context);
    final notificationPrefs = ref.watch(notificationSoundProvider);
    final notificationPrefsController =
        ref.read(notificationSoundProvider.notifier);
    final customSoundLabel = notificationPrefs.customPath == null
        ? 'Default device chime'
        : notificationPrefs.customPath!
            .split(RegExp(r'[\\/]+'))
            .last;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          _SettingsCard(
            title: 'Appearance',
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dark mode'),
                  subtitle: const Text('Toggle between light & dark themes'),
                  value: themeMode == ThemeMode.dark,
                  onChanged: (value) {
                    themeController.setTheme(
                      value ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.color_lens_outlined),
                  title: const Text('Use system setting'),
                  subtitle: const Text('Follow device appearance automatically'),
                  trailing: Switch.adaptive(
                    value: themeMode == ThemeMode.system,
                    onChanged: (value) {
                      themeController.setTheme(
                        value ? ThemeMode.system : ThemeMode.light,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          _SettingsCard(
            title: 'Notifications',
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: hasNotificationPermission,
                  onChanged: (value) => _handleNotificationPermission(value),
                  title: const Text('Push notifications'),
                  subtitle: Text(
                    hasNotificationPermission
                        ? 'Enabled'
                        : 'Permission disabled',
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: notificationPrefs.enabled,
                  onChanged: (value) =>
                      notificationPrefsController.setEnabled(value),
                  title: const Text('Play alert sound'),
                  subtitle: Text(
                    notificationPrefs.enabled
                        ? 'Sound will play for new anomalies'
                        : 'Muted',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.volume_up_outlined),
                  title: const Text('Preview alert sound'),
                  subtitle: const Text('Tap to hear current alert tone'),
                  onTap: () => ref
                      .read(notificationSoundPlayerProvider)
                      .playPreview(notificationPrefs),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.music_note_outlined),
                  title: const Text('Custom sound'),
                  subtitle: Text(
                    customSoundLabel,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.upload_file),
                    onPressed: () =>
                        _pickCustomSound(notificationPrefsController),
                  ),
                ),
                if (notificationPrefs.customPath != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset to default'),
                      onPressed: () =>
                          _clearCustomSound(notificationPrefsController),
                    ),
                  ),
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_active),
                  title: const Text('Send test notification'),
                  subtitle: const Text('Trigger a sample anomaly alert'),
                  onTap: _sendTestNotification,
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
                      icon: const Icon(Icons.copy),
                      onPressed: () => _copyToken(fcmState.token!),
                    ),
                  ),
              ],
            ),
          ),
          _SettingsCard(
            title: 'Camera',
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-record on anomaly'),
                  subtitle: const Text('Coming soon'),
                  value: autoRecord,
                  onChanged: null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Manage cameras'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {},
                ),
              ],
            ),
          ),
          _SettingsCard(
            title: 'About & Account',
            child: Column(
              children: [
                const AboutListTile(
                  icon: Icon(Icons.info_outline),
                  applicationName: 'AnomEye',
                  applicationVersion: '0.1.0',
                  aboutBoxChildren: [
                    Text('Anomaly detection system powered by AI.'),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout, color: theme.colorScheme.error),
                  title: Text(
                    'Log out',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () {
                    ref.read(authStateProvider.notifier).signOut();
                    context.go('/sign-in');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendTestNotification() async {
    final dio = ref.read(dioProvider);
    try {
      final res = await dio.post('/api/notifications/test');
      if (!mounted) return;
      final id = res.data['anomaly_id'] ?? '-';
      final cnt = res.data['tokens_count'] ?? 'unknown';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test push sent (id=$id, tokens=$cnt)')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed ($code): $msg')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send test push: $e')),
      );
    }
  }

  Future<void> _copyToken(String token) async {
    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('FCM token copied to clipboard')),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : const Color(0xFF3667C9).withOpacity(0.35),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1D1845).withOpacity(0.85), const Color(0xFF221036).withOpacity(0.75)]
              : [const Color(0xFFE4EEFF).withOpacity(0.85), const Color(0xFFD6E5FF).withOpacity(0.75)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.32 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
