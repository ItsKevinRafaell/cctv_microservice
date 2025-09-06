import 'package:anomeye/features/cameras/domain/camera.dart';

abstract class CamerasRepo {
  Future<List<Camera>> listCameras();
  Future<Camera> getCamera(String id);
}
