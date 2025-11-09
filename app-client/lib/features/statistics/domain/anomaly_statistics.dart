import 'package:anomeye/features/anomalies/domain/anomaly.dart';

class AnomalyDailyStat {
  final DateTime day;
  final int count;

  const AnomalyDailyStat({required this.day, required this.count});
}

class AnomalyMonthlyStat {
  final DateTime month;
  final int count;

  const AnomalyMonthlyStat({required this.month, required this.count});
}

class CameraStat {
  final String cameraId;
  final int count;

  const CameraStat({required this.cameraId, required this.count});
}

class AnomalyStatistics {
  final int todayCount;
  final int weekCount;
  final int monthCount;
  final int totalCount;
  final List<AnomalyDailyStat> lastSevenDays;
  final List<AnomalyMonthlyStat> lastSixMonths;
  final List<CameraStat> topCameras;

  const AnomalyStatistics({
    required this.todayCount,
    required this.weekCount,
    required this.monthCount,
    required this.totalCount,
    required this.lastSevenDays,
    required this.lastSixMonths,
    required this.topCameras,
  });

  factory AnomalyStatistics.from(List<Anomaly> anomalies) {
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    final weekThreshold = todayKey.subtract(const Duration(days: 6));

    final Map<DateTime, int> dailyCounts = {};
    final Map<DateTime, int> monthlyCounts = {};
    final Map<String, int> cameraCounts = {};

    var today = 0;
    var week = 0;
    var month = 0;

    for (final anomaly in anomalies) {
      final local = anomaly.reportedAt.toLocal();
      final dayKey = DateTime(local.year, local.month, local.day);
      final monthKey = DateTime(local.year, local.month);

      dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + 1;
      monthlyCounts[monthKey] = (monthlyCounts[monthKey] ?? 0) + 1;
      cameraCounts[anomaly.cameraId] =
          (cameraCounts[anomaly.cameraId] ?? 0) + 1;

      if (dayKey == todayKey) {
        today++;
      }
      if (!dayKey.isBefore(weekThreshold)) {
        week++;
      }
      if (local.year == now.year && local.month == now.month) {
        month++;
      }
    }

    final List<AnomalyDailyStat> lastSevenDays = List.generate(7, (index) {
      final day = todayKey.subtract(Duration(days: 6 - index));
      return AnomalyDailyStat(day: day, count: dailyCounts[day] ?? 0);
    });

    final List<AnomalyMonthlyStat> lastSixMonths = <AnomalyMonthlyStat>[];
    var cursor = DateTime(now.year, now.month);
    for (var i = 0; i < 6; i++) {
      final monthKey = DateTime(cursor.year, cursor.month);
      lastSixMonths.insert(
        0,
        AnomalyMonthlyStat(
          month: monthKey,
          count: monthlyCounts[monthKey] ?? 0,
        ),
      );
      cursor = DateTime(cursor.year, cursor.month - 1);
    }

    final top = cameraCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCameras = top
        .take(3)
        .map((entry) => CameraStat(cameraId: entry.key, count: entry.value))
        .toList();

    return AnomalyStatistics(
      todayCount: today,
      weekCount: week,
      monthCount: month,
      totalCount: anomalies.length,
      lastSevenDays: lastSevenDays,
      lastSixMonths: lastSixMonths,
      topCameras: topCameras,
    );
  }
}
