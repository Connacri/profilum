// lib/services/image_service.dart - ✅ CORRIGÉ POUR MODÉRATION

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

enum PhotoType { profile, cover, gallery }

class ImageService {
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _supabase;

  static const int _maxWidth = 1920;
  static const int _maxHeight = 1920;
  static const int _quality = 85;
  static const String _watermarkText = 'profilum';

  ImageService(this._supabase);

  // ═══════════════════════════════════════════════════════════
  // 📸 CAPTURE & SELECTION (inchangé)
  // ═══════════════════════════════════════════════════════════

  Future<File?> captureFromCamera() async {
    try {
      if (Platform.isWindows || Platform.isLinux) {
        debugPrint('⚠️ Camera not available on desktop');
        return null;
      }

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: _maxWidth.toDouble(),
        maxHeight: _maxHeight.toDouble(),
        imageQuality: 100,
      );

      if (photo == null) return null;
      return await _addWatermarkAndCompress(File(photo.path), fromCamera: true);
    } catch (e) {
      debugPrint('Camera error: $e');
      return null;
    }
  }

  Future<File?> pickFromGallery() async {
    try {
      if (Platform.isWindows || Platform.isLinux) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result == null || result.files.isEmpty) return null;
        return await _addWatermarkAndCompress(
          File(result.files.first.path!),
          fromCamera: false,
        );
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _maxWidth.toDouble(),
        maxHeight: _maxHeight.toDouble(),
        imageQuality: 100,
      );
      if (image == null) return null;
      return await _addWatermarkAndCompress(
        File(image.path),
        fromCamera: false,
      );
    } catch (e) {
      debugPrint('Gallery error: $e');
      return null;
    }
  }

  Future<List<File>> pickMultipleFromGallery({int maxImages = 6}) async {
    try {
      if (Platform.isWindows || Platform.isLinux) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
        );
        if (result == null || result.files.isEmpty) return [];

        final List<File> processed = [];
        for (var i = 0; i < result.files.length && i < maxImages; i++) {
          final file = await _addWatermarkAndCompress(
            File(result.files[i].path!),
            fromCamera: false,
          );
          if (file != null) processed.add(file);
        }
        return processed;
      }

      final images = await _picker.pickMultiImage(
        maxWidth: _maxWidth.toDouble(),
        maxHeight: _maxHeight.toDouble(),
        imageQuality: 100,
      );
      if (images.isEmpty) return [];

      final List<File> processed = [];
      for (var i = 0; i < images.length && i < maxImages; i++) {
        final file = await _addWatermarkAndCompress(
          File(images[i].path),
          fromCamera: false,
        );
        if (file != null) processed.add(file);
      }
      return processed;
    } catch (e) {
      debugPrint('Multiple gallery error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🖼️ IMAGE PROCESSING (inchangé)
  // ═══════════════════════════════════════════════════════════

  Future<File?> _addWatermarkAndCompress(
    File imageFile, {
    required bool fromCamera,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      if (image.width > _maxWidth || image.height > _maxHeight) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? _maxWidth : null,
          height: image.height > image.width ? _maxHeight : null,
          interpolation: img.Interpolation.cubic,
        );
      }

      if (fromCamera) image = _addWatermark(image);

      final jpegBytes = img.encodeJpg(image, quality: _quality);
      final tempDir = await getTemporaryDirectory();
      final fileName = '${const Uuid().v4()}.jpg';
      final jpegFile = File('${tempDir.path}/$fileName');
      await jpegFile.writeAsBytes(jpegBytes);

      return jpegFile;
    } catch (e) {
      debugPrint('Image processing error: $e');
      return null;
    }
  }

  img.Image _addWatermark(img.Image image) {
    final watermarkColor = img.ColorRgb8(255, 255, 255);
    final shadowColor = img.ColorRgb8(0, 0, 0);
    const fontSize = 24;
    const padding = 20;
    final x = image.width - (fontSize * _watermarkText.length ~/ 2) - padding;
    final y = padding;

    img.drawString(
      image,
      _watermarkText,
      font: img.arial24,
      x: x + 2,
      y: y + 2,
      color: shadowColor,
    );
    img.drawString(
      image,
      _watermarkText,
      font: img.arial24,
      x: x,
      y: y,
      color: watermarkColor,
    );
    return image;
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ UPLOAD - RETOURNE PATH (PAS URL)
  // ═══════════════════════════════════════════════════════════

  /// Upload et retourne le PATH (ex: "user_123/gallery/uuid.jpg")
  /// ⚠️ NE PAS stocker l'URL complète dans la DB
  Future<String?> uploadToStorage({
    required File imageFile,
    required String userId,
    required PhotoType photoType,
  }) async {
    try {
      const bucket = 'profiles';
      final folder = _getFolderForType(photoType);
      final fileName = '${const Uuid().v4()}.jpg';
      final fullPath = '$userId/$folder/$fileName'; // ✅ PATH uniquement

      debugPrint('🔵 Upload: bucket=$bucket, path=$fullPath');

      // Vérifier bucket existe
      try {
        await _supabase.storage
            .from(bucket)
            .list(path: '', searchOptions: const SearchOptions(limit: 1));
      } catch (e) {
        debugPrint('❌ Bucket "$bucket" not found');
        throw StorageException('Bucket "$bucket" inexistant');
      }

      // Upload
      await _supabase.storage
          .from(bucket)
          .upload(
            fullPath,
            imageFile,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      debugPrint('✅ Upload success: $fullPath');
      return fullPath; // ✅ Retourner PATH uniquement
    } on StorageException catch (e) {
      debugPrint('❌ StorageException: ${e.message} (${e.statusCode})');
      _logBucketError(e);
      return null;
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      return null;
    }
  }

  String _getFolderForType(PhotoType type) {
    switch (type) {
      case PhotoType.profile:
        return 'avatar';
      case PhotoType.cover:
        return 'covers';
      case PhotoType.gallery:
        return 'gallery';
    }
  }

  void _logBucketError(StorageException e) {
    if (e.statusCode == 404 || e.message.contains('Bucket not found')) {
      debugPrint('');
      debugPrint('════════════════════════════════════════════════════');
      debugPrint('⚠️  ERREUR : Bucket Supabase manquant');
      debugPrint('════════════════════════════════════════════════════');
      debugPrint('Bucket requis : "profiles"');
      debugPrint('📋 Instructions :');
      debugPrint('1. https://supabase.com/dashboard');
      debugPrint('2. Storage → Create bucket');
      debugPrint('3. Nom : "profiles"');
      debugPrint('4. Cocher "Public bucket"');
      debugPrint('════════════════════════════════════════════════════');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ DELETE - UTILISE PATH DIRECT
  // ═══════════════════════════════════════════════════════════

  /// Supprime une photo via son PATH (ex: "user_123/gallery/uuid.jpg")
  /// ⚠️ NE PAS passer une URL complète
  Future<bool> deleteFromStorage({required String path}) async {
    try {
      debugPrint('🗑️ Deleting from storage: $path');

      await _supabase.storage.from('profiles').remove([path]);

      debugPrint('✅ Photo deleted: $path');
      return true;
    } catch (e) {
      debugPrint('❌ Delete error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔧 HELPERS
  // ═══════════════════════════════════════════════════════════

  Future<int> getImageSize(File file) async => await file.length();

  bool isValidImageFormat(String path) {
    final ext = path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
  }

  int getMaxPhotos(PhotoType type) {
    switch (type) {
      case PhotoType.profile:
        return 1;
      case PhotoType.cover:
        return 3;
      case PhotoType.gallery:
        return 6;
    }
  }
}
