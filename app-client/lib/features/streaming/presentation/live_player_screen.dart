import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anomeye/features/streaming/domain/stream_url_builder.dart';
import 'package:video_player/video_player.dart';

class LivePlayerScreen extends ConsumerStatefulWidget {
  final String cameraId;
  final String? hlsUrl;
  const LivePlayerScreen({super.key, required this.cameraId, this.hlsUrl});

  @override
  ConsumerState<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends ConsumerState<LivePlayerScreen> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final String url = widget.hlsUrl ?? ref.read(streamUrlProvider(widget.cameraId));
    _controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _controller?.play();
      }).catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start live: $e')),
          );
        }
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String url = widget.hlsUrl ?? ref.watch(streamUrlProvider(widget.cameraId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Live • ${widget.cameraId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.replay),
            tooltip: 'Reopen',
            onPressed: () async {
              try {
                await _controller?.pause();
                await _controller?.dispose();
              } catch (_) {}
              _controller = VideoPlayerController.networkUrl(Uri.parse(url))
                ..setLooping(true)
                ..initialize().then((_) {
                  if (mounted) setState(() {});
                  _controller?.play();
                }).catchError((e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to reopen: $e')),
                    );
                  }
                });
            },
          ),
        ],
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Colors.black),
            child: _controller != null && _controller!.value.isInitialized
                ? VideoPlayer(_controller!)
                : const Center(
                    child: CircularProgressIndicator(),
                  ),
          ),
        ),
      ),
    );
  }
}
