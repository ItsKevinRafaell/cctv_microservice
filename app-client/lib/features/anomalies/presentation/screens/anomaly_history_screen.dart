import 'dart:io';

import 'package:anomeye/app/di.dart';
import 'package:anomeye/features/anomalies/presentation/anomaly_controllers.dart';
import 'package:anomeye/features/anomalies/presentation/anomaly_read_controller.dart';
import 'package:anomeye/features/anomalies/presentation/widgets/animated_list_item.dart';
import 'package:anomeye/features/anomalies/presentation/widgets/anomaly_card.dart';
import 'package:anomeye/features/auth/presentation/profile_avatar_controller.dart';
import 'package:anomeye/shared/styles/app_spacing.dart';
import 'package:anomeye/shared/widgets/app_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AnomalyHistoryScreen extends ConsumerStatefulWidget {
  const AnomalyHistoryScreen({super.key, this.cameraId});
  final String? cameraId;

  @override
  ConsumerState<AnomalyHistoryScreen> createState() =>
      _AnomalyHistoryScreenState();
}

class _AnomalyHistoryScreenState extends ConsumerState<AnomalyHistoryScreen> {
  bool showOldestFirst = false;

  @override
  void initState() {
    super.initState();
    // Atur bottom nav bar index saat layar ini dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentNavIndexProvider.notifier).state = 1; // 1 untuk History
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(anomaliesListProvider(widget.cameraId));
    final readIds = ref.watch(anomalyReadControllerProvider);
    final authState = ref.watch(authStateProvider);
    final avatarPath = ref.watch(profileAvatarProvider);

    String _userInitial() => authState.maybeWhen(
          authenticated: (_, user) =>
              user.email.isNotEmpty ? user.email[0].toUpperCase() : '?',
          orElse: () => '?',
        );

    Widget _profileAvatar() {
      if (avatarPath != null && avatarPath.isNotEmpty) {
        final file = File(avatarPath);
        if (file.existsSync()) {
          return CircleAvatar(
            radius: 11,
            backgroundImage: FileImage(file),
          );
        }
      }
      return CircleAvatar(
        radius: 11,
        backgroundColor: Theme.of(context)
            .colorScheme
            .primary
            .withAlpha((0.18 * 255).round()),
        child: Text(
          _userInitial(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.push('/account'),
            child: _profileAvatar(),
          ),
        ),
        title: Text(
          'History',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        actions: [
          PopupMenuButton<bool>(
            tooltip: 'Sort anomalies',
            initialValue: showOldestFirst,
            onSelected: (value) {
              setState(() => showOldestFirst = value);
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: false,
                checked: !showOldestFirst,
                child: const Text('Newest first'),
              ),
              CheckedPopupMenuItem(
                value: true,
                checked: showOldestFirst,
                child: const Text('Oldest first'),
              ),
            ],
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.read(anomaliesListProvider(widget.cameraId).notifier).load(),
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (items) {
            final ordered = showOldestFirst
                ? items.reversed.toList()
                : items.toList();
            if (items.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 60,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text('No recent alerts found.'),
                  ],
                ),
              );
            }

            // Langsung gunakan ListView.builder tanpa pengelompokan
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.horizontal,
                AppSpacing.vertical,
                AppSpacing.horizontal,
                AppSpacing.vertical,
              ),
              itemCount: ordered.length,
              itemBuilder: (context, index) {
                final anomaly = ordered[index];
                return AnimatedListItem(
                  index: index,
                  child: AnomalyCard(
                    item: anomaly,
                    isRead: readIds.contains(anomaly.id),
                    onTap: () {
                      ref
                          .read(anomalyReadControllerProvider.notifier)
                          .markRead(anomaly.id);
                      context.push('/anomalies/${anomaly.id}');
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }
}
