import 'package:anomeye/features/cameras/domain/camera.dart';
import 'package:anomeye/features/cameras/presentation/cameras_controller.dart';
import 'package:anomeye/features/streaming/domain/stream_url_builder.dart';
import 'package:anomeye/shared/styles/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

class CameraDetailScreen extends ConsumerStatefulWidget {
  const CameraDetailScreen({super.key, required this.cameraId});

  final String cameraId;

  @override
  ConsumerState<CameraDetailScreen> createState() => _CameraDetailScreenState();
}

class _CameraDetailScreenState extends ConsumerState<CameraDetailScreen> {
  VideoPlayerController? _liveController;
  bool _liveError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cameraDetailProvider(widget.cameraId).notifier).load();
    });
  }

  @override
  void dispose() {
    _liveController?.dispose();
    super.dispose();
  }

  void _ensureLivePlayer(Camera camera) {
    if (_liveController != null || _liveError) return;
    final String url =
        camera.streamUrl ?? ref.read(streamUrlProvider(camera.id));
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _liveController = controller;
    controller.setLooping(true);
    controller.initialize().then((_) {
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {});
      controller.play();
    }).catchError((_) {
      controller.dispose();
      if (mounted) {
        setState(() {
          _liveController = null;
          _liveError = true;
        });
      } else {
        _liveController = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cameraAsyncValue = ref.watch(cameraDetailProvider(widget.cameraId));

    return Scaffold(
      body: cameraAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (camera) {
          _ensureLivePlayer(camera);
          final controller = _liveController;
          final hasController =
              controller != null && controller.value.isInitialized;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(camera.name),
                pinned: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.page,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              color: Colors.black,
                            ),
                            child: hasController
                                ? VideoPlayer(controller!)
                                : _liveError
                                    ? const Center(
                                        child: Text(
                                          'Unable to start live stream',
                                          style:
                                              TextStyle(color: Colors.white70),
                                        ),
                                      )
                                    : const Center(
                                        child: CircularProgressIndicator
                                            .adaptive(),
                                      ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.fullscreen),
                            label: const Text('Open full screen'),
                            onPressed: () => context.push(
                              '/live/${camera.id}',
                              extra: camera.streamUrl,
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.video_library_outlined),
                            label: const Text('Recordings'),
                            onPressed: () => context.push(
                              '/cameras/${camera.id}/recordings',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        camera.location ?? 'No location',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Chip(
                            label: Text(camera.online ? 'Online' : 'Offline'),
                          ),
                          const SizedBox(width: 8),
                          Chip(label: Text('Alerts: ${camera.activeAlerts}')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Stream URL',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      SelectableText(camera.streamUrl ?? 'No stream URL'),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
