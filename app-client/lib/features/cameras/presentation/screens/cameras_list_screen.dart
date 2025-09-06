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
        backgroundColor: const Color(0xFF024670),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (cameras) => GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: cameras.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
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

