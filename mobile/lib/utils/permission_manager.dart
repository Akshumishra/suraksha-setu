import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  static Future<bool> requestAllPermissions() async {
    // Request all required permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.camera,
      Permission.microphone,
      Permission.storage, // optional if you save video files
    ].request();

    // Check if any permission is permanently denied
    bool permanentlyDenied = statuses.values.any((status) => status.isPermanentlyDenied);
    if (permanentlyDenied) {
      await openAppSettings();
      return false;
    }

    // Check if all are granted
    bool allGranted = statuses.values.every((status) => status.isGranted);
    return allGranted;
  }
}
