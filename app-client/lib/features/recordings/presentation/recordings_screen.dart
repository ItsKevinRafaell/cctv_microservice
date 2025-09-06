import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anomeye/features/recordings/domain/recording.dart';
import 'package:anomeye/features/recordings/presentation/recordings_controller.dart';

class RecordingsScreen extends ConsumerStatefulWidget {
  final String cameraId;
  const RecordingsScreen({super.key, required this.cameraId});

  @override
  ConsumerState<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends ConsumerState<RecordingsScreen> {
  DateTimeRange? range;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final to = DateTime.now().toUtc();
    final from = to.subtract(const Duration(hours: 24));
    ref.read(recordingsControllerProvider.notifier).fetch(
          widget.cameraId,
          from: range?.start ?? from,
          to: range?.end ?? to,
          presign: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Recordings • ${widget.cameraId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => _List(items: items),
      ),
    );
  }
}

class _List extends StatelessWidget {
  final List<Recording> items;
  const _List({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No recordings'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = items[i];
        final started = r.startedAt.toLocal();
        final ended = r.endedAt.toLocal();
        final dur = ended.difference(started);
        return ListTile(
          leading: const Icon(Icons.videocam_outlined),
          title: Text(
            '${started.toString().substring(0, 19)}  (${_hms(dur)})',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
              '${(r.sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB • ${r.key}'),
          trailing: IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () async {
              final url = r.url;
              if (url == null || url.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL belum tersedia.')),
                );
                return;
              }
              // TODO: navigate ke player screen, atau open with default player
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Open: ${r.key}')),
              );
            },
          ),
        );
      },
    );
  }

  String _hms(Duration d) {
    final s = d.inSeconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '00:$mm:$ss';
    // jika segmen 1 menit, hasil 00:01:00
  }
}
