import 'package:anomeye/features/anomalies/presentation/anomaly_controllers.dart';
import 'package:anomeye/features/anomalies/presentation/widgets/animated_list_item.dart';
import 'package:anomeye/features/anomalies/presentation/widgets/anomaly_card.dart';
import 'package:anomeye/features/cameras/presentation/cameras_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF024670),
        centerTitle: true,
        title: SizedBox(
          height: 50,
          child: Image.asset('assets/images/anomeye.png',fit: BoxFit.contain,),
        ),
        actions: [
          IconButton(onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings_outlined),),
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
              padding: const EdgeInsets.all(16),
              children: [
                // --- Bagian Live Cameras ---
                SectionHeader(
                  title: 'Live Cameras',
                  onSeeAll: () {/* Navigasi ke halaman semua kamera */},
                ),
                GridView.builder(
                  itemCount: cameraCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
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
                    final recentAnomalies = anomalies.take(3).toList();
                    return Column(
                      children: List.generate(recentAnomalies.length, (index) {
                        final anomaly = recentAnomalies[index];
                        // ANIMASI: Bungkus AnomalyCard dengan AnimatedListItem
                        // Index animasi dilanjutkan dari jumlah kamera agar berurutan
                        return AnimatedListItem(
                          index: cameraCount + index,
                          child: AnomalyCard(
                            item: anomaly,
                            onTap: () =>
                                context.push('/anomalies/${anomaly.id}'),
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
