import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final fcmProvider =
    Provider<FirebaseMessaging>((_) => FirebaseMessaging.instance);

// NOTE: gunakan Ref (bukan WidgetRef) agar bisa dipakai di controller/state.
Future<String?> ensureFcmToken(Ref ref) async {
  final fm = ref.read(fcmProvider);
  await fm.requestPermission(); // iOS: ask permission; Android: no-op
  return fm.getToken(); // null jika belum tersedia
}
