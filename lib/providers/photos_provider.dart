
// Gestion d'état des photos avec Provider + Service Locator

import 'dart:io';

import 'package:flutter/material.dart';

import '../claude/photo_item.dart';
import '../claude/service_locator.dart';
import '../models/photo_item.dart';


/// 📸 Provider pour la gestion des photos
class PhotosProvider with ChangeNotifier {
  final String userId;

  // ═══════════════════════════════════════════════════════════════════
  // 📦 STATE
  // ═══════════════════════════════════════════════════════════════════

  List<PhotoItem> _photos = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<PhotoItem> get photos => _photos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  // Photos par type
  List<PhotoItem> get profilePhotos =>
      _photos.where((p) => p.type == 'profile').toList();
  List<PhotoItem> get galleryPhotos =>
      _photos.where((p) => p.type == 'gallery').toList();

  // Photos par statut
  List<PhotoItem> get approvedPhotos =>
      _photos.where((p) => p.isApproved).toList();
  List<PhotoItem> get pendingPhotos =>
      _photos.where((p) => p.isPending).toList();
  List<PhotoItem> get rejectedPhotos =>
      _photos.where((p) => p.isRejected).toList();

  // Stats
  int get totalPhotos => _photos.length;
  int get approvedCount => approvedPhotos.length;
  int get pendingCount => pendingPhotos.length;

