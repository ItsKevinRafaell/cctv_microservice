import 'package:anomeye/features/anomalies/domain/anomaly.dart';
import 'package:flutter/material.dart';

class AnomalyTile extends StatelessWidget {
  const AnomalyTile({super.key, required this.item, this.onTap});
  final Anomaly item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
      title: Text(item.anomalyType),
      subtitle: Text(
        '${item.cameraId} • ${item.reportedAt}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text('${(item.confidence * 100).toStringAsFixed(0)}%'),
      onTap: onTap,
    );
  }
}
