import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class PermissionUtils {
  /// Request critical runtime permissions used across the app.
  static Future<void> requestCriticalPermissions() async {
    final List<Permission> permissions = [
      Permission.notification,
      Permission.locationWhenInUse,
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ];

    // Request all permissions in parallel.
    final statuses = await permissions.request();

    // Log denied permissions for debugging.
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        debugPrint('⚠️ Permission not granted: \\${permission.toString()}');
      }
    });

    // Optional: prompt user to enable location services if disabled
    if (await Permission.location.serviceStatus.isDisabled) {
      debugPrint('⚠️ Location services are disabled. Opening settings.');
      await Permission.location.request();
    }
  }
} 