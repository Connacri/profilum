// lib/services/fix_photo_url_builder.dart - ✅ FIX COMPLET HTTP 400

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🔗 Helper centralisé pour construire les URLs publiques des photos
class PhotoUrlHelper {
  final SupabaseClient _supabase;

  // ✅ Cache des URLs validées pour optimisation
  final Map<String, String> _urlCache = {};

  // ✅ Cache de l'URL de base du storage
  String? _cachedStorageBaseUrl;

  PhotoUrlHelper(this._supabase);

  /// ✅ MÉTHODE PRINCIPALE : Construction d'URL robuste
  String buildPhotoUrl(String path) {
    // Cache hit
    if (_urlCache.containsKey(path)) {
      return _urlCache[path]!;
    }

    // ✅ 1. Si déjà une URL complète, retourner tel quel
    if (path.startsWith('http://') || path.startsWith('https://')) {
      debugPrint('⚠️ Path is already a full URL: $path');
      _urlCache[path] = path;
      return path;
    }

    // ✅ 2. Nettoyer le path (CRITIQUE pour éviter erreurs 400)
    String cleanPath = _cleanPath(path);

    if (cleanPath.isEmpty) {
      debugPrint('❌ Invalid path after cleaning: $path');
      return '';
    }

    // ✅ 3. Construire l'URL via Supabase SDK
    try {
      final url = _supabase.storage
          .from('profiles')
          .getPublicUrl(cleanPath);

      // ✅ 4. Valider l'URL construite
      if (!_isValidUrl(url)) {
        debugPrint('❌ Invalid URL generated: $url');
        // Fallback : construction manuelle
        return _buildManualUrl(cleanPath);
      }

      debugPrint('✅ Photo URL built: $url');
      _urlCache[path] = url;
      return url;

    } catch (e) {
      debugPrint('❌ SDK error building URL: $e');
      return _buildManualUrl(cleanPath);
    }
  }

  /// 🧹 Nettoyer le path (enlever caractères problématiques)
  String _cleanPath(String path) {
    return path
        .trim()                              // Enlever espaces
        .replaceAll(RegExp(r'^/+'), '')      // Enlever / au début
        .replaceAll(RegExp(r'/+'), '/')      // Normaliser slashes multiples
        .replaceAll(RegExp(r'\s+'), '')      // Enlever espaces cachés
        .replaceAll(RegExp(r'[^\w\-./]'), ''); // Garder seulement alphanumériques + - . /
  }

