import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_constants.dart';

class PermissionService {
  static Future<bool> _isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('permissions_requested') != true;
  }

  static Future<void> _markPermissionsRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_requested', true);
  }

  static Future<bool> requestCameraPermission() async {
    final status = await ph.Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> requestPhotoLibraryPermission() async {
    final status = await ph.Permission.photos.request();
    return status.isGranted;
  }

  static Future<bool> requestLocationPermission() async {
    final status = await ph.Permission.location.request();
    return status.isGranted;
  }

  static Future<bool> isCameraPermissionGranted() async {
    final status = await ph.Permission.camera.status;
    return status.isGranted;
  }

  static Future<bool> isPhotoLibraryPermissionGranted() async {
    final status = await ph.Permission.photos.status;
    return status.isGranted;
  }

  static Future<bool> isLocationPermissionGranted() async {
    final status = await ph.Permission.location.status;
    return status.isGranted;
  }

  static Future<Map<String, bool>> requestMediaPermissions() async {
    final camera = await requestCameraPermission();
    final photos = await requestPhotoLibraryPermission();
    return {
      'camera': camera,
      'photos': photos,
    };
  }

  static Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }

  static Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'camera': await isCameraPermissionGranted(),
      'photos': await isPhotoLibraryPermissionGranted(),
      'location': await isLocationPermissionGranted(),
    };
  }

  static Future<bool> requestInitialPermissions() async {
    final isFirstTime = await _isFirstTime();
    if (!isFirstTime) {
      return true;
    }

    final camera = await requestCameraPermission();
    final photos = await requestPhotoLibraryPermission();
    final location = await requestLocationPermission();

    await _markPermissionsRequested();

    return camera && photos && location;
  }
}
