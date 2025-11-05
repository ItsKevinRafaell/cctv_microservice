import 'package:anomeye/features/recordings/domain/recording.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class RecordingPlayerScreen extends StatefulWidget {
  final Recording recording;
  const RecordingPlayerScreen({super.key, required this.recording});

  @override
  State<RecordingPlayerScreen> createState() => _RecordingPlayerScreenState();
}

class _RecordingPlayerScreenState extends State<RecordingPlayerScreen> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    final url = widget.recording.url;
    if (url == null || url.isEmpty) {
      setState(() {
        _error = 'URL rekaman tidak tersedia.';
        _loading = false;
      });
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      controller.play();
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memutar rekaman: $e';
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recording = widget.recording;

    return Scaffold(
      appBar: AppBar(
        title: Text('Playback ${recording.cameraId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _error = null;
                _loading = true;
                _controller?.dispose();
                _controller = null;
              });
              _init();
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio:
                  _controller != null && _controller!.value.isInitialized
                      ? _controller!.value.aspectRatio
                      : 16 / 9,
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Colors.black),
                child: Builder(
                  builder: (_) {
                    if (_loading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (_error != null) {
                      return Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    if (_controller != null &&
                        _controller!.value.isInitialized) {
                      return Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          VideoPlayer(_controller!),
                          VideoProgressIndicator(
                            _controller!,
                            allowScrubbing: true,
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              recording.key,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Start: ${recording.startedAt.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'End  : ${recording.endedAt.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Size : ${(recording.sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (recording.url != null && recording.url!.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                recording.url!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.blueGrey),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: _controller != null &&
              _controller!.value.isInitialized &&
              _error == null
          ? FloatingActionButton(
              onPressed: () {
                if (_controller!.value.isPlaying) {
                  _controller!.pause();
                } else {
                  _controller!.play();
                }
                setState(() {});
              },
              child: Icon(
                _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
}
