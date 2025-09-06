import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:anomeye/features/streaming/domain/stream_url_builder.dart';
import 'package:anomeye/features/streaming/presentation/live_controller.dart';
import 'package:media_kit/media_kit.dart';

class LivePlayerScreen extends ConsumerStatefulWidget {
  final String cameraId;
  const LivePlayerScreen({super.key, required this.cameraId});

  @override
  ConsumerState<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends ConsumerState<LivePlayerScreen> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _openIfNeeded();
  }

  Future<void> _openIfNeeded() async {
    if (_opened) return;
    _opened = true;
    final player = ref.read(playerProvider);
    final url = ref.read(streamUrlProvider(widget.cameraId));
    // HLS live
    await player.open(Media(url), play: true);
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final controller = VideoController(player);
    final url = ref.watch(streamUrlProvider(widget.cameraId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Live • ${widget.cameraId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.replay),
            tooltip: 'Reopen',
            onPressed: () async {
              await player.stop();
              await player.open(Media(url), play: true);
            },
          ),
        ],
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Colors.black),
            child: Video(controller: controller),
          ),
        ),
      ),
    );
  }
}
