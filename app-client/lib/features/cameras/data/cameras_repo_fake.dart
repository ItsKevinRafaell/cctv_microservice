import 'package:anomeye/features/cameras/domain/camera.dart';
import 'package:anomeye/features/cameras/domain/cameras_repo.dart';

/// A fake implementation of CamerasRepo for testing and UI development.
class CamerasRepoFake implements CamerasRepo {
  /// An optional delay to simulate network latency.
  final Duration delay;

  CamerasRepoFake({this.delay = const Duration(milliseconds: 500)});

  // A hardcoded list of cameras to be used as a fake data source.
  final _cameras = <Camera>[
    const Camera(
      id: 'cam1',
      name: 'Lobby - Main Entrance',
      location: '1st Floor',
      online: true,
      activeAlerts: 2,
    ),
    const Camera(
      id: 'cam2',
      name: 'Parking Lot A',
      location: 'Outdoor',
      online: true,
      activeAlerts: 0,
    ),
    const Camera(
      id: 'cam3',
      name: 'Server Room',
      location: 'Basement',
      online: false, // Simulate an offline camera
      activeAlerts: 0,
    ),
    const Camera(
      id: 'cam4',
      name: 'Rooftop East Wing',
      location: 'Rooftop',
      online: true,
      activeAlerts: 0,
    ),
  ];

  @override
  Future<List<Camera>> listCameras() async {
    // Wait for the simulated delay
    await Future.delayed(delay);

    // To simulate an error, you could uncomment the following line:
    // throw Exception('Failed to connect to the network.');

    return _cameras;
  }

  @override
  Future<Camera> getCamera(String id) async {
    // Wait for the simulated delay
    await Future.delayed(delay);

    // Find the camera by ID.
    final camera = _cameras.firstWhere((cam) => cam.id == id,
        orElse: () => throw Exception('Camera with ID $id not found.'));

    return camera;
    }
}
