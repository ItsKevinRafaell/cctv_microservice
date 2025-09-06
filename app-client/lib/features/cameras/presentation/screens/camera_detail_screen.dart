import 'package:anomeye/features/cameras/presentation/cameras_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Note: Adjust this import path as needed.

class CameraDetailScreen extends ConsumerStatefulWidget {
  final String cameraId;
  const CameraDetailScreen({super.key, required this.cameraId});

  @override
  ConsumerState<CameraDetailScreen> createState() => _CameraDetailScreenState();
}

class _CameraDetailScreenState extends ConsumerState<CameraDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch the specific camera's details when this screen loads.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cameraDetailProvider(widget.cameraId).notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the family provider with the specific camera ID.
    final cameraAsyncValue = ref.watch(cameraDetailProvider(widget.cameraId));

    return Scaffold(
      // Use the data from the provider to build the UI.
      body: cameraAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (camera) => CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(camera.name),
              pinned: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.play_circle_outline,
                            size: 64, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(camera.location ?? 'No location',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Chip(label: Text(camera.online ? 'Online' : 'Offline')),
                        const SizedBox(width: 8),
                        Chip(label: Text('Alerts: ${camera.activeAlerts}')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Stream URL',
                        style: Theme.of(context).textTheme.titleSmall),
                    SelectableText(camera.streamUrl ?? 'No stream URL'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
