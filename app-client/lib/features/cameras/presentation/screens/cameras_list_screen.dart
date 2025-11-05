import 'package:anomeye/features/cameras/presentation/cameras_controller.dart';
import 'package:anomeye/features/cameras/presentation/widgets/camera_card.dart';
import 'package:anomeye/shared/widgets/app_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CamerasListScreen extends ConsumerStatefulWidget {
  const CamerasListScreen({super.key});

  @override
  ConsumerState<CamerasListScreen> createState() => _CamerasListScreenState();
}

class _CamerasListScreenState extends ConsumerState<CamerasListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Home tab for cameras list
      ref.read(currentNavIndexProvider.notifier).state = 1;
      if (ref.read(camerasListProvider) is AsyncLoading) {
        ref.read(camerasListProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(camerasListProvider);
    return Scaffold(
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (cameras) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.video_camera_front_outlined,
                              color: Color(0xFF0C4EA3)),
                          const SizedBox(width: 10),
                          Text(
                            'All cameras',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () =>
                                ref.read(camerasListProvider.notifier).load(),
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Refresh',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0EDFF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.shield_moon_outlined,
                                  color: Color(0xFF0C4EA3)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                cameras.any((c) => !c.online)
                                    ? 'Some cameras need attention'
                                    : 'All cameras are streaming normally',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                sliver: SliverGrid.builder(
                  itemCount: cameras.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, index) {
                    final cam = cameras[index];
                    return CameraCard(
                      camera: cam,
                      onTap: () => context.push('/camera/${cam.id}'),
                      onOpenLive: () => context.push('/live/${cam.id}'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }
}