  PhotosProvider({required this.userId}) {
    loadPhotos();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 📥 LOAD - Charger les photos
  // ═══════════════════════════════════════════════════════════════════

  /// Charger les photos (cache-first)
  Future<void> loadPhotos({bool forceRefresh = false}) async {
    _setLoading(true);
    _clearError();

    try {
      debugPrint('📥 Loading photos for user: $userId');

      final photosData = await services.photoCrudService.getPhotos(
        userId: userId,
        forceRefresh: forceRefresh,
      );

      _photos = photosData
          .map((data) => PhotoItem.fromSupabase(data))
          .toList()
          .sortedByOrder();

      debugPrint('✅ Loaded ${_photos.length} photos');

      _setLoading(false);
    } catch (e) {
      debugPrint('❌ Error loading photos: $e');
      _setError('Erreur lors du chargement des photos');
      _setLoading(false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // ➕ ADD - Ajouter une photo
  // ═══════════════════════════════════════════════════════════════════

  /// Ajouter une nouvelle photo locale (pas encore uploadée)
  void addLocalPhoto({
    required File file,
    required String type,
    bool hasWatermark = false,
  }) {
    final newPhoto = PhotoItem.fromLocal(
      file: file,
      type: type,
      displayOrder: _photos.length,
      hasWatermark: hasWatermark,
    );

    _photos.add(newPhoto);
    notifyListeners();

    debugPrint('✅ Local photo added: ${newPhoto.id}');
  }

  /// Upload une photo locale vers Supabase
  Future<bool> uploadPhoto(PhotoItem photo) async {
    if (!photo.needsUpload || photo.localFile == null) {
      debugPrint('⚠️ Photo does not need upload');
      return false;
    }

    try {
      debugPrint('📤 Uploading photo: ${photo.id}');

      final uploadedData = await services.photoCrudService.createPhoto(
        imageFile: photo.localFile!,
        userId: userId,
        type: photo.type,
        displayOrder: photo.displayOrder,
        hasWatermark: photo.hasWatermark,
      );

      if (uploadedData == null) {
        throw Exception('Upload failed');
      }

      // Remplacer la photo locale par la photo remote
      final index = _photos.indexWhere((p) => p.id == photo.id);
      if (index != -1) {
        _photos[index] = PhotoItem.fromSupabase(uploadedData);
        notifyListeners();
      }

      debugPrint('✅ Photo uploaded successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error uploading photo: $e');
      _setError('Erreur lors de l\'upload de la photo');
      return false;
    }
  }

  /// Upload toutes les photos locales
  Future<void> uploadAllLocalPhotos() async {
    final localPhotos = _photos.where((p) => p.needsUpload).toList();

    if (localPhotos.isEmpty) {
      debugPrint('⚠️ No local photos to upload');
      return;
    }

    debugPrint('📤 Uploading ${localPhotos.length} local photos...');

    for (final photo in localPhotos) {
      await uploadPhoto(photo);
    }

    debugPrint('✅ All local photos uploaded');
  }

  // ═══════════════════════════════════════════════════════════════════
  // ✏️ UPDATE - Modifier une photo
  // ═══════════════════════════════════════════════════════════════════

  /// Mettre à jour le displayOrder d'une photo
  Future<bool> updatePhotoOrder(String photoId, int newOrder) async {
    try {
      final success = await services.photoCrudService.updatePhoto(
        photoId: photoId,
        userId: userId,
        displayOrder: newOrder,
      );

      if (success) {
        final index = _photos.indexWhere((p) => p.id == photoId);
        if (index != -1) {
          _photos[index] = _photos[index].copyWith(displayOrder: newOrder);
          _photos = _photos.sortedByOrder();
          notifyListeners();
        }
      }

      return success;
    } catch (e) {
      debugPrint('❌ Error updating photo order: $e');
      return false;
    }
  }

  /// Réordonner les photos (après drag & drop)
  Future<void> reorderPhotos(List<PhotoItem> newOrder) async {
    try {
      debugPrint('🔄 Reordering photos...');

      // Mettre à jour localement d'abord (optimistic update)
      _photos = newOrder.reindex();
      notifyListeners();

      // Puis synchroniser avec Supabase
      for (var i = 0; i < _photos.length; i++) {
        final photo = _photos[i];
        if (photo.isRemote) {
          await services.photoCrudService.updatePhoto(
            photoId: photo.id,
            userId: userId,
            displayOrder: i,
          );
        }
      }

      debugPrint('✅ Photos reordered');
    } catch (e) {
      debugPrint('❌ Error reordering photos: $e');
      // Recharger en cas d'erreur
      await loadPhotos(forceRefresh: true);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🗑️ DELETE - Supprimer une photo
  // ═══════════════════════════════════════════════════════════════════

  /// Supprimer une photo
  Future<bool> deletePhoto(String photoId) async {
    try {
      debugPrint('🗑️ Deleting photo: $photoId');

      // Optimistic delete
      final oldPhotos = List<PhotoItem>.from(_photos);
      _photos.removeWhere((p) => p.id == photoId);
      notifyListeners();

      // Delete depuis Supabase
      final success = await services.photoCrudService.deletePhoto(
        photoId: photoId,
        userId: userId,
      );

      if (!success) {
        // Rollback si erreur
        _photos = oldPhotos;
        notifyListeners();
        _setError('Erreur lors de la suppression');
        return false;
      }

      debugPrint('✅ Photo deleted');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting photo: $e');
      _setError('Erreur lors de la suppression');
      return false;
    }
  }

  /// Supprimer une photo locale (pas encore uploadée)
  void deleteLocalPhoto(String photoId) {
    _photos.removeWhere((p) => p.id == photoId);
    notifyListeners();
    debugPrint('✅ Local photo deleted: $photoId');
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔄 SYNC
  // ═══════════════════════════════════════════════════════════════════

  /// Force refresh depuis Supabase
  Future<void> refresh() async {
    await loadPhotos(forceRefresh: true);
  }

  /// Synchroniser toutes les photos
  Future<void> sync() async {
    try {
      await services.photoCrudService.syncAllPhotos(userId: userId);
      await loadPhotos(forceRefresh: true);
      debugPrint('✅ Photos synced');
    } catch (e) {
      debugPrint('❌ Error syncing photos: $e');
      _setError('Erreur lors de la synchronisation');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔍 QUERIES
  // ═══════════════════════════════════════════════════════════════════

  /// Obtenir une photo par ID
  PhotoItem? getPhotoById(String photoId) {
    try {
      return _photos.firstWhere((p) => p.id == photoId);
    } catch (e) {
      return null;
    }
  }

  /// Vérifier si le user a une photo de profil approuvée
  bool get hasApprovedProfilePhoto {
    return profilePhotos.any((p) => p.isApproved);
  }

  /// Obtenir la photo de profil approuvée
  PhotoItem? get approvedProfilePhoto {
    try {
      return profilePhotos.firstWhere((p) => p.isApproved);
    } catch (e) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔧 INTERNAL HELPERS
  // ═══════════════════════════════════════════════════════════════════

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🧹 CLEANUP
  // ═══════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    debugPrint('🧹 PhotosProvider disposed');
    super.dispose();
  }
}
