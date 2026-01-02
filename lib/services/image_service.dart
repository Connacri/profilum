// lib/core/services/image_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _supabase;
  
  static const int _maxWidth = 1920;
  static const int _maxHeight = 1920;
  static const int _quality = 85;
  static const String _watermarkText = 'profilum';

  ImageService(this._supabase);

  // Capture depuis caméra avec watermark automatique
  Future<File?> captureFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: _maxWidth.toDouble(),
        maxHeight: _maxHeight.toDouble(),
        imageQuality: 100,
      );

      if (photo == null) return null;

      final file = File(photo.path);
      return await _addWatermarkAndCompress(file, fromCamera: true);
    } catch (e) {
      debugPrint('Camera error: $e');
      return null;
    }
  }

  // Selection depuis galerie (pas de watermark)
  Future<File?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _maxWidth.toDouble(),
        maxHeight: _maxHeight.toDouble(),
        imageQuality: 100,
      );

      if (image == null) return null;

      final file = File(image.path);
      return await _addWatermarkAndCompress(file, fromCamera: false);
    } catch (e) {
      debugPrint('Gallery error: $e');
      return null;
    }
  }

  // Selection multiple depuis galerie
  Future<List<File>> pickMultipleFromGallery({int maxImages = 6}) async {
    try {
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

  // Traitement: Watermark + Compression WebP
  Future<File?> _addWatermarkAndCompress(
    File imageFile, {
    required bool fromCamera,
  }) async {
    try {
      // Lire l'image
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) return null;

      // Redimensionner si nécessaire
      if (image.width > _maxWidth || image.height > _maxHeight) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? _maxWidth : null,
          height: image.height > image.width ? _maxHeight : null,
        );
      }

      // Ajouter watermark si photo prise par caméra
      if (fromCamera) {
        image = _addWatermark(image);
      }

      // Convertir en WebP
      final webpBytes = img.encodeWebP(image, quality: _quality);

      // Sauvegarder localement
      final tempDir = await getTemporaryDirectory();
      final fileName = '${const Uuid().v4()}.webp';
      final webpFile = File('${tempDir.path}/$fileName');
      await webpFile.writeAsBytes(webpBytes);

      return webpFile;
    } catch (e) {
      debugPrint('Image processing error: $e');
      return null;
    }
  }

  // Ajouter watermark en haut à droite
  img.Image _addWatermark(img.Image image) {
    final watermarkColor = img.ColorRgb8(255, 255, 255);
    final shadowColor = img.ColorRgb8(0, 0, 0);
    
    // Position haut droite avec marge
    const fontSize = 24;
    const padding = 20;
    final x = image.width - (fontSize * _watermarkText.length ~/ 2) - padding;
    final y = padding;

    // Ombre pour lisibilité
    img.drawString(
      image,
      _watermarkText,
      font: img.arial24,
      x: x + 2,
      y: y + 2,
      color: shadowColor,
    );

    // Texte principal
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

  // Upload vers Supabase Storage
  Future<String?> uploadToStorage({
    required File imageFile,
    required String userId,
    required String bucket,
    String? folder,
  }) async {
    try {
      final fileName = '${const Uuid().v4()}.webp';
      final path = folder != null ? '$folder/$fileName' : fileName;
      final fullPath = '$userId/$path';

      await _supabase.storage.from(bucket).upload(
        fullPath,
        imageFile,
        fileOptions: const FileOptions(
          contentType: 'image/webp',
          upsert: false,
        ),
      );

      return _supabase.storage.from(bucket).getPublicUrl(fullPath);
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  // Supprimer du storage
  Future<bool> deleteFromStorage({
    required String url,
    required String bucket,
  }) async {
    try {
      final uri = Uri.parse(url);
      final path = uri.pathSegments.sublist(
        uri.pathSegments.indexOf(bucket) + 1,
      ).join('/');

      await _supabase.storage.from(bucket).remove([path]);
      return true;
    } catch (e) {
      debugPrint('Delete error: $e');
      return false;
    }
  }

  // Calculer taille d'image optimisée
  Future<int> getImageSize(File file) async {
    return await file.length();
  }

  // Valider format image
  bool isValidImageFormat(String path) {
    final ext = path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
  }
}