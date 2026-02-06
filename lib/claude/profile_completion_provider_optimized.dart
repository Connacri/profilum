// lib/providers/profile_completion_provider.dart - ✅ VERSION OPTIMISÉE SANS OBJECTBOX
// Migration vers architecture Supabase + LocalCache

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/social_link_model.dart';

import 'photo_item.dart';
import 'service_locator.dart';

/// 🎯 Provider pour la complétion de profil
/// Architecture : Supabase (source unique) → LocalCache → UI
class ProfileCompletionProvider extends ChangeNotifier {
  Timer? _calculationTimer;
  
  // ═══════════════════════════════════════════════════════════════════
  // 📦 STATE
  // ═══════════════════════════════════════════════════════════════════
  
  Map<String, dynamic>? _userData;
  PhotoItem? _profilePhoto;
  List<PhotoItem> _galleryPhotos = [];

  // ✅ Tracking suppressions (PATH uniquement)
  final Set<String> _deletedPhotoPaths = {};
  String? _deletedProfilePhotoPath;

  bool _isLoading = false;
  bool _isLoadingPhotos = false;
  String? _errorMessage;

  final Map<String, bool> _completionFields = {
    'full_name': false,
    'date_of_birth': false,
    'gender': false,
    'looking_for': false,
    'bio': false,
    'city': false,
    'country': false,
    'occupation': false,
    'education': false,
    'height_cm': false,
    'relationship_status': false,
    'interests': false,
    'social_links': false,
    'profile_photo': false,
    'gallery_photos': false,
  };

  // ═══════════════════════════════════════════════════════════════════
  // 🔍 GETTERS
  // ═══════════════════════════════════════════════════════════════════

  int get completionPercentage {
    final completed = _completionFields.values.where((v) => v).length;
    return ((completed / _completionFields.length) * 100).round();
  }

  bool get isComplete => completionPercentage >= 80;
  bool get isLoading => _isLoading;
  bool get isLoadingPhotos => _isLoadingPhotos;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get userData => _userData;
  String? get userId => _userData?['user_id'] as String?;
  
  PhotoItem? get profilePhoto => _profilePhoto;
  List<PhotoItem> get galleryPhotos => _galleryPhotos;
  bool get hasProfilePhoto => _profilePhoto != null;
  bool get hasMinGallery => _galleryPhotos.length >= 3;
  bool get mounted => _userData != null;

  // Helpers pour accès aux champs
  String? get fullName => _userData?['full_name'] as String?;
  DateTime? get dateOfBirth {
    final dobStr = _userData?['date_of_birth'] as String?;
    return dobStr != null ? DateTime.tryParse(dobStr) : null;
  }
  String? get gender => _userData?['gender'] as String?;
  String? get lookingFor => _userData?['looking_for'] as String?;
  String? get bio => _userData?['bio'] as String?;
  String? get city => _userData?['city'] as String?;
  String? get country => _userData?['country'] as String?;
  String? get occupation => _userData?['occupation'] as String?;
  String? get education => _userData?['education'] as String?;
  int? get heightCm => _userData?['height_cm'] as int?;
  String? get relationshipStatus => _userData?['relationship_status'] as String?;
  
  List<String> get interests {
    final interestsData = _userData?['interests'];
    if (interestsData is List) {
      return List<String>.from(interestsData);
    }
    return [];
  }

