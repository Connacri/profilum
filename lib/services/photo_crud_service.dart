// lib/services/photo_crud_service.dart - ✅ VERSION CORRIGÉE SANS has_watermark
// Architecture : Supabase (source de vérité) + LocalCache (vitesse) + CachedNetworkImage (images)

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../claude/local_cache_service.dart';
import 'fix_photo_url_builder.dart';
import 'image_service.dart';


/// 📸 Service CRUD optimisé pour la gestion des photos
/// Couches : Supabase (DB + Storage) → LocalCache → CachedNetworkImage
class PhotoCrudService {
  final SupabaseClient _supabase;
  final LocalCacheService _localCache;
  final ImageService _imageService;
  final PhotoUrlHelper _urlHelper;

  PhotoCrudService({
    required SupabaseClient supabase,
    required LocalCacheService localCache,
    required ImageService imageService,
    required PhotoUrlHelper urlHelper,
  })  : _supabase = supabase,
        _localCache = localCache,
        _imageService = imageService,
        _urlHelper = urlHelper;

  // ════════════════════════════════════════════════════════════════
  // ✅ CREATE - Ajouter une nouvelle photo
  // ════════════════════════════════════════════════════════════════

  /// 📤 Upload une photo complète
  Future<Map<String, dynamic>?> createPhoto({
    required File imageFile,
    required String userId,
    required String type, // 'profile' | 'gallery'
    int? displayOrder,
    bool hasWatermark = false, // ⚠️ Paramètre conservé mais non utilisé en DB
  }) async {
    try {
      debugPrint('════════════════════════════════════════════════════');
      debugPrint('📤 CREATE PHOTO');
      debugPrint('   User: $userId | Type: $type');
      debugPrint('════════════════════════════════════════════════════');

      // ✅ 1. UPLOAD FICHIER → STORAGE
      debugPrint('📦 [1/3] Uploading to Storage...');

      final photoType = type == 'profile'
          ? PhotoType.profile
          : PhotoType.gallery;

      final remotePath = await _imageService.uploadToStorage(
        imageFile: imageFile,
        userId: userId,
        photoType: photoType,
      );

      if (remotePath == null) {
        debugPrint('❌ Upload failed');
        return null;
      }
      debugPrint('✅ Uploaded: $remotePath');

      // ✅ 2. CRÉER MÉTADONNÉES → SUPABASE TABLE
      debugPrint('📝 [2/3] Creating metadata...');

      final photoId = const Uuid().v4();
      final now = DateTime.now().toIso8601String();

      // ✅ CORRECTION : Retrait de 'has_watermark'
      final photoData = {
        'id': photoId,
        'user_id': userId,
        'remote_path': remotePath,
        'type': type,
        'status': 'pending', // Toujours en modération
        'display_order': displayOrder ?? 0,
        'uploaded_at': now,
        'created_at': now,
        'updated_at': now,
      };

      await _supabase.from('photos').insert(photoData);
      debugPrint('✅ Metadata created: $photoId');

      // ✅ 3. MISE À JOUR CACHE LOCAL
      debugPrint('💾 [3/3] Updating local cache...');

      // Ajouter has_watermark dans le cache local uniquement (pas en DB)
      final cachedData = {...photoData, 'has_watermark': hasWatermark};
      await _localCache.addPhoto(userId, cachedData);
      debugPrint('✅ Cache updated');

      debugPrint('════════════════════════════════════════════════════');
      debugPrint('✅ PHOTO CREATED SUCCESSFULLY');
      debugPrint('════════════════════════════════════════════════════');

      return cachedData; // Retourner avec has_watermark pour la cohérence locale

    } catch (e, stack) {
      debugPrint('❌ CREATE PHOTO ERROR: $e');
      debugPrint('Stack: $stack');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════
  // ✅ READ - Récupérer les photos
  // ════════════════════════════════════════════════════════════════

  /// 📥 Récupérer les photos d'un user avec stratégie cache-first
  Future<List<Map<String, dynamic>>> getPhotos({
    required String userId,
    bool forceRefresh = false,
  }) async {
    try {
      debugPrint('════════════════════════════════════════════════════');
      debugPrint('📥 GET PHOTOS');
      debugPrint('   User: $userId | Force: $forceRefresh');
      debugPrint('════════════════════════════════════════════════════');

      // ✅ STRATÉGIE : Cache-first (sauf si forceRefresh)
      if (!forceRefresh) {
        debugPrint('💾 [1/2] Checking local cache...');
        final cachedPhotos = _localCache.getUserPhotos(userId);

        if (cachedPhotos != null && cachedPhotos.isNotEmpty) {
          debugPrint('✅ Found ${cachedPhotos.length} photos in cache');
          debugPrint('════════════════════════════════════════════════════');
          return cachedPhotos;
        }

        debugPrint('⚠️ No cache, fetching from Supabase...');
      }

      // ✅ FETCH DEPUIS SUPABASE
      debugPrint('🌐 [2/2] Fetching from Supabase...');

      final response = await _supabase
          .from('photos')
          .select()
          .eq('user_id', userId)
          .order('display_order', ascending: true);

      final photos = List<Map<String, dynamic>>.from(response);

      debugPrint('✅ Fetched ${photos.length} photos from Supabase');

      // ✅ Ajouter has_watermark par défaut (false) pour compatibilité locale
      final photosWithWatermark = photos.map((photo) {
        return {...photo, 'has_watermark': photo['has_watermark'] ?? false};
      }).toList();

      // ✅ MISE À JOUR CACHE
      await _localCache.saveUserPhotos(userId, photosWithWatermark);
      debugPrint('💾 Cache updated');

      debugPrint('════════════════════════════════════════════════════');
      debugPrint('✅ PHOTOS LOADED SUCCESSFULLY');
      debugPrint('════════════════════════════════════════════════════');

      return photosWithWatermark;

    } catch (e, stack) {
      debugPrint('❌ GET PHOTOS ERROR: $e');
      debugPrint('Stack: $stack');

      // ⚠️ FALLBACK : Essayer le cache même en cas d'erreur
      final cachedPhotos = _localCache.getUserPhotos(userId);
      if (cachedPhotos != null) {
        debugPrint('⚠️ Using cached data as fallback');
        return cachedPhotos;
      }

      return [];
    }
  }

  // ════════════════════════════════════════════════════════════════
  // ✅ UPDATE - Modifier une photo
  // ════════════════════════════════════════════════════════════════

  /// ✏️ Mettre à jour les métadonnées d'une photo
  Future<bool> updatePhoto({
    required String photoId,
    required String userId,
    String? status,
    int? displayOrder,
    String? moderatorId,
    String? rejectionReason,
  }) async {
    try {
      debugPrint('════════════════════════════════════════════════════');
      debugPrint('✏️ UPDATE PHOTO');
      debugPrint('   Photo: $photoId | Status: $status | Order: $displayOrder');
      debugPrint('════════════════════════════════════════════════════');

      // ✅ 1. PRÉPARER LES UPDATES
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (status != null) {
        updates['status'] = status;
        if (status == 'approved' || status == 'rejected') {
          updates['moderated_at'] = DateTime.now().toIso8601String();
          if (moderatorId != null) updates['moderator_id'] = moderatorId;
          if (rejectionReason != null) updates['rejection_reason'] = rejectionReason;
        }
      }

      if (displayOrder != null) {
        updates['display_order'] = displayOrder;
      }

      // ✅ 2. UPDATE SUPABASE
      debugPrint('📝 [1/3] Updating Supabase...');

      await _supabase
          .from('photos')
          .update(updates)
          .eq('id', photoId);

      debugPrint('✅ Supabase updated');

      // ✅ 3. UPDATE CACHE LOCAL
      debugPrint('💾 [2/3] Updating local cache...');
      await _localCache.updatePhoto(userId, photoId, updates);
      debugPrint('✅ Cache updated');

      // ✅ 4. CLEAR IMAGE CACHE (pour forcer refresh)
      debugPrint('🗑️ [3/3] Clearing image cache...');

      // Récupérer le remote_path pour invalider le cache
      final photos = _localCache.getUserPhotos(userId);
      final photo = photos?.firstWhere(
            (p) => p['id'] == photoId,
        orElse: () => {},
      );

      if (photo != null && photo['remote_path'] != null) {
        final remotePath = photo['remote_path'] as String;
        await _urlHelper.evictCachedUrl(remotePath);

        final url = _urlHelper.buildPhotoUrl(remotePath);
        if (url.isNotEmpty) {
          await CachedNetworkImage.evictFromCache(url);
        }
      }

      debugPrint('✅ Image cache cleared');

      debugPrint('════════════════════════════════════════════════════');
      debugPrint('✅ PHOTO UPDATED SUCCESSFULLY');
      debugPrint('════════════════════════════════════════════════════');

      return true;

    } catch (e, stack) {
      debugPrint('❌ UPDATE PHOTO ERROR: $e');
      debugPrint('Stack: $stack');
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════════
  // ✅ DELETE - Supprimer une photo
  // ════════════════════════════════════════════════════════════════

  /// 🗑️ Supprimer complètement une photo
  Future<bool> deletePhoto({
    required String photoId,
    required String userId,
  }) async {
    try {
      debugPrint('════════════════════════════════════════════════════');
      debugPrint('🗑️ DELETE PHOTO');
      debugPrint('   Photo: $photoId | User: $userId');
      debugPrint('════════════════════════════════════════════════════');

      // ✅ 0. RÉCUPÉRER LES INFOS
      debugPrint('📋 [0/4] Fetching photo info...');

      final photoData = await _supabase
          .from('photos')
          .select('remote_path')
          .eq('id', photoId)
          .maybeSingle();

      if (photoData == null) {
        debugPrint('⚠️ Photo not found');
        return false;
      }

      final remotePath = photoData['remote_path'] as String?;

      if (remotePath == null || remotePath.isEmpty) {
        debugPrint('⚠️ No remote_path found');
      } else {
        debugPrint('✅ Photo info: $remotePath');
      }

      // ✅ 1. SUPPRIMER FICHIER → STORAGE
      if (remotePath != null && remotePath.isNotEmpty) {
        debugPrint('📦 [1/4] Deleting from Storage...');

        final storageDeleted = await _imageService.deleteFromStorage(
          path: remotePath,
        );

        if (!storageDeleted) {
          debugPrint('⚠️ Storage deletion failed (continuing)');
        } else {
          debugPrint('✅ Storage deleted');
        }
      }

      // ✅ 2. SUPPRIMER MÉTADONNÉES → SUPABASE TABLE
      debugPrint('📝 [2/4] Deleting from Supabase...');

      await _supabase
          .from('photos')
          .delete()
          .eq('id', photoId);

      debugPrint('✅ Supabase deleted');

      // ✅ 3. SUPPRIMER CACHE LOCAL
      debugPrint('💾 [3/4] Deleting from cache...');
      await _localCache.deletePhoto(userId, photoId);
      debugPrint('✅ Cache deleted');

      // ✅ 4. CLEAR IMAGE CACHE
      if (remotePath != null && remotePath.isNotEmpty) {
        debugPrint('🗑️ [4/4] Clearing image cache...');

        await _urlHelper.evictCachedUrl(remotePath);
        final url = _urlHelper.buildPhotoUrl(remotePath);
        if (url.isNotEmpty) {
          await CachedNetworkImage.evictFromCache(url);
        }

        debugPrint('✅ Image cache cleared');
      }

      debugPrint('════════════════════════════════════════════════════');
      debugPrint('✅ PHOTO DELETED SUCCESSFULLY');
      debugPrint('════════════════════════════════════════════════════');

      return true;

    } catch (e, stack) {
      debugPrint('❌ DELETE PHOTO ERROR: $e');
      debugPrint('Stack: $stack');
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════════
  // 🔄 SYNC - Synchronisation
  // ════════════════════════════════════════════════════════════════

  /// 🔄 Synchroniser toutes les photos d'un user
  Future<bool> syncAllPhotos({required String userId}) async {
    try {
      debugPrint('════════════════════════════════════════════════════');
      debugPrint('🔄 SYNC PHOTOS');
      debugPrint('   User: $userId');
      debugPrint('════════════════════════════════════════════════════');

      // ✅ 1. Clear tous les caches
      debugPrint('🗑️ [1/2] Clearing all caches...');

      _urlHelper.clearCache();
      await _localCache.clearUserPhotos(userId);

      debugPrint('✅ Caches cleared');

      // ✅ 2. Force refresh depuis Supabase
      debugPrint('🌐 [2/2] Force refreshing...');
      final photos = await getPhotos(userId: userId, forceRefresh: true);

      debugPrint('════════════════════════════════════════════════════');
      debugPrint('✅ SYNC COMPLETE');
      debugPrint('   Synced: ${photos.length} photos');
      debugPrint('════════════════════════════════════════════════════');

      return true;

    } catch (e, stack) {
      debugPrint('❌ SYNC ERROR: $e');
      debugPrint('Stack: $stack');
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════════
  // 🧹 CLEANUP - Nettoyage complet
  // ════════════════════════════════════════════════════════════════

  /// 🧹 Supprimer toutes les photos d'un user (suppression de compte)
  Future<bool> deleteAllUserPhotos({required String userId}) async {
    try {
      debugPrint('════════════════════════════════════════════════════');
      debugPrint('🧹 DELETE ALL USER PHOTOS');
      debugPrint('   User: $userId');
      debugPrint('════════════════════════════════════════════════════');

      // Récupérer toutes les photos
      final photos = await getPhotos(userId: userId, forceRefresh: true);

      debugPrint('📋 Found ${photos.length} photos to delete');

      // Supprimer chaque photo
      int successCount = 0;
      for (final photo in photos) {
        final photoId = photo['id'] as String;
        final deleted = await deletePhoto(photoId: photoId, userId: userId);
        if (deleted) successCount++;
      }

      debugPrint('════════════════════════════════════════════════════');
      debugPrint('✅ CLEANUP COMPLETE');
      debugPrint('   Deleted: $successCount/${photos.length}');
      debugPrint('════════════════════════════════════════════════════');

      return successCount == photos.length;

    } catch (e, stack) {
      debugPrint('❌ DELETE ALL ERROR: $e');
      debugPrint('Stack: $stack');
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════════
  // 📊 HELPERS - Méthodes utilitaires
  // ════════════════════════════════════════════════════════════════

  /// 📸 Obtenir la photo de profil d'un user
  Future<Map<String, dynamic>?> getProfilePhoto(String userId) async {
    final photos = await getPhotos(userId: userId);

    try {
      return photos.firstWhere(
            (p) => p['type'] == 'profile' && p['status'] == 'approved',
      );
    } catch (e) {
      return null;
    }
  }

  /// 🖼️ Obtenir les photos de galerie d'un user
  Future<List<Map<String, dynamic>>> getGalleryPhotos(String userId) async {
    final photos = await getPhotos(userId: userId);
    return photos
        .where((p) => p['type'] == 'gallery' && p['status'] == 'approved')
        .toList();
  }

  /// 📊 Obtenir les photos en attente de modération
  Future<List<Map<String, dynamic>>> getPendingPhotos(String userId) async {
    final photos = await getPhotos(userId: userId);
    return photos.where((p) => p['status'] == 'pending').toList();
  }

  /// 📊 Compter les photos par statut
  Future<Map<String, int>> getPhotoStats(String userId) async {
    final photos = await getPhotos(userId: userId);

    return {
      'total': photos.length,
      'profile': photos.where((p) => p['type'] == 'profile').length,
      'gallery': photos.where((p) => p['type'] == 'gallery').length,
      'pending': photos.where((p) => p['status'] == 'pending').length,
      'approved': photos.where((p) => p['status'] == 'approved').length,
      'rejected': photos.where((p) => p['status'] == 'rejected').length,
    };
  }

  /// 📝 Vérifier si un user a une photo de profil approuvée
  Future<bool> hasApprovedProfilePhoto(String userId) async {
    final profilePhoto = await getProfilePhoto(userId);
    return profilePhoto != null;
  }

  /// 📸 Obtenir l'URL de la photo de profil
  Future<String?> getProfilePhotoUrl(String userId) async {
    final photo = await getProfilePhoto(userId);
    if (photo == null) return null;

    final remotePath = photo['remote_path'] as String?;
    if (remotePath == null || remotePath.isEmpty) return null;

    return _urlHelper.buildPhotoUrl(remotePath);
  }
}