import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Tambahkan package: flutter pub add intl
import 'package:anomeye/features/anomalies/domain/anomaly.dart';

class AnomalyCard extends StatelessWidget {
  final Anomaly item;
  final VoidCallback? onTap;

  const AnomalyCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      // clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: Colors.black26,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Icon di sebelah kiri
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_amber_rounded,
                    color: colorScheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              // Kolom untuk detail teks
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.anomalyType,
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.cameraId} • ${DateFormat.Hm().format(item.reportedAt)}', // Format jam:menit
                      style: textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              // Teks confidence di sebelah kanan
              const SizedBox(width: 16),
              Text(
                '${(item.confidence * 100).toStringAsFixed(0)}%',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
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
