import 'package:anomeye/features/recordings/domain/recordings_repo.dart';
import 'package:anomeye/features/recordings/domain/recording.dart';
import 'package:anomeye/features/recordings/data/recordings_api.dart';

class RecordingsRepoImpl implements RecordingsRepo {
  final RecordingsApi api;
  RecordingsRepoImpl(this.api);

  @override
  Future<List<Recording>> list({
    required String cameraId,
    DateTime? from,
    DateTime? to,
    bool presign = true,
  }) {
    return api.list(cameraId, from: from, to: to, presign: presign);
  }
}
