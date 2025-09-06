import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anomeye/app/di.dart';

final streamUrlProvider = Provider.family<String, String>((ref, cameraId) {
  final env = ref.watch(envProvider);
  // Standar MediaMTX HLS: http://<host>:8888/<cameraId>/index.m3u8
  return '${env.mtxHlsBase}/$cameraId/index.m3u8';
});