  List<SocialLink> get socialLinks {
    final linksData = _userData?['social_links'];
    if (linksData is List) {
      return linksData.map((e) => SocialLink.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  @override
  void dispose() {
    _calculationTimer?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🚀 INITIALISATION
  // ═══════════════════════════════════════════════════════════════════

  /// Initialiser avec les données utilisateur
  Future<void> initialize(Map<String, dynamic> userData) async {
    _userData = userData;
    _updateCompletionFields();
    
    // Charger les photos après le premier frame
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _loadExistingPhotos(),
    );
  }

  /// Charger depuis le cache/Supabase
  Future<void> initializeFromUserId(String userId) async {
    try {
      _isLoading = true;
      safeNotify();

      // ✅ Charger les données user (cache-first)
      final userData = await services.supabaseService.getUserData(userId);
      
      if (userData != null) {
        await initialize(userData);
      } else {
        throw Exception('User data not found');
      }

      _isLoading = false;
      safeNotify();
    } catch (e) {
      debugPrint('❌ Error initializing: $e');
      _errorMessage = 'Erreur lors du chargement du profil';
      _isLoading = false;
      safeNotify();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 📸 GESTION DES PHOTOS
  // ═══════════════════════════════════════════════════════════════════

  /// Charger les photos existantes
  Future<void> _loadExistingPhotos() async {
    if (userId == null) return;

    _isLoadingPhotos = true;
    safeNotify();

    try {
      debugPrint('📸 Loading photos for user: $userId');

      // ✅ Charger depuis PhotoCrudService (cache-first)
      final photos = await services.photoCrudService.getPhotos(
        userId: userId!,
        forceRefresh: false,
      );

      // ✅ Accepter approved ET pending (pas rejected)
      final validPhotos = photos
          .where((p) => 
              (p['status'] == 'approved' || p['status'] == 'pending') &&
              p['remote_path'] != null
          )
          .toList();

      validPhotos.sort((a, b) {
        final orderA = a['display_order'] as int? ?? 0;
        final orderB = b['display_order'] as int? ?? 0;
        return orderA.compareTo(orderB);
      });

      debugPrint('📸 Loaded ${validPhotos.length} photos (approved + pending)');

      // ✅ Photo de profil
      final profilePhotoData = validPhotos
          .where((p) => p['type'] == 'profile')
          .firstOrNull;

      if (profilePhotoData != null) {
        _profilePhoto = PhotoItem.fromSupabase(profilePhotoData);
        debugPrint('📷 Profile photo: ${_profilePhoto!.status}');
      }

      // ✅ Photos galerie
      _galleryPhotos = validPhotos
          .where((p) => p['type'] == 'gallery')
          .map((p) => PhotoItem.fromSupabase(p))
          .toList();

      debugPrint('🖼️ Gallery photos: ${_galleryPhotos.length}');
      for (var i = 0; i < _galleryPhotos.length; i++) {
        debugPrint('   [$i] ${_galleryPhotos[i].status}');
      }

      _updateCompletionFields();
    } catch (e, stack) {
      debugPrint('❌ Error loading photos: $e');
      debugPrint('Stack: $stack');
    } finally {
      _isLoadingPhotos = false;
      safeNotify();
    }
  }

  /// Recharger les photos
  Future<void> refreshPhotos() async {
    if (userId == null) return;

    try {
      // Force refresh depuis Supabase
      final photos = await services.photoCrudService.getPhotos(
        userId: userId!,
        forceRefresh: true,
      );

      // Re-process comme dans _loadExistingPhotos
      final validPhotos = photos
          .where((p) => 
              (p['status'] == 'approved' || p['status'] == 'pending') &&
              p['remote_path'] != null
          )
          .toList();

      validPhotos.sort((a, b) {
        final orderA = a['display_order'] as int? ?? 0;
        final orderB = b['display_order'] as int? ?? 0;
        return orderA.compareTo(orderB);
      });

      final profilePhotoData = validPhotos
          .where((p) => p['type'] == 'profile')
          .firstOrNull;

      _profilePhoto = profilePhotoData != null 
          ? PhotoItem.fromSupabase(profilePhotoData)
          : null;

      _galleryPhotos = validPhotos
          .where((p) => p['type'] == 'gallery')
          .map((p) => PhotoItem.fromSupabase(p))
          .toList();

      _updateCompletionFields();
      safeNotify();

      debugPrint('✅ Photos refreshed');
    } catch (e) {
      debugPrint('❌ Error refreshing photos: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 📸 AJOUT/MODIFICATION PHOTOS
  // ═══════════════════════════════════════════════════════════════════

  /// Définir la photo de profil
  Future<void> setProfilePhoto({required bool fromCamera}) async {
    final photo = fromCamera
        ? await services.imageService.captureFromCamera()
        : await services.imageService.pickFromGallery();

    if (photo == null) return;

    // Si déjà une photo, marquer l'ancienne pour suppression
    if (_profilePhoto != null && _profilePhoto!.isRemote) {
      _deletedProfilePhotoPath = _profilePhoto!.remotePath;
    }

    // Créer la nouvelle photo locale
    _profilePhoto = PhotoItem.fromLocal(
      file: photo,
      type: 'profile',
      displayOrder: 0,
      hasWatermark: fromCamera,
    );

    _updateCompletionFields();
  }

  /// Supprimer la photo de profil
  void removeProfilePhoto() {
    if (_profilePhoto == null) return;

    // Si photo remote, marquer pour suppression
    if (_profilePhoto!.isRemote && _profilePhoto!.remotePath != null) {
      _deletedProfilePhotoPath = _profilePhoto!.remotePath;
    }

    _profilePhoto = null;
    _updateCompletionFields();
  }

  /// Ajouter des photos à la galerie
  Future<void> addGalleryPhotos({required bool fromCamera}) async {
    if (_galleryPhotos.length >= 6) {
      debugPrint('⚠️ Max 6 gallery photos');
      return;
    }

    if (fromCamera) {
      final photo = await services.imageService.captureFromCamera();
      if (photo != null) {
        _addGalleryPhoto(photo, hasWatermark: true);
      }
    } else {
      final photos = await services.imageService.pickMultipleFromGallery(
        maxImages: 6 - _galleryPhotos.length,
      );
      
      for (final photo in photos) {
        _addGalleryPhoto(photo, hasWatermark: false);
      }
    }
  }

  void _addGalleryPhoto(File file, {required bool hasWatermark}) {
    final newPhoto = PhotoItem.fromLocal(
      file: file,
      type: 'gallery',
      displayOrder: _galleryPhotos.length,
      hasWatermark: hasWatermark,
    );

    _galleryPhotos.add(newPhoto);
    _updateCompletionFields();
  }

  /// Supprimer une photo de galerie
  void removeGalleryPhoto(int index) {
    if (index < 0 || index >= _galleryPhotos.length) return;

    final photo = _galleryPhotos[index];

    // Si photo remote, marquer pour suppression
    if (photo.isRemote && photo.remotePath != null) {
      _deletedPhotoPaths.add(photo.remotePath!);
    }

    _galleryPhotos.removeAt(index);

    // Réindexer
    for (var i = 0; i < _galleryPhotos.length; i++) {
      _galleryPhotos[i] = _galleryPhotos[i].copyWith(displayOrder: i);
    }

    _updateCompletionFields();
  }

  /// Réordonner les photos de galerie
  void reorderGalleryPhotos(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final photo = _galleryPhotos.removeAt(oldIndex);
    _galleryPhotos.insert(newIndex, photo);

    // Réindexer
    for (var i = 0; i < _galleryPhotos.length; i++) {
      _galleryPhotos[i] = _galleryPhotos[i].copyWith(displayOrder: i);
    }

    _updateCompletionFields();
  }

  // ═══════════════════════════════════════════════════════════════════
  // ✏️ MODIFICATION DES CHAMPS
  // ═══════════════════════════════════════════════════════════════════

  void _updateCompletionFields() {
    if (_userData == null) return;

    _completionFields['full_name'] = fullName?.isNotEmpty ?? false;
    _completionFields['date_of_birth'] = dateOfBirth != null;
    _completionFields['gender'] = gender?.isNotEmpty ?? false;
    _completionFields['looking_for'] = lookingFor?.isNotEmpty ?? false;
    _completionFields['bio'] = (bio?.length ?? 0) >= 50;
    _completionFields['city'] = city?.isNotEmpty ?? false;
    _completionFields['country'] = country?.isNotEmpty ?? false;
    _completionFields['occupation'] = occupation?.isNotEmpty ?? false;
    _completionFields['education'] = education?.isNotEmpty ?? false;
    _completionFields['height_cm'] = heightCm != null;
    _completionFields['relationship_status'] = 
        relationshipStatus?.isNotEmpty ?? false;
    _completionFields['interests'] = interests.length >= 3;
    _completionFields['social_links'] = socialLinks.isNotEmpty;
    _completionFields['profile_photo'] = _profilePhoto != null;
    _completionFields['gallery_photos'] = _galleryPhotos.length >= 3;

    safeNotify();
  }

  void updateField(String field, dynamic value) {
    if (_userData == null) return;

    switch (field) {
      case 'full_name':
        _userData!['full_name'] = value;
        break;
      case 'date_of_birth':
        _userData!['date_of_birth'] = value is DateTime 
            ? value.toIso8601String() 
            : value;
        break;
      case 'gender':
        _userData!['gender'] = value;
        break;
      case 'looking_for':
        _userData!['looking_for'] = value;
        break;
      case 'bio':
        _userData!['bio'] = value;
        break;
      case 'city':
        _userData!['city'] = value;
        break;
      case 'country':
        _userData!['country'] = value;
        break;
      case 'occupation':
        _userData!['occupation'] = value;
        break;
      case 'education':
        _userData!['education'] = value;
        break;
      case 'height_cm':
        _userData!['height_cm'] = value;
        break;
      case 'relationship_status':
        _userData!['relationship_status'] = value;
        break;
      case 'interests':
        _userData!['interests'] = List<String>.from(value);
        break;
      case 'social_links':
        _userData!['social_links'] = 
            (value as List<SocialLink>).map((e) => e.toJson()).toList();
        break;
    }

    _updateCompletionFields();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 💾 SAUVEGARDE
  // ═══════════════════════════════════════════════════════════════════

  /// Sauvegarder le profil complet
  Future<bool> saveProfile({bool isSkipped = false}) async {
    if (_userData == null || userId == null) return false;

    _isLoading = true;
    _errorMessage = null;
    safeNotify();

    try {
      debugPrint('════════════════════════════════════════════════════');
      debugPrint('💾 SAVING PROFILE');
      debugPrint('════════════════════════════════════════════════════');

      // ════════════════════════════════════════════════════════════
      // 1. SUPPRIMER LES PHOTOS MARQUÉES
      // ════════════════════════════════════════════════════════════

      if (_deletedProfilePhotoPath != null) {
        debugPrint('🗑️ [1/3] Deleting old profile photo...');
        await _deletePhotoFromSupabase(_deletedProfilePhotoPath!);
        _deletedProfilePhotoPath = null;
      }

      for (final path in _deletedPhotoPaths) {
        debugPrint('🗑️ Deleting gallery photo: $path');
        await _deletePhotoFromSupabase(path);
      }
      _deletedPhotoPaths.clear();

      // ════════════════════════════════════════════════════════════
      // 2. UPLOAD NOUVELLES PHOTOS
      // ════════════════════════════════════════════════════════════

      debugPrint('📤 [2/3] Uploading new photos...');

      // Photo de profil
      if (_profilePhoto != null && _profilePhoto!.needsUpload) {
        debugPrint('📸 Uploading profile photo...');
        
        final photoData = await services.photoCrudService.createPhoto(
          imageFile: _profilePhoto!.localFile!,
          userId: userId!,
          type: 'profile',
          displayOrder: 0,
          hasWatermark: _profilePhoto!.hasWatermark,
        );

        if (photoData != null) {
          _profilePhoto = PhotoItem.fromSupabase(photoData);
          debugPrint('✅ Profile photo uploaded');
        }
      }

      // Photos galerie
      final newGalleryPhotos = _galleryPhotos.where((p) => p.needsUpload).toList();
      debugPrint('📸 Uploading ${newGalleryPhotos.length} gallery photos...');

      for (var i = 0; i < newGalleryPhotos.length; i++) {
        final photo = newGalleryPhotos[i];
        
        final photoData = await services.photoCrudService.createPhoto(
          imageFile: photo.localFile!,
          userId: userId!,
          type: 'gallery',
          displayOrder: photo.displayOrder,
          hasWatermark: photo.hasWatermark,
        );

        if (photoData != null) {
          final index = _galleryPhotos.indexWhere((p) => p.id == photo.id);
          if (index != -1) {
            _galleryPhotos[index] = PhotoItem.fromSupabase(photoData);
          }
          debugPrint('✅ Gallery photo ${i + 1}/${newGalleryPhotos.length} uploaded');
        }
      }

      // ════════════════════════════════════════════════════════════
      // 3. MISE À JOUR PROFIL
      // ════════════════════════════════════════════════════════════

      debugPrint('📝 [3/3] Updating profile...');

      final finalCompletion = completionPercentage;
      final isProfileComplete = !isSkipped && finalCompletion >= 80;

      debugPrint('📊 Completion: $finalCompletion%');
      debugPrint('📊 Profile complete: $isProfileComplete');

      final updateData = {
        'full_name': fullName,
        'date_of_birth': dateOfBirth?.toIso8601String(),
        'gender': gender,
        'looking_for': lookingFor,
        'bio': bio,
        'city': city,
        'country': country,
        'occupation': occupation,
        'education': education,
        'height_cm': heightCm,
        'relationship_status': relationshipStatus,
        'interests': interests,
        'social_links': socialLinks.map((e) => e.toJson()).toList(),
        'profile_completed': isProfileComplete,
        'completion_percentage': finalCompletion,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // ✅ Update Supabase
      await services.supabase
          .from('profiles')
          .update(updateData)
          .eq('id', userId!);
      
      debugPrint('✅ Supabase updated');

      // ✅ Update cache local
      _userData = {..._userData!, ...updateData};
      await services.cache.saveUserData(_userData!);
      
      debugPrint('✅ Cache updated');

      debugPrint('════════════════════════════════════════════════════');
      debugPrint('✅ PROFILE SAVED SUCCESSFULLY');
      debugPrint('════════════════════════════════════════════════════');

      _isLoading = false;
      safeNotify();
      return true;

    } catch (e, stack) {
      debugPrint('════════════════════════════════════════════════════');
      debugPrint('❌ SAVE PROFILE ERROR');
      debugPrint('Error: $e');
      debugPrint('Stack: $stack');
      debugPrint('════════════════════════════════════════════════════');
      
      _errorMessage = 'Erreur de sauvegarde: $e';
      _isLoading = false;
      safeNotify();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🗑️ SUPPRESSION PHOTO
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _deletePhotoFromSupabase(String path) async {
    try {
      debugPrint('🗑️ Deleting photo: $path');

      // Récupérer l'ID via le path
      final photoData = await services.supabase
          .from('photos')
          .select('id')
          .eq('remote_path', path)
          .maybeSingle();

      if (photoData != null) {
        final photoId = photoData['id'] as String;
        
        // Utiliser PhotoCrudService pour supprimer
        await services.photoCrudService.deletePhoto(
          photoId: photoId,
          userId: userId!,
        );
        
        debugPrint('✅ Photo deleted: $photoId');
      }
    } catch (e) {
      debugPrint('❌ Error deleting photo $path: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔧 HELPERS
  // ═══════════════════════════════════════════════════════════════════

  void reset() {
    debugPrint('🧹 ProfileCompletionProvider: Resetting all data');

    _userData = null;
    _profilePhoto = null;
    _galleryPhotos.clear();
    _deletedPhotoPaths.clear();
    _deletedProfilePhotoPath = null;
    _isLoading = false;
    _isLoadingPhotos = false;
    _errorMessage = null;
    _completionFields.updateAll((key, value) => false);

    debugPrint('✅ ProfileCompletionProvider reset complete');
    safeNotify();
  }

  void safeNotify() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }
}
