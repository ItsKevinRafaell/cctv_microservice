import 'package:anomeye/features/anomalies/presentation/anomaly_controllers.dart';
import 'package:anomeye/features/anomalies/presentation/anomaly_read_controller.dart';
import 'package:anomeye/features/anomalies/presentation/widgets/anomaly_card.dart';
import 'package:anomeye/shared/styles/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

class AnomalyDetailScreen extends ConsumerStatefulWidget {
  final String anomalyId;
  const AnomalyDetailScreen({super.key, required this.anomalyId});

  @override
  ConsumerState<AnomalyDetailScreen> createState() =>
      _AnomalyDetailScreenState();
}

class _AnomalyDetailScreenState extends ConsumerState<AnomalyDetailScreen> {
  VideoPlayerController? _player;
  bool _clipTried = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _playClip(String? url) async {
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clip URL tidak tersedia.')),
        );
      }
      return;
    }
    _clipTried = true;
    try {
      if (_player != null) {
        await _player!.pause();
        await _player!.dispose();
      }
      _player = VideoPlayerController.networkUrl(Uri.parse(url));
      await _player!.initialize();
      await _player!.play();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memutar clip: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final anomalyState = ref.watch(anomalyDetailProvider(widget.anomalyId));
    final readIds = ref.watch(anomalyReadControllerProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: anomalyState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (anomaly) {
          ref.read(anomalyReadControllerProvider.notifier).markRead(anomaly.id);
          final clipUrl = anomaly.videoClipUrl;
          final relatedAnomaliesState = ref.watch(
            anomaliesListProvider(anomaly.cameraId),
          );
          final has = _player != null && _player!.value.isInitialized;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text('Anomaly Detail'),
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
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              color: Colors.black,
                            ),
                            child: has
                                ? VideoPlayer(_player!)
                                : Center(
                                    child: IconButton(
                                      iconSize: 64,
                                      color: Colors.white70,
                                      icon: const Icon(
                                        Icons.play_circle_fill_rounded,
                                      ),
                                      onPressed: () => _playClip(clipUrl),
                                      tooltip: 'Play Clip',
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      if (clipUrl != null &&
                          clipUrl.isNotEmpty &&
                          _player == null &&
                          _clipTried)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Jika gagal memutar, pastikan URL bisa diakses dari emulator: $clipUrl',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        anomaly.anomalyType,
                        style: textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Detected on ${DateFormat.yMMMMEEEEd().add_jms().format(anomaly.reportedAt)}',
                        style: textTheme.titleSmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Chip(label: Text('Camera: ${anomaly.cameraId}')),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(
                              'Confidence: ${(anomaly.confidence * 100).toStringAsFixed(0)}%',
                            ),
                            backgroundColor: Colors.blue.shade100,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.videocam_outlined),
                        label: const Text('View camera'),
                        onPressed: () => context.push(
                          '/camera/${anomaly.cameraId}',
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('Open live feed'),
                        onPressed: () => context.push(
                          '/live/${anomaly.cameraId}',
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 48),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Share'),
                            onPressed: () {},
                          ),
                          TextButton.icon(
                            icon: const Icon(
                              Icons.download_for_offline_outlined,
                            ),
                            label: const Text('Download'),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const Divider(height: 48),
                      Text(
                        'More from ${anomaly.cameraId}',
                        style: textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      relatedAnomaliesState.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) =>
                            Text('Could not load related events: $e'),
                        data: (related) {
                          final otherAnomalies = related
                              .where((a) => a.id != anomaly.id)
                              .toList();
                          if (otherAnomalies.isEmpty) {
                            return const Text(
                              'No other events from this camera.',
                            );
                          }
                          return Column(
                            children: otherAnomalies.take(3).map((item) {
                              final alreadyRead = readIds.contains(item.id);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AnomalyCard(
                                  item: item,
                                  isRead: alreadyRead,
                                  onTap: () {
                                    ref
                                        .read(
                                          anomalyReadControllerProvider
                                              .notifier,
                                        )
                                        .markRead(item.id);
                                    context.push('/anomalies/${item.id}');
                                  },
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
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