  /// ✅ Valider que l'URL est bien formée
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);

      // Vérifications de base
      if (!uri.hasScheme || !uri.hasAuthority) return false;
      if (uri.scheme != 'http' && uri.scheme != 'https') return false;

      // Vérifier que le path contient bien "profiles"
      if (!uri.path.contains('/profiles/')) return false;

      // Vérifier qu'on n'a pas de double-slash bizarre
      if (uri.path.contains('//')) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 🛠️ Construction manuelle d'URL (fallback robuste)
  String _buildManualUrl(String cleanPath) {
    try {
      // ✅ Utiliser le cache ou détecter l'URL de base
      _cachedStorageBaseUrl ??= _detectStorageBaseUrl();

      if (_cachedStorageBaseUrl == null || _cachedStorageBaseUrl!.isEmpty) {
        debugPrint('❌ Could not detect storage base URL');
        return '';
      }

      // Construire l'URL complète
      final url = '$_cachedStorageBaseUrl/object/public/profiles/$cleanPath';

      debugPrint('🔧 Manual URL built: $url');
      _urlCache[cleanPath] = url;
      return url;

    } catch (e) {
      debugPrint('❌ Failed to build manual URL: $e');
      return '';
    }
  }

  /// 🔍 Détecter l'URL de base du storage via une URL test
  String? _detectStorageBaseUrl() {
    try {
      // ✅ MÉTHODE FIABLE : Construire une URL test et l'analyser
      final testUrl = _supabase.storage.from('profiles').getPublicUrl('test.jpg');

      debugPrint('🔍 Test URL generated: $testUrl');

      final uri = Uri.parse(testUrl);

      // Extraire : https://xxx.supabase.co/storage/v1
      // depuis : https://xxx.supabase.co/storage/v1/object/public/profiles/test.jpg
      final pathSegments = uri.pathSegments;

      // Trouver l'index de "storage"
      final storageIndex = pathSegments.indexOf('storage');

      if (storageIndex >= 0 && storageIndex + 1 < pathSegments.length) {
        final version = pathSegments[storageIndex + 1]; // "v1"
        final baseUrl = '${uri.scheme}://${uri.host}/storage/$version';

        debugPrint('✅ Detected storage base URL: $baseUrl');
        return baseUrl;
      }

      // Fallback : juste prendre scheme + host + /storage/v1
      final fallbackUrl = '${uri.scheme}://${uri.host}/storage/v1';
      debugPrint('⚠️ Using fallback URL: $fallbackUrl');
      return fallbackUrl;

    } catch (e) {
      debugPrint('❌ Failed to detect storage URL: $e');
      return null;
    }
  }

  /// 📸 Construire l'URL pour une photo de profil
  String? buildProfilePhotoUrl(Map<String, dynamic> profile) {
    try {
      final photos = profile['photos'];

      debugPrint('🔍 buildProfilePhotoUrl:');
      debugPrint('   - photos type: ${photos.runtimeType}');

      if (photos == null || photos is! List || photos.isEmpty) {
        debugPrint('   → No photos available');
        return null;
      }

      debugPrint('   → Found ${photos.length} photos');

      // Chercher photo de profil approuvée
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
        return null;
      }

      final path = profilePhoto['remote_path'] as String?;

      if (path == null || path.isEmpty) {
        debugPrint('   → Profile photo has no remote_path');
        return null;
      }

      debugPrint('   → Building URL for path: $path');
      final url = buildPhotoUrl(path);

      debugPrint('   → Final URL: $url');
      return url.isNotEmpty ? url : null;

    } catch (e, stack) {
      debugPrint('❌ Error building profile photo URL: $e');
      debugPrint('Stack: $stack');
      return null;
    }
  }

  /// 🖼️ Construire les URLs de galerie
  List<String> buildGalleryPhotoUrls(Map<String, dynamic> profile) {
    try {
      final photos = profile['photos'];

      if (photos == null || photos is! List || photos.isEmpty) {
        return [];
      }

      final urls = <String>[];

      for (final photo in photos) {
        if (photo['type'] == 'gallery' &&
            photo['status'] == 'approved' &&
            photo['remote_path'] != null &&
            (photo['remote_path'] as String).isNotEmpty) {

          final url = buildPhotoUrl(photo['remote_path'] as String);

          if (url.isNotEmpty) {
            urls.add(url);
          }
        }
      }

      debugPrint('📸 Built ${urls.length} gallery URLs');
      return urls;

    } catch (e, stack) {
      debugPrint('❌ Error building gallery URLs: $e');
      debugPrint('Stack: $stack');
      return [];
    }
  }

  /// 🧹 Nettoyer le cache (utile après modération/suppression)
  void clearCache() {
    _urlCache.clear();
    _cachedStorageBaseUrl = null;
    debugPrint('🧹 Photo URL cache cleared');
  }

  /// 🗑️ Invalider le cache d'une URL spécifique
  Future<void> evictCachedUrl(String path) async {
    try {
      // Supprimer du cache interne
      _urlCache.remove(path);

      // Construire l'URL pour supprimer du cache réseau
      final url = buildPhotoUrl(path);

      if (url.isNotEmpty) {
        // Import requis : import 'package:cached_network_image/cached_network_image.dart';
        await CachedNetworkImage.evictFromCache(url);
        debugPrint('🗑️ Evicted from network cache: $url');
      }
    } catch (e) {
      debugPrint('⚠️ Error evicting cache: $e');
    }
  }

  /// 🔍 Diagnostic : Tester une URL
  Future<bool> testUrl(String url) async {
    try {
      debugPrint('🧪 Testing URL: $url');

      // On ne peut pas faire de requête HTTP depuis Flutter sans package
      // Mais on peut au moins valider le format
      final isValid = _isValidUrl(url);

      debugPrint(isValid ? '✅ URL is valid' : '❌ URL is invalid');
      return isValid;

    } catch (e) {
      debugPrint('❌ Test failed: $e');
      return false;
    }
  }
}