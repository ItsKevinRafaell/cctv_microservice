import 'package:flutter/material.dart';
import 'package:anomeye/features/cameras/domain/camera.dart';

class CameraCard extends StatelessWidget {
  final Camera camera;
  final VoidCallback? onTap;

  const CameraCard({
    super.key,
    required this.camera,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // REFINED: Menghapus SizedBox luar, karena GridView sudah mengatur ukuran.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bagian atas: Preview video & status online
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black87,
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(Icons.videocam_outlined,
                          color: Colors.white54, size: 48),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: camera.online ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          camera.online ? 'Online' : 'Offline',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bagian bawah: Nama & lokasi kamera
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0), // Padding sedikit dikurangi
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      camera.name,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2, // Izinkan nama hingga 2 baris
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      camera.location ?? 'No location',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
