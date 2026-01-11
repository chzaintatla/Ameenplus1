import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Storage service that uses Supabase Storage
/// Note: Supabase is used ONLY for storage operations (images, videos, files)
/// All database operations use Firebase Firestore
class StorageService {
  static SupabaseClient get _supabase => Supabase.instance.client;

  /// Upload a file to Supabase Storage
  /// 
  /// IMPORTANT: filePath must include userId as first folder: userId/filename.ext
  /// Example: 'user123/profile.jpg' or 'user123/post-image.jpg'
  /// 
  /// [bucket] - The storage bucket name (e.g., 'avatars', 'media', 'deeds')
  /// [filePath] - The path where the file should be stored (must be: userId/filename.ext)
  /// [file] - The file to upload
  /// [contentType] - Optional content type (e.g., 'image/jpeg', 'video/mp4')
  /// [upsert] - Whether to overwrite if file exists
  /// 
  /// Returns the public URL of the uploaded file
  static Future<String> uploadFile({
    required String bucket,
    required String filePath,
    required File file,
    String? contentType,
    bool upsert = false,
  }) async {
    try {
      await _supabase.storage.from(bucket).upload(
        filePath,
        file,
        fileOptions: FileOptions(
          contentType: contentType,
          cacheControl: '3600',
          upsert: upsert,
        ),
      );

      final downloadUrl = _supabase.storage.from(bucket).getPublicUrl(filePath);
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload file to storage: $e');
    }
  }

  /// Upload bytes to Supabase Storage
  /// 
  /// [bucket] - The storage bucket name
  /// [filePath] - The path where the file should be stored
  /// [bytes] - The file bytes to upload
  /// [contentType] - Optional content type
  /// [upsert] - Whether to overwrite if file exists
  /// 
  /// Returns the public URL of the uploaded file
  static Future<String> uploadBytes({
    required String bucket,
    required String filePath,
    required List<int> bytes,
    String? contentType,
    bool upsert = false,
  }) async {
    try {
      await _supabase.storage.from(bucket).uploadBinary(
        filePath,
        Uint8List.fromList(bytes),
        fileOptions: FileOptions(
          contentType: contentType,
          cacheControl: '3600',
          upsert: upsert,
        ),
      );

      final downloadUrl = _supabase.storage.from(bucket).getPublicUrl(filePath);
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload bytes to storage: $e');
    }
  }

  /// Get public URL for a file in storage
  /// 
  /// [bucket] - The storage bucket name
  /// [filePath] - The path to the file
  /// 
  /// Returns the public URL
  static String getPublicUrl({
    required String bucket,
    required String filePath,
  }) {
    return _supabase.storage.from(bucket).getPublicUrl(filePath);
  }

  /// Delete a file from storage
  /// 
  /// [bucket] - The storage bucket name
  /// [filePath] - The path to the file to delete
  static Future<void> deleteFile({
    required String bucket,
    required String filePath,
  }) async {
    try {
      await _supabase.storage.from(bucket).remove([filePath]);
    } catch (e) {
      throw Exception('Failed to delete file from storage: $e');
    }
  }

  /// Delete multiple files from storage
  /// 
  /// [bucket] - The storage bucket name
  /// [filePaths] - List of paths to files to delete
  static Future<void> deleteFiles({
    required String bucket,
    required List<String> filePaths,
  }) async {
    try {
      await _supabase.storage.from(bucket).remove(filePaths);
    } catch (e) {
      throw Exception('Failed to delete files from storage: $e');
    }
  }
}
