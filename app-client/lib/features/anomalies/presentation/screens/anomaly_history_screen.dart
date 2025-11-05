import 'package:anomeye/features/anomalies/presentation/anomaly_controllers.dart';
import 'package:anomeye/features/anomalies/domain/anomaly.dart';
import 'package:anomeye/shared/widgets/app_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:anomeye/features/anomalies/presentation/widgets/anomaly_card.dart';
import 'package:go_router/go_router.dart';

class AnomalyHistoryScreen extends ConsumerStatefulWidget {
  const AnomalyHistoryScreen({super.key, this.cameraId});
  final String? cameraId;

  @override
  ConsumerState<AnomalyHistoryScreen> createState() =>
      _AnomalyHistoryScreenState();
}

class _AnomalyHistoryScreenState extends ConsumerState<AnomalyHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Atur bottom nav bar index saat layar ini dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentNavIndexProvider.notifier).state = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(anomaliesListProvider(widget.cameraId));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.read(anomaliesListProvider(widget.cameraId).notifier).load(),
          child: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (items) {
              if (items.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
                  children: const [
                    Icon(Icons.check_circle_outline,
                        size: 64, color: Color(0xFF98A2B3)),
                    SizedBox(height: 16),
                    Text(
                      'No recent alerts',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Great job! Your perimeters are all clear.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF667085)),
                    ),
                  ],
                );
              }

              final groupedByDate = <DateTime, List<Anomaly>>{};
              for (final anomaly in items) {
                final dateKey = DateTime(anomaly.reportedAt.year,
                    anomaly.reportedAt.month, anomaly.reportedAt.day);
                groupedByDate.putIfAbsent(dateKey, () => []).add(anomaly);
              }
              final sortedDates = groupedByDate.keys.toList()
                ..sort((a, b) => b.compareTo(a));

              return ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_outlined,
                          color: Color(0xFF0C4EA3)),
                      const SizedBox(width: 10),
                      Text(
                        'Alert centre',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      if (widget.cameraId != null)
                        TextButton(
                          onPressed: () => context.go('/history'),
                          child: const Text('View all'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < sortedDates.length; i++) ...[
                    _DateSectionHeader(date: sortedDates[i]),
                    const SizedBox(height: 8),
                    for (final anomaly in groupedByDate[sortedDates[i]]!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: AnomalyCard(
                            item: anomaly,
                            onTap: () =>
                                context.push('/anomalies/${anomaly.id}'),
                          ),
                        ),
                      ),
                    if (i != sortedDates.length - 1)
                      const SizedBox(height: 8),
                  ]
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }
}

class _DateSectionHeader extends StatelessWidget {
  const _DateSectionHeader({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      _labelFor(date),
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1C2433),
      ),
    );
  }

  String _labelFor(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return 'Today';
    if (target == yesterday) return 'Yesterday';
    return DateFormat('EEEE, d MMM yyyy').format(date);
  }
}
