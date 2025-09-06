import 'package:anomeye/app/di.dart';
import 'package:anomeye/features/notifications/presentation/fcm_controller.dart';
import 'package:anomeye/shared/widgets/app_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
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
    // Mendaftarkan observer untuk mendeteksi siklus hidup aplikasi
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Atur bottom nav bar index saat layar ini dibuka
      ref.read(currentNavIndexProvider.notifier).state = 3; // 3 untuk Settings
      // Periksa status izin saat pertama kali masuk ke halaman
      _checkAndUpdatePermissionStatus();
    });
  }

  @override
  void dispose() {
    // Hapus observer saat widget dihancurkan untuk mencegah memory leak
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Metode ini dipanggil oleh Flutter saat aplikasi dijeda atau dilanjutkan.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Jika pengguna baru saja kembali ke aplikasi
    if (state == AppLifecycleState.resumed) {
      // Periksa ulang status izin notifikasi kalau-kalau ada perubahan
      _checkAndUpdatePermissionStatus();
    }
  }

  /// Memeriksa status izin saat ini dan memperbarui state di Riverpod.
  Future<void> _checkAndUpdatePermissionStatus() async {
    final status = await Permission.notification.status;
    if (status.isGranted) {
      await ref.read(fcmControllerProvider.notifier).registerIfPossible();
    }
  }

  /// Menangani logika saat saklar notifikasi ditekan.
  Future<void> _handleNotificationPermission(bool value) async {
    if (value) {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        await ref.read(fcmControllerProvider.notifier).registerIfPossible();
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permission Required'),
              content: const Text(
                  'To receive alerts, please enable notification permissions in your device settings.'),
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
      }
    } else {
      await openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fcmState = ref.watch(fcmControllerProvider);
    final hasNotificationPermission = fcmState.permissionGranted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF024670),
      ),
      backgroundColor: Colors.grey[100],
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          // Grup Pengaturan Notifikasi
          _buildSectionHeader('Notifications'),
          SwitchListTile(
            title: const Text('Push notifications'),
            subtitle: Text(hasNotificationPermission ? 'Enabled' : 'Disabled'),
            value: hasNotificationPermission,
            onChanged: _handleNotificationPermission,
            secondary: const Icon(Icons.notifications_active_outlined),
          ),

          // Grup Pengaturan Kamera
          _buildSectionHeader('Camera'),
          SwitchListTile(
            title: const Text('Auto-record on anomaly'),
            subtitle: const Text('Coming soon'),
            value: autoRecord,
            onChanged: null, // Dinonaktifkan untuk saat ini
            secondary: const Icon(Icons.videocam_outlined),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Manage Cameras'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Arahkan ke halaman manajemen kamera
            },
          ),

          // Grup Pengaturan Aplikasi
          _buildSectionHeader('About'),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'AnomEye',
            applicationVersion: '0.1.0',
            aboutBoxChildren: [
              Text('Anomaly detection system powered by AI.'),
            ],
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Log Out',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              ref.read(authStateProvider.notifier).signOut();
              context.go('/sign-in'); // Arahkan ke halaman login
            },
          )
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }

  /// Widget helper untuk membuat header setiap seksi
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[600],
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
