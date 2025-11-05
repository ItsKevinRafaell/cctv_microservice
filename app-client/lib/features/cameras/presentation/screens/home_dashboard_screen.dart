import 'package:anomeye/app/di.dart';
import 'package:anomeye/features/anomalies/domain/anomaly.dart';
import 'package:anomeye/features/anomalies/presentation/anomaly_controllers.dart';
import 'package:anomeye/features/cameras/presentation/cameras_controller.dart';
import 'package:anomeye/features/cameras/presentation/widgets/camera_card.dart';
import 'package:anomeye/shared/widgets/app_bottom_nav_bar.dart';
import 'package:anomeye/shared/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final auth = ref.watch(authStateProvider);
    final user = auth.whenOrNull(authenticated: (_, user) => user);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(camerasListProvider.notifier).load();
            await ref.read(anomaliesListProvider(null).notifier).load();
          },
          child: camerasState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading cameras: $e')),
            data: (cameras) {
              final cameraCount = cameras.length.clamp(0, 4);
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: const Color(0xFFE0EDFF),
                                child: Text(
                                  user?.email.substring(0, 2).toUpperCase() ??
                                      'AN',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0C4EA3),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome back',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                              color: const Color(0xFF667085)),
                                    ),
                                    Text(
                                      user?.email.split('@').first ??
                                          'Security Lead',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0C4EA3), Color(0xFF0AA6E6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Live command center',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Monitor every site with unified intelligence and rapid response.',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color:
                                                  Colors.white.withOpacity(.85),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                FilledButton(
                                  onPressed: () => context.go('/cameras'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF0C4EA3),
                                  ),
                                  child: const Text('Full camera view'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Live cameras',
                      actionLabel: 'See all',
                      onSeeAll: () => context.push('/cameras'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid.builder(
                      itemCount: cameraCount,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.7,
                      ),
                      itemBuilder: (context, index) {
                        final camera = cameras[index];
                        return CameraCard(
                          camera: camera,
                          onTap: () => context.push('/camera/${camera.id}'),
                          onOpenLive: () => context.push('/live/${camera.id}'),
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Recent alerts',
                      actionLabel: 'View history',
                      onSeeAll: () => context.go('/history'),
                    ),
                  ),
                  anomaliesState.when(
                    loading: () => const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (e, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text('Could not load alerts: $e'),
                      ),
                    ),
                    data: (anomalies) {
                      final recentAnomalies = anomalies.take(4).toList();
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList.separated(
                          itemCount: recentAnomalies.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final anomaly = recentAnomalies[index];
                            return _AnomalyPreviewTile(
                              anomaly: anomaly,
                              onTap: () =>
                                  context.push('/anomalies/${anomaly.id}'),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }
}

class _AnomalyPreviewTile extends StatelessWidget {
  final Anomaly anomaly;
  final VoidCallback onTap;

  const _AnomalyPreviewTile({
    required this.anomaly,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timestamp = anomaly.reportedAt.toLocal().toString().substring(0, 19);
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: colorScheme.primary.withOpacity(0.12),
          child: Icon(Icons.shield_outlined, color: colorScheme.primary),
        ),
        title: Text(
          '${anomaly.anomalyType} detected',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Camera #${anomaly.cameraId}\n'),
              TextSpan(text: timestamp),
            ],
          ),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: const Color(0xFF667085)),
          maxLines: 2,
          overflow: TextOverflow.fade,
        ),
        trailing: Icon(Icons.chevron_right, color: colorScheme.primary),
      ),
    );
  }
}




