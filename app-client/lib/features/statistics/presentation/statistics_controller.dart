import 'package:anomeye/features/anomalies/presentation/anomaly_controllers.dart';
import 'package:anomeye/features/statistics/domain/anomaly_statistics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final anomalyStatisticsProvider = FutureProvider.autoDispose<AnomalyStatistics>(
  (ref) async {
    final repo = ref.watch(anomaliesRepoProvider);
    final anomalies = await repo.listRecent(limit: 300);
    return AnomalyStatistics.from(anomalies);
  },
);
