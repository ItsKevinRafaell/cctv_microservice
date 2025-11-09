import 'dart:io';

import 'package:anomeye/features/anomalies/presentation/anomaly_controllers.dart';
import 'package:anomeye/features/anomalies/presentation/anomaly_read_controller.dart';
import 'package:anomeye/features/anomalies/presentation/widgets/animated_list_item.dart';
import 'package:anomeye/features/anomalies/presentation/widgets/anomaly_card.dart';
import 'package:anomeye/app/di.dart';
import 'package:anomeye/features/cameras/presentation/cameras_controller.dart';
import 'package:anomeye/features/auth/presentation/profile_avatar_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:anomeye/shared/styles/app_spacing.dart';
import 'package:anomeye/shared/widgets/section_header.dart';
import 'package:anomeye/features/cameras/presentation/widgets/camera_card.dart';
import 'package:anomeye/shared/widgets/app_bottom_nav_bar.dart';

class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentNavIndexProvider.notifier).state = 0;
      if (ref.read(camerasListProvider) is AsyncLoading) {
        ref.read(camerasListProvider.notifier).load();
      }
      if (ref.read(anomaliesListProvider(null)) is AsyncLoading) {
        ref.read(anomaliesListProvider(null).notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final camerasState = ref.watch(camerasListProvider);
    final anomaliesState = ref.watch(anomaliesListProvider(null));
    final readIds = ref.watch(anomalyReadControllerProvider);
    final authState = ref.watch(authStateProvider);
    final avatarPath = ref.watch(profileAvatarProvider);

    String _userInitial() {
      return authState.maybeWhen(
        authenticated: (_, user) =>
            user.email.isNotEmpty ? user.email[0].toUpperCase() : '?',
        orElse: () => '?',
      );
    }

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
          'AnomEye',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(camerasListProvider.notifier).load();
          await ref.read(anomaliesListProvider(null).notifier).load();
        },
        child: camerasState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading cameras: $e')),
          data: (cameras) {
            final cameraCount = cameras.length > 4 ? 4 : cameras.length;

            return ListView(
              padding: AppSpacing.page,
              children: [
                // --- Bagian Live Cameras ---
                SectionHeader(
                  title: 'Live Cameras',
                  onSeeAll: () {
                    context.push('/cameras');
                  },
                ),
                GridView.builder(
                  itemCount: cameraCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.gridGap,
                    mainAxisSpacing: AppSpacing.gridGap,
                    childAspectRatio: 0.68,
                  ),
                  itemBuilder: (context, index) {
                    final camera = cameras[index];
                    // ANIMASI: Bungkus CameraCard dengan AnimatedListItem
                    return AnimatedListItem(
                      index: index,
                      child: CameraCard(
                        camera: camera,
                        onTap: () => context.push('/camera/${camera.id}'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // --- Bagian Recent Alerts ---
                SectionHeader(
                  title: 'Recent Alerts',
                  onSeeAll: () => context.go('/history'),
                ),
                anomaliesState.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) =>
                      Center(child: Text('Could not load alerts: $e')),
                  data: (anomalies) {
                    final recentAnomalies = anomalies
                        .where((a) => !readIds.contains(a.id))
                        .take(3)
                        .toList();
                    if (recentAnomalies.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'No new alerts',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: List.generate(recentAnomalies.length, (index) {
                        final anomaly = recentAnomalies[index];
                        // ANIMASI: Bungkus AnomalyCard dengan AnimatedListItem
                        // Index animasi dilanjutkan dari jumlah kamera agar berurutan
                        return AnimatedListItem(
                          index: cameraCount + index,
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
                      }),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }
}
