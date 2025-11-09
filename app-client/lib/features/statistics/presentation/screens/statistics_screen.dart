import 'dart:io';
import 'dart:math' as math;

import 'package:anomeye/app/di.dart';
import 'package:anomeye/features/auth/presentation/profile_avatar_controller.dart';
import 'package:anomeye/features/statistics/domain/anomaly_statistics.dart';
import 'package:anomeye/features/statistics/presentation/statistics_controller.dart';
import 'package:anomeye/shared/styles/app_spacing.dart';
import 'package:anomeye/shared/widgets/app_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

enum _ChartRange { weekly, monthly }

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  _ChartRange _chartRange = _ChartRange.weekly;
  String _userInitial() {
    final authState = ref.watch(authStateProvider);
    return authState.maybeWhen(
      authenticated: (_, user) =>
          user.email.isNotEmpty ? user.email[0].toUpperCase() : '?',
      orElse: () => '?',
    );
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(anomalyStatisticsProvider);
    final avatarPath = ref.watch(profileAvatarProvider);

    Widget _profileAvatar() {
      if (avatarPath != null && avatarPath.isNotEmpty) {
        final file = File(avatarPath);
        if (file.existsSync()) {
          return CircleAvatar(
            radius: 11,
            backgroundImage: FileImage(file),
          );
        }
      }
      return CircleAvatar(
        radius: 11,
        backgroundColor: Theme.of(context)
            .colorScheme
            .primary
            .withAlpha((0.18 * 255).round()),
        child: Text(
          _userInitial(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.push('/account'),
            child: _profileAvatar(),
          ),
        ),
        title: Text(
          'Statistics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load statistics:\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () => ref.refresh(anomalyStatisticsProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.page,
            children: [
              _TrendSwitcherCard(
                stats: stats,
                range: _chartRange,
                onRangeChanged: (range) => setState(() {
                  _chartRange = range;
                }),
              ),
              const SizedBox(height: 20),
              _SummaryGrid(stats: stats),
              const SizedBox(height: 20),
              _DailyBreakdown(stats: stats),
              const SizedBox(height: 20),
              _MonthlyOverview(stats: stats),
              if (stats.topCameras.isNotEmpty) ...[
                const SizedBox(height: 20),
                _TopCameras(stats: stats),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.stats});

  final AnomalyStatistics stats;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _Metric(
        label: 'Today',
        value: stats.todayCount,
        icon: Icons.flash_on_outlined,
      ),
      _Metric(
        label: 'Last 7 days',
        value: stats.weekCount,
        icon: Icons.view_week,
      ),
      _Metric(
        label: 'This month',
        value: stats.monthCount,
        icon: Icons.calendar_month_outlined,
      ),
      _Metric(
        label: 'Total captured',
        value: stats.totalCount,
        icon: Icons.all_inclusive,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = AppSpacing.gridGap;
        final maxWidth = constraints.maxWidth;
        final twoColumns = maxWidth >= 360;
        final cardWidth =
            twoColumns ? (maxWidth - spacing) / 2 : maxWidth;
        return Align(
          alignment: Alignment.center,
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: metrics
                .map(
                  (metric) => SizedBox(
                    width: cardWidth,
                    child: _MetricCard(metric: metric),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _Metric {
  final String label;
  final int value;
  final IconData icon;

  const _Metric({required this.label, required this.value, required this.icon});
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradientColors = isDark
        ? [
            const Color(0xE01A1435),
            const Color(0xD0100C25),
          ]
        : [
            const Color(0xFFE4EEFF),
            const Color(0xFFD5E5FF),
          ];
    final textColor =
        isDark ? Colors.white : const Color(0xFF1A2B49);
    final iconColor = isDark ? Colors.white : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: _opacity(Colors.black, isDark ? 0.3 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SizedBox(
        height: 90,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: isDark
                  ? _opacity(Colors.white, 0.15)
                  : _opacity(theme.colorScheme.primary, 0.12),
              child: Icon(metric.icon, size: 16, color: iconColor),
            ),
            Text(
              '${metric.value}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            Text(
              metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _opacity(textColor, 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyBreakdown extends StatelessWidget {
  const _DailyBreakdown({required this.stats});

  final AnomalyStatistics stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('EEE');
    final max = stats.lastSevenDays.fold<int>(
      0,
      (previousValue, element) =>
          previousValue > element.count ? previousValue : element.count,
    );

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily breakdown',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          for (final entry in stats.lastSevenDays) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatter.format(entry.day)),
                Text('${entry.count}'),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: max == 0 ? 0 : entry.count / max,
                backgroundColor: _opacity(theme.colorScheme.primary, 0.12),
                valueColor:
                    AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _MonthlyOverview extends StatelessWidget {
  const _MonthlyOverview({required this.stats});

  final AnomalyStatistics stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('MMM yyyy');
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly overview',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...stats.lastSixMonths.map((entry) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(formatter.format(entry.month)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _opacity(theme.colorScheme.primary, 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${entry.count}'),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _TrendSwitcherCard extends StatelessWidget {
  const _TrendSwitcherCard({
    required this.stats,
    required this.range,
    required this.onRangeChanged,
  });

  final AnomalyStatistics stats;
  final _ChartRange range;
  final ValueChanged<_ChartRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWeekly = range == _ChartRange.weekly;
    final labels = isWeekly
        ? stats.lastSevenDays.map((e) => DateFormat('E').format(e.day)).toList()
        : stats.lastSixMonths
            .map((e) => DateFormat('MMM').format(e.month))
            .toList();
    final values = isWeekly
        ? stats.lastSevenDays.map((e) => e.count).toList()
        : stats.lastSixMonths.map((e) => e.count).toList();

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trend overview',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            isWeekly ? 'Last 7 days' : 'Last 6 months',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _TrendChart(
            values: values.map((e) => e.toDouble()).toList(),
            labels: labels,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.center,
            child: SegmentedButton<_ChartRange>(
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: _ChartRange.weekly,
                  label: Text('Weekly'),
                ),
                ButtonSegment(
                  value: _ChartRange.monthly,
                  label: Text('Monthly'),
                ),
              ],
              selected: {range},
              onSelectionChanged: (selected) {
                if (selected.isNotEmpty) onRangeChanged(selected.first);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.values,
    required this.labels,
    required this.color,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: _opacityOrNull(
            Theme.of(context).textTheme.bodySmall?.color,
            0.7,
          ),
        );
    final double maxValue =
        values.isEmpty ? 1.0 : math.max(values.reduce(math.max), 1);
    final ySteps = List.generate(
      4,
      (index) => ((maxValue / 3) * (3 - index)).round(),
    );

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ySteps
                    .map(
                      (value) => Text(
                        '$value',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: _opacity(
                                Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.color ??
                                    Colors.white,
                                0.6,
                              ),
                            ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomPaint(
                  painter: _BarChartPainter(
                    values: values,
                    maxValue: maxValue,
                    barColor: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (labels.isNotEmpty)
          Row(
            children: labels
                .map(
                  (label) => Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: labelStyle,
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.values,
    required this.maxValue,
    required this.barColor,
  });

  final List<double> values;
  final double maxValue;
  final Color barColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final double safeMax = maxValue <= 0 ? 1 : maxValue;
    final barSpacing = size.width / (values.length * 1.5);
    final barWidth = barSpacing;

    // Draw baseline and grid
    final gridPaint = Paint()
      ..color = _opacity(Colors.white, 0.1)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final dy = size.height - (size.height / 3) * i;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    double x = 0;
    for (final value in values) {
      final barHeight = (value / safeMax) * size.height;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          size.height - barHeight,
          barWidth,
          barHeight,
        ),
        const Radius.circular(8),
      );
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            barColor,
            _opacity(barColor, 0.5),
          ],
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);
      x += barWidth * 1.5;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _TopCameras extends StatelessWidget {
  const _TopCameras({required this.stats});

  final AnomalyStatistics stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Most active cameras',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...stats.topCameras.map((camera) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: _opacity(
                  theme.colorScheme.secondary,
                  theme.brightness == Brightness.dark ? 0.2 : 0.12,
                ),
                foregroundColor: theme.colorScheme.secondary,
                child: const Icon(Icons.videocam_outlined),
              ),
              title: Text(camera.cameraId),
              trailing: Text(
                '${camera.count}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark
              ? const Color(0x14FFFFFF)
              : const Color(0x592E63C7),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xEB1F1745),
                  const Color(0xD1120B27),
                ]
              : [
                  const Color(0xEBE5EEFF),
                  const Color(0xD9D5E5FF),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: _opacity(Colors.black, isDark ? 0.35 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

Color _opacity(Color color, double opacity) {
  final alpha = (opacity.clamp(0, 1) * 255).round();
  return color.withAlpha(alpha);
}

Color? _opacityOrNull(Color? color, double opacity) {
  if (color == null) return null;
  return _opacity(color, opacity);
}
