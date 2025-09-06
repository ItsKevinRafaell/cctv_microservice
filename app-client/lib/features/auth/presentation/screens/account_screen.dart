import 'package:anomeye/app/di.dart';
import 'package:anomeye/shared/widgets/app_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  @override
  void initState() {
    super.initState();
    // Atur bottom nav bar index saat layar ini dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentNavIndexProvider.notifier).state = 2; // 3 untuk Profile
    });
  }

  @override
  Widget build(BuildContext context) {
    // Tonton state otentikasi untuk mendapatkan data user
    final authState = ref.watch(authStateProvider);
    final user = authState.whenOrNull(authenticated: (_, user) => user);

    // Jika user tidak ditemukan (seharusnya tidak terjadi jika halaman ini terlindungi),
    // tampilkan loading atau pesan error.
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
        bottomNavigationBar: AppBottomNavBar(),
      );
    }

    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  // Gradien untuk tampilan yang lebih modern
                  gradient: const LinearGradient(
                    colors: [Color(0xFF024670), Color(0xFF00639C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar dengan inisial nama
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: Text(
                        user.email.substring(0, 2).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF024670),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.email.split('@').first, // Tampilkan bagian sebelum @
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // --- MENU PENGATURAN ---
            _MenuListItem(
              title: 'Edit Profile',
              icon: Icons.person_outline,
              onTap: () {},
            ),
            _MenuListItem(
              title: 'Change Password',
              icon: Icons.lock_outline,
              onTap: () {},
            ),
            const Divider(indent: 20, endIndent: 20, height: 30),
            _MenuListItem(
              title: 'Log Out',
              icon: Icons.logout,
              textColor: Colors.red,
              onTap: () {
                // Tampilkan dialog konfirmasi sebelum logout
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Log Out'),
                    content: const Text('Are you sure you want to log out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () {
                          ref.read(authStateProvider.notifier).signOut();
                        },
                        style:
                            FilledButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Log Out'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }
}

// Widget helper untuk membuat item menu yang konsisten
class _MenuListItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? textColor;

  const _MenuListItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.grey[700]),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
