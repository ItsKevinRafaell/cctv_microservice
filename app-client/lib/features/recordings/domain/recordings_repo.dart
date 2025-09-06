import 'package:anomeye/features/recordings/domain/recording.dart';

abstract class RecordingsRepo {
  Future<List<Recording>> list({
    required String cameraId,
    DateTime? from,
    DateTime? to,
    bool presign = true,
  });
}
