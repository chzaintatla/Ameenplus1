import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Storage service that uses Supabase Storage
/// Note: Supabase is used ONLY for storage operations (images, videos, files)
/// All database operations use Firebase Firestore
class StorageService {
  static SupabaseClient get _supabase => Supabase.instance.client;
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


  static String getPublicUrl({
    required String bucket,
    required String filePath,
  }) {
    return _supabase.storage.from(bucket).getPublicUrl(filePath);
  }

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
