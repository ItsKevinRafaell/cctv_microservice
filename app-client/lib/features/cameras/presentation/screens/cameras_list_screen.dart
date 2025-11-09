import 'package:anomeye/features/cameras/presentation/cameras_controller.dart';
import 'package:anomeye/features/cameras/presentation/widgets/camera_card.dart';
import 'package:anomeye/shared/styles/app_spacing.dart';
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
      ref.read(currentNavIndexProvider.notifier).state = 0;
      if (ref.read(camerasListProvider) is AsyncLoading) {
        ref.read(camerasListProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(camerasListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Cameras'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (cameras) => GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.horizontal,
            AppSpacing.vertical,
            AppSpacing.horizontal,
            AppSpacing.vertical,
          ),
          itemCount: cameras.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.gridGap,
            mainAxisSpacing: AppSpacing.gridGap,
            childAspectRatio: 0.68,
          ),
          itemBuilder: (context, index) {
            final cam = cameras[index];
            return CameraCard(
              camera: cam,
              onTap: () => context.push('/camera/${cam.id}'),
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }
}
