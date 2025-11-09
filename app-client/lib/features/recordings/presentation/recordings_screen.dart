import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import 'package:anomeye/features/recordings/domain/recording.dart';
import 'package:anomeye/features/recordings/presentation/recordings_controller.dart';
import 'package:anomeye/shared/styles/app_spacing.dart';

class RecordingsScreen extends ConsumerStatefulWidget {
  const RecordingsScreen({super.key, required this.cameraId});

  final String cameraId;

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
    final now = DateTime.now();
    final selected = range;
    final startLocal =
        selected?.start ?? now.subtract(const Duration(hours: 24));
    final endLocal = selected != null
        ? selected.end
            .add(const Duration(days: 1))
            .subtract(const Duration(seconds: 1))
        : now;
    ref.read(recordingsControllerProvider.notifier).fetch(
          widget.cameraId,
          from: startLocal.toUtc(),
          to: endLocal.toUtc(),
          presign: true,
        );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initial = range ??
        DateTimeRange(
          start: now.subtract(const Duration(hours: 24)),
          end: now,
        );
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => range = picked);
      _reload();
    }
  }

  Future<void> _openRecording(Recording recording) async {
    final url = recording.url;
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL belum tersedia.')),
      );
      return;
    }
    await showDialog(
      context: context,
      builder: (_) => RecordingPlayerDialog(recording: recording),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Recordings - ${widget.cameraId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: _pickRange,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reload),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => _RecordingsList(
          items: items,
          onPlay: _openRecording,
          header: _RangeHeader(
            range: range,
            onPick: _pickRange,
            onClear: () {
              setState(() => range = null);
              _reload();
            },
          ),
        ),
      ),
    );
  }
}

class _RecordingsList extends StatelessWidget {
  const _RecordingsList({
    required this.items,
    required this.onPlay,
    required this.header,
  });

  final List<Recording> items;
  final void Function(Recording) onPlay;
  final Widget header;

  @override
  Widget build(BuildContext context) {
    final padding = const EdgeInsets.fromLTRB(
      AppSpacing.horizontal,
      AppSpacing.vertical,
      AppSpacing.horizontal,
      AppSpacing.vertical,
    );
    if (items.isEmpty) {
      return ListView(
        padding: padding,
        children: [
          header,
          const SizedBox(height: 24),
          const Center(child: Text('No recordings')),
        ],
      );
    }
    return ListView.separated(
      padding: padding,
      itemCount: items.length + 1,
      separatorBuilder: (_, index) =>
          index == 0 ? const SizedBox(height: 16) : const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == 0) return header;
        final recording = items[index - 1];
        final started = recording.startedAt.toLocal();
        final ended = recording.endedAt.toLocal();
        final dur = ended.difference(started);
        return ListTile(
          leading: const Icon(Icons.videocam_outlined),
          title: Text(
            '${DateFormat.yMMMd().add_Hm().format(started)} (${_hms(dur)})',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${(recording.sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB - ${recording.key}',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () => onPlay(recording),
          ),
        );
      },
    );
  }

  String _hms(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _RangeHeader extends StatelessWidget {
  const _RangeHeader({
    required this.range,
    required this.onPick,
    required this.onClear,
  });

  final DateTimeRange? range;
  final Future<void> Function() onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = range == null
        ? 'Last 24 hours'
        : '${DateFormat.yMMMd().format(range!.start)} – ${DateFormat.yMMMd().format(range!.end)}';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recording window',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
        TextButton.icon(
          icon: const Icon(Icons.filter_alt),
          label: const Text('Change'),
          onPressed: () => onPick(),
        ),
        if (range != null)
          IconButton(
            tooltip: 'Reset filter',
            icon: const Icon(Icons.close),
            onPressed: onClear,
          ),
      ],
    );
  }
}

class RecordingPlayerDialog extends StatefulWidget {
  const RecordingPlayerDialog({super.key, required this.recording});

  final Recording recording;

  @override
  State<RecordingPlayerDialog> createState() => _RecordingPlayerDialogState();
}

class _RecordingPlayerDialogState extends State<RecordingPlayerDialog> {
  late final VideoPlayerController _controller;
  bool _initializing = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    final url = widget.recording.url!;
    _controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initializing = false);
        _controller.play();
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _error = true;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 400,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _initializing
              ? const Center(child: CircularProgressIndicator())
              : _error
                  ? const Center(child: Text('Failed to load recording'))
                  : VideoPlayer(_controller),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
