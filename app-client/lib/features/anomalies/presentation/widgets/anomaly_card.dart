import 'package:anomeye/features/anomalies/domain/anomaly.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnomalyCard extends StatelessWidget {
  const AnomalyCard({
    super.key,
    required this.item,
    this.onTap,
    this.isRead = false,
  });

  final Anomaly item;
  final VoidCallback? onTap;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final gradientColors = isRead
        ? [
            isDark
                ? Colors.white.withOpacity(0.08)
                : const Color(0xFFF4F7FF).withOpacity(0.9),
            isDark
                ? Colors.white.withOpacity(0.04)
                : const Color(0xFFE8EEFF).withOpacity(0.82),
          ]
        : [
            isDark
                ? const Color(0xFF2B1E58).withOpacity(0.92)
                : const Color(0xFFE2ECFF).withOpacity(0.95),
            isDark
                ? const Color(0xFF160F2F).withOpacity(0.85)
                : const Color(0xFFD0E0FF).withOpacity(0.86),
          ];

    final borderColor = isRead
        ? Colors.transparent
        : colors.primary.withOpacity(isDark ? 0.35 : 0.4);

    final timestamp = DateFormat.Hm().format(item.reportedAt);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isRead ? 0.6 : 1.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isRead ? 0.04 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: colors.primary,
                      size: 28,
                    ),
                  ),
                  if (!isRead)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors.error,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.error.withOpacity(0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.anomalyType,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.cameraId} - $timestamp',
                      style: textTheme.bodyMedium?.copyWith(
                        color: textTheme.bodyMedium?.color?.withOpacity(
                          isRead ? 0.55 : 0.85,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(item.confidence * 100).toStringAsFixed(0)}%',
                style: textTheme.titleMedium?.copyWith(
                  color: isRead
                      ? colors.primary.withOpacity(0.65)
                      : colors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
