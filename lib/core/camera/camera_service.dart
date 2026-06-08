import 'package:camera/camera.dart';

class CameraService {
  CameraService._();

  static final CameraService _instance = CameraService._();

  /// Singleton instance.
  static CameraService get instance => _instance;

  List<CameraDescription>? _cameras;
  CameraDescription? _preferred;

  /// Fetches available cameras once and caches the result.
  Future<List<CameraDescription>> getAvailableCameras() async {
    if (_cameras != null) return _cameras!;
    _cameras = await availableCameras();
    return _cameras!;
  }

  Future<CameraDescription?> getPreferredCamera() async {
    if (_preferred != null) return _preferred;
    final cameras = await getAvailableCameras();
    if (cameras.isEmpty) return null;

    final front = cameras
        .where((c) => c.lensDirection == CameraLensDirection.front)
        .firstOrNull;
    _preferred = front ?? cameras.first;
    return _preferred;
  }

  /// Clears cached cameras (e.g. after permission change). Next call will re-fetch.
  void clearCache() {
    _cameras = null;
    _preferred = null;
  }
}
