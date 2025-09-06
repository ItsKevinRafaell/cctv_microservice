import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

final playerProvider = Provider.autoDispose<Player>((ref) {
  final player = Player();
  ref.onDispose(() async {
    try {
      await player.dispose();
    } catch (_) {}
  });
  return player;
});
