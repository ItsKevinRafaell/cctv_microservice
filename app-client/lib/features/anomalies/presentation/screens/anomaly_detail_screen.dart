import 'package:anomeye/features/anomalies/presentation/anomaly_controllers.dart';
import 'package:anomeye/features/anomalies/presentation/widgets/anomaly_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnomalyDetailScreen extends ConsumerWidget {
  final String anomalyId;
  const AnomalyDetailScreen({super.key, required this.anomalyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anomalyState = ref.watch(anomalyDetailProvider(anomalyId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: anomalyState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (anomaly) {
          // Tonton juga anomali lain dari kamera yang sama
          final relatedAnomaliesState =
              ref.watch(anomaliesListProvider(anomaly.cameraId));

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back), // Or any other icon
                  onPressed: () {
                    Navigator.pop(
                        context); // Navigates back to the previous route
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Placeholder untuk Video Player
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.play_circle_fill_rounded,
                                color: Colors.white70, size: 64),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 2. Detail Utama Anomali
                      Text(anomaly.anomalyType,
                          style: textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Detected on ${DateFormat.yMMMMEEEEd().add_jms().format(anomaly.reportedAt)}',
                        style: textTheme.titleSmall
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Chip(label: Text('Camera: ${anomaly.cameraId}')),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(
                                'Confidence: ${(anomaly.confidence * 100).toStringAsFixed(0)}%'),
                            backgroundColor: Colors.blue.shade100,
                          ),
                        ],
                      ),
                      const Divider(height: 48),

                      // 3. Tombol Aksi
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Share'),
                            onPressed: () {},
                          ),
                          TextButton.icon(
                            icon:
                                const Icon(Icons.download_for_offline_outlined),
                            label: const Text('Download'),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const Divider(height: 48),

                      // 4. Anomali Terkait dari Kamera yang Sama
                      Text('More from ${anomaly.cameraId}',
                          style: textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      relatedAnomaliesState.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) =>
                            Text('Could not load related events: $e'),
                        data: (related) {
                          final otherAnomalies =
                              related.where((a) => a.id != anomaly.id).toList();
                          if (otherAnomalies.isEmpty) {
                            return const Text(
                                'No other events from this camera.');
                          }
                          return Column(
                            children: otherAnomalies
                                .take(3)
                                .map((item) => AnomalyCard(item: item))
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}
