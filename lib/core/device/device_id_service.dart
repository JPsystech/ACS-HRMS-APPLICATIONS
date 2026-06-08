import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'device_id_platform_stub.dart' if (dart.library.io) 'device_id_platform_io.dart' as platform;

const String _keyDeviceId = 'acs_hrms_device_id';

/// Provides a stable device identifier for punch-in/out. Uses platform id when
/// available (Android/iOS), otherwise a generated UUID stored in SharedPreferences.
class DeviceIdService {
  DeviceIdService._();

  static SharedPreferences? _prefs;
  static String? _cachedId;

  static Future<String> getDeviceId() async {
    if (_cachedId != null && _cachedId!.isNotEmpty) return _cachedId!;

    _prefs ??= await SharedPreferences.getInstance();
    String? id = _prefs!.getString(_keyDeviceId);
    if (id != null && id.trim().isNotEmpty) {
      _cachedId = id;
      return _cachedId!;
    }

    try {
      id = await platform.getPlatformDeviceId();
      if (id != null && id.trim().isNotEmpty) {
        await _prefs!.setString(_keyDeviceId, id);
        _cachedId = id;
        return _cachedId!;
      }
    } catch (_) {
      // Fall through to UUID
    }

    id = const Uuid().v4();
    await _prefs!.setString(_keyDeviceId, id);
    _cachedId = id;
    return _cachedId!;
  }
}
