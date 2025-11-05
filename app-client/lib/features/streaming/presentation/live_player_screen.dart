import 'package:anomeye/features/streaming/domain/stream_url_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final String url =
        widget.hlsUrl ?? ref.read(streamUrlProvider(widget.cameraId));
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
    final String url =
        widget.hlsUrl ?? ref.watch(streamUrlProvider(widget.cameraId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Colors.black),
                  child: _controller != null && _controller!.value.isInitialized
                      ? VideoPlayer(_controller!)
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _GlassIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  _GlassIconButton(
                    icon: Icons.replay,
                    onPressed: () async {
                      try {
                        await _controller?.pause();
                        await _controller?.dispose();
                      } catch (_) {}
                      _controller =
                          VideoPlayerController.networkUrl(Uri.parse(url))
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
            ),
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.videocam_outlined, color: Colors.white70),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live stream · ${widget.cameraId}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
        color: Colors.black.withOpacity(.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}
