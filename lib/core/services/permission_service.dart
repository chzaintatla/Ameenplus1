import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request camera permission
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request photo library permission
  static Future<bool> requestPhotoLibraryPermission() async {
    if (await Permission.photos.isGranted) {
      return true;
    }
    final status = await Permission.photos.request();
    return status.isGranted;
  }

  /// Request location permission
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Check if camera permission is granted
  static Future<bool> isCameraPermissionGranted() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Check if photo library permission is granted
  static Future<bool> isPhotoLibraryPermissionGranted() async {
    final status = await Permission.photos.status;
    return status.isGranted;
  }

  /// Check if location permission is granted
  static Future<bool> isLocationPermissionGranted() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Request all media permissions (camera and photos)
  static Future<Map<String, bool>> requestMediaPermissions() async {
    final camera = await requestCameraPermission();
    final photos = await requestPhotoLibraryPermission();
    return {
      'camera': camera,
      'photos': photos,
    };
  }

  /// Open app settings
  static Future<bool> openAppSettings() async {
    return await openAppSettings();
  }
  
  /// Check and request all required permissions
  static Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'camera': await isCameraPermissionGranted(),
      'photos': await isPhotoLibraryPermissionGranted(),
      'location': await isLocationPermissionGranted(),
    };
  }
}

