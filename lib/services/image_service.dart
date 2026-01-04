// lib/services/image_service.dart - REFACTORISÉ

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Types de photos supportés
enum PhotoType {
  profile, // Photo de profil (1 max)
  cover, // Photos de couverture (3 max)
  gallery, // Photos de galerie (6 max)
}

class ImageService {
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _supabase;

  static const int _maxWidth = 1920;
  static const int _maxHeight = 1920;
  static const int _quality = 85;
  static const String _watermarkText = 'profilum';

  ImageService(this._supabase);

  /// Capturer depuis la caméra (AVEC watermark)
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

      final file = File(photo.path);
      // ✅ Toujours ajouter le watermark pour les photos caméra
      return await _addWatermarkAndCompress(file, fromCamera: true);
    } catch (e) {
      debugPrint('Camera error: $e');
      return null;
    }
  }

  /// Choisir depuis la galerie (SANS watermark)
  Future<File?> pickFromGallery() async {
    try {
      // Windows/Linux: utiliser file_picker
      if (Platform.isWindows || Platform.isLinux) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );

        if (result == null || result.files.isEmpty) return null;

        final file = File(result.files.first.path!);
        // ✅ PAS de watermark pour les photos galerie
        return await _addWatermarkAndCompress(file, fromCamera: false);
      }

      // Android/iOS: utiliser image_picker
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _maxWidth.toDouble(),
        maxHeight: _maxHeight.toDouble(),
        imageQuality: 100,
      );

      if (image == null) return null;

      final file = File(image.path);
      // ✅ PAS de watermark pour les photos galerie
      return await _addWatermarkAndCompress(file, fromCamera: false);
    } catch (e) {
      debugPrint('Gallery error: $e');
      return null;
    }
  }

  /// Choisir plusieurs photos depuis la galerie
  Future<List<File>> pickMultipleFromGallery({int maxImages = 6}) async {
    try {
      // Windows/Linux: utiliser file_picker
      if (Platform.isWindows || Platform.isLinux) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
        );

        if (result == null || result.files.isEmpty) return [];

        final List<File> processedImages = [];
        for (var i = 0; i < result.files.length && i < maxImages; i++) {
          final file = File(result.files[i].path!);
          final processed = await _addWatermarkAndCompress(
            file,
            fromCamera: false,
          );
          if (processed != null) {
            processedImages.add(processed);
          }
        }

        return processedImages;
      }

      // Android/iOS: utiliser image_picker
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: _maxWidth.toDouble(),
        maxHeight: _maxHeight.toDouble(),
        imageQuality: 100,
      );

      if (images.isEmpty) return [];

      final List<File> processedImages = [];
      for (var i = 0; i < images.length && i < maxImages; i++) {
        final processed = await _addWatermarkAndCompress(
          File(images[i].path),
          fromCamera: false,
        );
        if (processed != null) {
          processedImages.add(processed);
        }
      }

      return processedImages;
    } catch (e) {
      debugPrint('Multiple gallery error: $e');
      return [];
    }
  }

  /// Traitement: Compression + Watermark optionnel
  Future<File?> _addWatermarkAndCompress(
    File imageFile, {
    required bool fromCamera,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) return null;

      // Resize avec interpolation cubique
      if (image.width > _maxWidth || image.height > _maxHeight) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? _maxWidth : null,
          height: image.height > image.width ? _maxHeight : null,
          interpolation: img.Interpolation.cubic,
        );
      }

      // ✅ Watermark SEULEMENT si photo caméra
      if (fromCamera) {
        image = _addWatermark(image);
      }

      // Compression JPEG (qualité 85)
      final List<int> jpegBytes = img.encodeJpg(image, quality: _quality);

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

  /// Ajouter le watermark "profilum"
  img.Image _addWatermark(img.Image image) {
    final watermarkColor = img.ColorRgb8(255, 255, 255);
    final shadowColor = img.ColorRgb8(0, 0, 0);

    const fontSize = 24;
    const padding = 20;
    final x = image.width - (fontSize * _watermarkText.length ~/ 2) - padding;
    final y = padding;

    // Ombre
    img.drawString(
      image,
      _watermarkText,
      font: img.arial24,
      x: x + 2,
      y: y + 2,
      color: shadowColor,
    );

    // Texte blanc
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

  /// ✅ NOUVEAU: Upload avec type de photo
  Future<String?> uploadToStorage({
    required File imageFile,
    required String userId,
    required PhotoType photoType,
  }) async {
    try {
      // Déterminer le bucket et le dossier selon le type
      final String bucket = 'profiles';
      final String folder = _getFolderForType(photoType);

      final fileName = '${const Uuid().v4()}.jpg';
      final fullPath = '$userId/$folder/$fileName';

      debugPrint('🔵 Upload attempt: bucket=$bucket, path=$fullPath');

      // Vérifier que le bucket existe
      try {
        await _supabase.storage
            .from(bucket)
            .list(path: '', searchOptions: const SearchOptions(limit: 1));
      } catch (e) {
        debugPrint(
          '❌ Bucket "$bucket" not found. Please create it in Supabase Dashboard.',
        );
        throw StorageException(
          'Le bucket de stockage "$bucket" n\'existe pas. '
          'Veuillez le créer dans le tableau de bord Supabase.',
        );
      }

      // Upload du fichier
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

      final publicUrl = _supabase.storage.from(bucket).getPublicUrl(fullPath);
      debugPrint('✅ Upload success: $publicUrl');

      return publicUrl;
    } on StorageException catch (e) {
      debugPrint('❌ StorageException: ${e.message} (${e.statusCode})');
      _logBucketError(e);
      return null;
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      return null;
    }
  }

  /// Helper: Obtenir le dossier selon le type de photo
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

  /// Logger les erreurs de bucket
  void _logBucketError(StorageException e) {
    if (e.statusCode == 404 || e.message.contains('Bucket not found')) {
      debugPrint('');
      debugPrint('════════════════════════════════════════════════════');
      debugPrint('⚠️  ERREUR : Bucket Supabase manquant');
      debugPrint('════════════════════════════════════════════════════');
      debugPrint('Bucket requis : "profiles"');
      debugPrint('');
      debugPrint('📋 Instructions :');
      debugPrint('1. Allez sur https://supabase.com/dashboard');
      debugPrint('2. Sélectionnez votre projet');
      debugPrint('3. Menu Storage → Create bucket');
      debugPrint('4. Nom : "profiles"');
      debugPrint('5. Cochez "Public bucket"');
      debugPrint('════════════════════════════════════════════════════');
      debugPrint('');
    }
  }

  /// Supprimer une photo du storage
  Future<bool> deleteFromStorage({required String url}) async {
    try {
      final uri = Uri.parse(url);
      // Extraire le path après le bucket
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf('profiles');

      if (bucketIndex == -1) {
        debugPrint('❌ Invalid storage URL: $url');
        return false;
      }

      final path = segments.sublist(bucketIndex + 1).join('/');

      await _supabase.storage.from('profiles').remove([path]);
      debugPrint('✅ Photo deleted: $path');
      return true;
    } catch (e) {
      debugPrint('❌ Delete error: $e');
      return false;
    }
  }

  /// Obtenir la taille d'une image
  Future<int> getImageSize(File file) async {
    return await file.length();
  }

  /// Valider le format d'image
  bool isValidImageFormat(String path) {
    final ext = path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
  }

  /// ✅ NOUVEAU: Limites selon le type
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
