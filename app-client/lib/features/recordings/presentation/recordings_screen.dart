import 'package:anomeye/features/recordings/domain/recording.dart';
import 'package:anomeye/features/recordings/presentation/recording_seen_controller.dart';
import 'package:anomeye/features/recordings/presentation/recordings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  void _openRecording(BuildContext context, Recording recording) {
    final url = recording.url;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL rekaman belum tersedia.')),
      );
      return;
    }

    ref.read(recordingSeenProvider.notifier).markSeen(recording.key);
    context.push('/recordings/play', extra: recording);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingsControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (items) {
            final seen = ref.watch(recordingSeenProvider);
            return _RecordingsList(
              cameraId: widget.cameraId,
              items: items,
              seenKeys: seen,
              onRefresh: _reload,
              onOpen: (recording) => _openRecording(context, recording),
            );
          },
        ),
      ),
    );
  }
}

class _RecordingsList extends StatelessWidget {
  final String cameraId;
  final List<Recording> items;
  final Set<String> seenKeys;
  final void Function(Recording) onOpen;
  final VoidCallback onRefresh;

  const _RecordingsList({
    required this.cameraId,
    required this.items,
    required this.seenKeys,
    required this.onOpen,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
        children: const [
          Icon(Icons.folder_off_outlined, size: 64, color: Color(0xFF98A2B3)),
          SizedBox(height: 16),
          Text(
            'No recordings yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text(
            'Clips will appear here once the camera starts storing footage.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF667085)),
          ),
        ],
      );
    }

    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                _GlassIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Clips for $cameraId',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap an unseen clip to open it in the player.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: const Color(0xFF667085)),
                      ),
                    ],
                  ),
                ),
                _GlassIconButton(
                  icon: Icons.refresh,
                  onPressed: onRefresh,
                ),
              ],
            ),
          );
        }

        final recording = items[index - 1];
        final started = recording.startedAt.toLocal();
        final ended = recording.endedAt.toLocal();
        final dur = ended.difference(started);
        final seen = seenKeys.contains(recording.key);

        final decoration = BoxDecoration(
          color: seen ? Colors.white : const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: seen ? Colors.white : accent.withOpacity(.35),
            width: 1.5,
          ),
          boxShadow: [
            if (!seen)
              BoxShadow(
                color: accent.withOpacity(.12),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
          ],
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: decoration,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: seen ? const Color(0xFFE4E7EC) : accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.smart_display_outlined,
                color: seen ? const Color(0xFF475467) : Colors.white,
              ),
            ),
            title: Text(
              '${started.toString().substring(0, 19)}  (${_formatDuration(dur)})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: seen ? FontWeight.w600 : FontWeight.w700,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${(recording.sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB • ${recording.key}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: seen
                        ? const Color(0xFF98A2B3)
                        : accent.withOpacity(0.7),
                  ),
                ),
                if (!seen)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'New clip',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            trailing: IconButton.filledTonal(
              icon: const Icon(Icons.play_arrow_rounded),
              color: Colors.white,
              onPressed: () => onOpen(recording),
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '00:$minutes:$seconds';
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _GlassIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Theme.of(context).colorScheme.primary),
        onPressed: onPressed,
      ),
    );
  }
}
