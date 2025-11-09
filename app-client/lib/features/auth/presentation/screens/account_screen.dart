import 'dart:io';

import 'package:anomeye/app/di.dart';
import 'package:anomeye/features/auth/presentation/profile_avatar_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.whenOrNull(authenticated: (_, user) => user);
    final avatarPath = ref.watch(profileAvatarProvider);
    final profileInfo = ref.watch(profileInfoProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final displayName =
        profileInfo.displayName ?? user.email.split('@').first;
    final accountEmail = profileInfo.accountEmail ?? user.email;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ProfileCard(
            displayName: displayName,
            userEmail: accountEmail,
            avatarPath: avatarPath,
            onChangePhoto: _changeAvatar,
          ),
          const SizedBox(height: 24),
          Text(
            'Edit Profile',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          _ProfileActionButton(
            title: 'Edit Name',
            icon: Icons.person_outline,
            onTap: () => _editText(
              context,
              title: 'Edit Name',
              initial: displayName,
              onSubmit: (value) => ref
                  .read(profileInfoProvider.notifier)
                  .setDisplayName(value),
            ),
          ),
          const SizedBox(height: 10),
          _ProfileActionButton(
            title: 'Edit Account',
            icon: Icons.email_outlined,
            onTap: () => _editText(
              context,
              title: 'Edit Account',
              initial: accountEmail,
              keyboardType: TextInputType.emailAddress,
              onSubmit: (value) => ref
                  .read(profileInfoProvider.notifier)
                  .setAccountEmail(value),
            ),
          ),
          const SizedBox(height: 10),
          _ProfileActionButton(
            title: 'Edit Password',
            icon: Icons.lock_outline,
            onTap: () => _changePassword(context),
          ),
          const SizedBox(height: 24),
          _GradientButton(
            label: 'Change Password',
            onTap: () => _changePassword(context),
          ),
          const SizedBox(height: 16),
          _ProfileActionButton(
            title: 'Log Out',
            icon: Icons.logout,
            textColor: Colors.red,
            showTrailing: false,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Log Out'),
                  content:
                      const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        ref.read(authStateProvider.notifier).signOut();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Log Out'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _changeAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path != null) {
      await ref.read(profileAvatarProvider.notifier).setAvatarPath(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    }
  }

  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String initial,
    TextInputType keyboardType = TextInputType.text,
    required Future<void> Function(String value) onSubmit,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await onSubmit(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title updated')),
      );
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final newPass = TextEditingController();
    final confirm = TextEditingController();
    final key = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
              ),
              TextFormField(
                controller: newPass,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (value) =>
                    value != null && value.length >= 6 ? null : 'Minimum 6 characters',
              ),
              TextFormField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm password'),
                validator: (value) =>
                    value == newPass.text ? null : 'Passwords do not match',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.displayName,
    required this.userEmail,
    required this.avatarPath,
    required this.onChangePhoto,
  });

  final String displayName;
  final String userEmail;
  final String? avatarPath;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark
            ? _withAlpha(Colors.white, 0.05)
            : _withAlpha(Colors.black, 0.03),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor:
                    _withAlpha(theme.colorScheme.primary, 0.12),
                backgroundImage: avatarPath != null && avatarPath!.isNotEmpty
                    ? FileImage(File(avatarPath!))
                    : null,
                child: avatarPath == null || avatarPath!.isEmpty
                    ? Text(
                        userEmail.substring(0, 2).toUpperCase(),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              InkWell(
                onTap: onChangePhoto,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            userEmail,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _withAlpha(theme.colorScheme.onSurface, 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.title,
    required this.icon,
    required this.onTap,
    this.textColor,
    this.showTrailing = true,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? textColor;
  final bool showTrailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark
            ? _withAlpha(Colors.white, 0.05)
            : _withAlpha(Colors.black, 0.03),
      ),
      child: ListTile(
        leading: Icon(icon, color: textColor ?? theme.colorScheme.primary),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: textColor ?? theme.colorScheme.onSurface,
          ),
        ),
        trailing: showTrailing
            ? Icon(
                Icons.edit_outlined,
                size: 18,
                color: textColor ?? theme.colorScheme.primary,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradientColors = isDark
        ? [
            _withAlpha(theme.colorScheme.primary, 0.9),
            _withAlpha(theme.colorScheme.primary, 0.6),
          ]
        : [
            theme.colorScheme.primary,
            _withAlpha(theme.colorScheme.primary, 0.7),
          ];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

Color _withAlpha(Color color, double opacity) =>
    color.withAlpha((opacity.clamp(0, 1) * 255).round());
