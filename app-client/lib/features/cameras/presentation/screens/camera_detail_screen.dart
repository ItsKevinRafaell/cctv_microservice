import 'package:anomeye/features/cameras/presentation/cameras_controller.dart';
import 'package:anomeye/features/streaming/domain/stream_url_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      body: cameraAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (camera) {
          final hlsUrl = ref.watch(streamUrlProvider(camera.id));
          final statusColor =
              camera.online ? const Color(0xFF12B76A) : const Color(0xFFD92D20);
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    Expanded(
                      child: Text(
                        camera.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          context.push('/cameras/${camera.id}/recordings'),
                      icon: const Icon(Icons.video_library_outlined),
                      tooltip: 'Recordings',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF111928), Color(0xFF20385C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: InkWell(
                          onTap: () => context.push('/live/${camera.id}', extra: hlsUrl),
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: 72,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(.35),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                camera.online ? 'Online' : 'Offline',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.push('/live/${camera.id}', extra: hlsUrl),
                  icon: const Icon(Icons.fullscreen),
                  label: const Text('Open full camera view'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    textStyle: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camera.location ?? 'No registered location',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          Chip(
                            backgroundColor: statusColor.withOpacity(.12),
                            label: Text(
                              camera.online ? 'Streaming normal' : 'Stream offline',
                              style: TextStyle(color: statusColor),
                            ),
                          ),
                          Chip(
                            label: Text('Active alerts: ${camera.activeAlerts}'),
                          ),
                          Chip(
                            label: Text('Camera ID: ${camera.id}'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stream endpoint',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        hlsUrl,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      if (camera.streamUrl != null &&
                          camera.streamUrl!.isNotEmpty &&
                          camera.streamUrl != hlsUrl) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Backend URL',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          camera.streamUrl!,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
