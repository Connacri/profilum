// lib/utils/photo_url_helper.dart - ✅ NOUVEAU FICHIER

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🔗 Helper centralisé pour construire les URLs publiques des photos
/// Utilise le SupabaseClient pour garantir la cohérence
class PhotoUrlHelper {
  final SupabaseClient _supabase;

  PhotoUrlHelper(this._supabase);

  String buildPhotoUrl(String path) {
    // ✅ Valider que le path ne contient pas déjà l'URL complète
    if (path.startsWith('http://') || path.startsWith('https://')) {
      debugPrint('⚠️ Path already contains full URL: $path');
      return path;
    }

    // ✅ Nettoyer le path (enlever les slashes en trop)
    final cleanPath = path
        .replaceAll(RegExp(r'^/+'), '') // Enlever slashes au début
        .replaceAll(RegExp(r'/+'), '/'); // Normaliser les slashes multiples

    // ✅ Construire l'URL publique via Supabase
    final url = _supabase.storage.from('profiles').getPublicUrl(cleanPath);

    debugPrint('🔗 Built URL: $url');
    debugPrint('   From path: $cleanPath');

    return url;
  }

  /// Construire l'URL pour une photo de profil
  String? buildProfilePhotoUrl(Map<String, dynamic> profile) {
    try {
      final photos = profile['photos'];

      debugPrint('🔍 buildProfilePhotoUrl:');
      debugPrint('   - photos type: ${photos.runtimeType}');
      debugPrint('   - photos value: $photos');

      // ✅ Gérer le cas où photos est null ou pas une liste
      if (photos == null) {
        debugPrint('   → photos is null');
        return null;
      }

      if (photos is! List) {
        debugPrint('   → photos is not a List (${photos.runtimeType})');
        return null;
      }

      if (photos.isEmpty) {
        debugPrint('   → photos array is empty');
        return null;
      }

      debugPrint('   → Found ${photos.length} photos');

      // ✅ Chercher photo de profil approuvée
      Map<String, dynamic>? profilePhoto;

      try {
        profilePhoto = photos.firstWhere(
          (p) => p['type'] == 'profile' && p['status'] == 'approved',
          orElse: () => null,
        );
      } catch (e) {
        debugPrint('   → firstWhere error: $e');
        profilePhoto = null;
      }

      if (profilePhoto == null) {
        debugPrint('   → No approved profile photo found');
        debugPrint('   → Available photos:');
        for (var p in photos) {
          debugPrint('      • type=${p['type']}, status=${p['status']}');
        }
        return null;
      }

      final path = profilePhoto['remote_path'] as String?;
      if (path == null || path.isEmpty) {
        debugPrint('   → Profile photo has no remote_path');
        return null;
      }

      final url = buildPhotoUrl(path);
      debugPrint('   → Built URL: $url');
      return url;
    } catch (e, stack) {
      debugPrint('❌ Error building profile photo URL: $e');
      debugPrint('Stack: $stack');
      return null;
    }
  }

  /// Construire les URLs de toutes les photos galerie d'un profil
  List<String> buildGalleryPhotoUrls(Map<String, dynamic> profile) {
    try {
      final photos = profile['photos'];

      debugPrint('🔍 buildGalleryPhotoUrls:');
      debugPrint('   - photos type: ${photos.runtimeType}');

      if (photos == null || photos is! List || photos.isEmpty) {
        debugPrint('   → No photos available');
        return [];
      }

      debugPrint('   → Found ${photos.length} total photos');

      final urls = <String>[];

      for (final photo in photos) {
        // ✅ Filtrer : galerie + approved + avec remote_path
        if (photo['type'] == 'gallery' &&
            photo['status'] == 'approved' &&
            photo['remote_path'] != null &&
            (photo['remote_path'] as String).isNotEmpty) {
          final url = buildPhotoUrl(photo['remote_path'] as String);
          urls.add(url);
          debugPrint('   → Gallery photo: ${photo['remote_path']}');
        }
      }

      debugPrint('   → Built ${urls.length} gallery URLs');
      return urls;
    } catch (e, stack) {
      debugPrint('❌ Error building gallery URLs: $e');
      debugPrint('Stack: $stack');
      return [];
    }
  }
}
