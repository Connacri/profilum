import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/photo_item.dart';
import '../models/social_link_model.dart';
import '../objectbox_entities_complete.dart';
import '../services/image_service.dart';
import '../services/services.dart';

class ProfileCompletionProvider extends ChangeNotifier {
  final SupabaseClient _supabase;
  final ObjectBoxService _objectBox;
  final ImageService _imageService;

  Timer? _calculationTimer;

  UserEntity? _user;

  // ✅ Photos actuelles
  PhotoItem? _profilePhoto;
  List<PhotoItem> _galleryPhotos = [];

  // ✅ NOUVEAU : Tracking des suppressions (pour photos distantes)
  final Set<String> _deletedPhotoIds = {};
  String? _deletedProfilePhotoId;

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

  ProfileCompletionProvider(
    this._supabase,
    this._objectBox,
    this._imageService,
  );

  @override
  void dispose() {
    _calculationTimer?.cancel();
    super.dispose();
  }

  // Getters
  int get completionPercentage {
    final completed = _completionFields.values.where((v) => v).length;
    return ((completed / _completionFields.length) * 100).round();
  }

  bool get isComplete => completionPercentage >= 80;
  bool get isLoading => _isLoading;
  bool get isLoadingPhotos => _isLoadingPhotos;
  String? get errorMessage => _errorMessage;
  UserEntity? get user => _user;
  ImageService get imageService => _imageService;

  PhotoItem? get profilePhoto => _profilePhoto;
  List<PhotoItem> get galleryPhotos => _galleryPhotos;

  bool get hasProfilePhoto => _profilePhoto != null;
  bool get hasMinGallery => _galleryPhotos.length >= 3;

  /// Initialisation
  Future<void> initialize(UserEntity user) async {
    _user = user;
    _updateCompletionFields();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadExistingPhotos();
    });
  }

  /// Charger les photos depuis ObjectBox avec toutes les infos (status, watermark, etc.)
  Future<void> _loadExistingPhotos() async {
    if (_user == null) return;

    _isLoadingPhotos = true;
    safeNotify();

    try {
      final photos = await _objectBox.getUserPhotos(_user!.userId);
      final approved = photos.where((p) => p.status == 'approved').toList();
      approved.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      // ✅ Photo de profil avec infos complètes
      final profilePhotoEntity = approved
          .where((p) => p.type == 'profile')
          .firstOrNull;

      if (profilePhotoEntity != null && profilePhotoEntity.remotePath != null) {
        _profilePhoto = PhotoItem(
          id: profilePhotoEntity.photoId,
          source: PhotoSource.remote,
          remotePath: profilePhotoEntity.remotePath,
          displayOrder: 0,
          type: 'profile',
          status: profilePhotoEntity.status, // ✅ AJOUTÉ
          hasWatermark: profilePhotoEntity.hasWatermark, // ✅ AJOUTÉ
          uploadedAt: profilePhotoEntity.uploadedAt, // ✅ AJOUTÉ
          moderatedAt: profilePhotoEntity.moderatedAt, // ✅ AJOUTÉ
        );
      }

      // ✅ Photos galerie avec infos complètes
      _galleryPhotos = approved
          .where((p) => p.type == 'gallery' && p.remotePath != null)
          .map(
            (p) => PhotoItem(
              id: p.photoId,
              source: PhotoSource.remote,
              remotePath: p.remotePath,
              displayOrder: p.displayOrder,
              type: 'gallery',
              status: p.status, // ✅ AJOUTÉ
              hasWatermark: p.hasWatermark, // ✅ AJOUTÉ
              uploadedAt: p.uploadedAt, // ✅ AJOUTÉ
              moderatedAt: p.moderatedAt, // ✅ AJOUTÉ
            ),
          )
          .toList();

      debugPrint('✅ Loaded ${_galleryPhotos.length} existing photos');

      _updateCompletionFields();
    } catch (e) {
      debugPrint('❌ Error loading photos: $e');
    } finally {
      _isLoadingPhotos = false;
      safeNotify();
    }
  }

  void _updateCompletionFields() {
    if (_user == null) return;

    _completionFields['full_name'] = _user!.fullName?.isNotEmpty ?? false;
    _completionFields['date_of_birth'] = _user!.dateOfBirth != null;
    _completionFields['gender'] = _user!.gender?.isNotEmpty ?? false;
    _completionFields['looking_for'] = _user!.lookingFor?.isNotEmpty ?? false;
    _completionFields['bio'] = (_user!.bio?.length ?? 0) >= 50;
    _completionFields['city'] = _user!.city?.isNotEmpty ?? false;
    _completionFields['country'] = _user!.country?.isNotEmpty ?? false;
    _completionFields['occupation'] = _user!.occupation?.isNotEmpty ?? false;
    _completionFields['education'] = _user!.education?.isNotEmpty ?? false;
    _completionFields['height_cm'] = _user!.heightCm != null;
    _completionFields['relationship_status'] =
        _user!.relationshipStatus?.isNotEmpty ?? false;
    _completionFields['interests'] = _user!.interests.length >= 3;
    _completionFields['social_links'] = _user!.socialLinks.isNotEmpty;

    _completionFields['profile_photo'] = _profilePhoto != null;
    _completionFields['gallery_photos'] = _galleryPhotos.length >= 3;

    safeNotify();
  }

  void updateField(String field, dynamic value) {
    if (_user == null) return;

    switch (field) {
      case 'full_name':
        _user = _user!..fullName = value;
        break;
      case 'date_of_birth':
        _user = _user!..dateOfBirth = value;
        break;
      case 'gender':
        _user = _user!..gender = value;
        break;
      case 'looking_for':
        _user = _user!..lookingFor = value;
        break;
      case 'bio':
        _user = _user!..bio = value;
        break;
      case 'city':
        _user = _user!..city = value;
        break;
      case 'country':
        _user = _user!..country = value;
        break;
      case 'occupation':
        _user = _user!..occupation = value;
        break;
      case 'education':
        _user = _user!..education = value;
        break;
      case 'height_cm':
        _user = _user!..heightCm = value;
        break;
      case 'relationship_status':
        _user = _user!..relationshipStatus = value;
        break;
      case 'interests':
        _user = _user!..interests = List<String>.from(value);
        break;
      case 'social_links':
        _user = _user!..socialLinks = List<SocialLink>.from(value);
        break;
    }

    _updateCompletionFields();
  }

  /// ✅ Ajouter/Remplacer photo de profil
  Future<void> setProfilePhoto({required bool fromCamera}) async {
    final photo = fromCamera
        ? await _imageService.captureFromCamera()
        : await _imageService.pickFromGallery();

    if (photo != null) {
      // ✅ Si photo existante distante, la marquer pour suppression
      if (_profilePhoto != null &&
          _profilePhoto!.source == PhotoSource.remote) {
        _deletedProfilePhotoId = _profilePhoto!.id;
        debugPrint(
          '🗑️ Profile photo marquée pour suppression: ${_profilePhoto!.id}',
        );
      }

      // Ajouter la nouvelle photo (locale)
      _profilePhoto = PhotoItem(
        id: const Uuid().v4(),
        source: PhotoSource.local,
        localFile: photo,
        displayOrder: 0,
        type: 'profile',
        isModified: true,
      );

      _updateCompletionFields();
      debugPrint('✅ Nouvelle photo de profil ajoutée (locale)');
    }
  }

  /// ✅ Supprimer photo de profil
  void removeProfilePhoto() {
    if (_profilePhoto == null) return;

    // Si photo distante, la marquer pour suppression
    if (_profilePhoto!.source == PhotoSource.remote) {
      _deletedProfilePhotoId = _profilePhoto!.id;
      debugPrint(
        '🗑️ Profile photo marquée pour suppression: ${_profilePhoto!.id}',
      );
    }

    _profilePhoto = null;
    _updateCompletionFields();
  }

  /// ✅ Ajouter photos galerie
  Future<void> addGalleryPhotos({required bool fromCamera}) async {
    if (_galleryPhotos.length >= 6) {
      _errorMessage = 'Maximum 6 photos de galerie';
      safeNotify();
      return;
    }

    if (fromCamera) {
      final photo = await _imageService.captureFromCamera();
      if (photo != null) {
        _galleryPhotos.add(
          PhotoItem(
            id: const Uuid().v4(),
            source: PhotoSource.local,
            localFile: photo,
            displayOrder: _galleryPhotos.length,
            type: 'gallery',
            isModified: true,
          ),
        );
        _updateCompletionFields();
      }
    } else {
      final remainingSlots = 6 - _galleryPhotos.length;
      final photos = await _imageService.pickMultipleFromGallery(
        maxImages: remainingSlots,
      );

      for (var photo in photos) {
        _galleryPhotos.add(
          PhotoItem(
            id: const Uuid().v4(),
            source: PhotoSource.local,
            localFile: photo,
            displayOrder: _galleryPhotos.length,
            type: 'gallery',
            isModified: true,
          ),
        );
      }
      _updateCompletionFields();
    }
  }

  /// ✅ Supprimer photo galerie
  Future<void> removeGalleryPhoto(int index) async {
    if (index >= _galleryPhotos.length) return;

    final photo = _galleryPhotos[index];

    // ✅ Si photo distante, la marquer pour suppression (pas supprimer tout de suite)
    if (photo.source == PhotoSource.remote) {
      _deletedPhotoIds.add(photo.id);
      debugPrint('🗑️ Photo galerie marquée pour suppression: ${photo.id}');
    }

    // Retirer de la liste
    _galleryPhotos.removeAt(index);

    // Réordonner
    for (var i = 0; i < _galleryPhotos.length; i++) {
      _galleryPhotos[i] = _galleryPhotos[i].copyWith(displayOrder: i);
    }

    _updateCompletionFields();
  }

  /// ✅ SAUVEGARDE INTELLIGENTE : Upload nouvelles + Supprimer anciennes
  Future<bool> saveProfile({bool isSkipped = false}) async {
    if (_user == null) return false;

    _isLoading = true;
    _errorMessage = null;
    safeNotify();

    try {
      final userId = _user!.userId;

      // ════════════════════════════════════════════════════════
      // 1. SUPPRIMER LES PHOTOS MARQUÉES POUR SUPPRESSION
      // ════════════════════════════════════════════════════════

      // Supprimer l'ancienne photo de profil
      if (_deletedProfilePhotoId != null) {
        debugPrint('🗑️ Suppression ancienne photo de profil...');
        await _deletePhotoFromSupabase(_deletedProfilePhotoId!);
        _deletedProfilePhotoId = null;
      }

      // Supprimer les photos de galerie
      for (final photoId in _deletedPhotoIds) {
        debugPrint('🗑️ Suppression photo galerie: $photoId');
        await _deletePhotoFromSupabase(photoId);
      }
      _deletedPhotoIds.clear();

      // ════════════════════════════════════════════════════════
      // 2. UPLOAD SEULEMENT LES NOUVELLES PHOTOS (LOCAL)
      // ════════════════════════════════════════════════════════

      // Photo de profil
      if (_profilePhoto != null && _profilePhoto!.needsUpload) {
        debugPrint('📤 Uploading NEW profile photo...');
        final url = await _imageService.uploadToStorage(
          imageFile: _profilePhoto!.localFile!,
          userId: userId,
          photoType: PhotoType.profile,
        );

        if (url != null) {
          Future<void> _savePhotoEntity({
            required String path, // ⚠️ PAS une URL
            required String type,
            required int displayOrder,
            required bool hasWatermark,
          }) async {
            final photoId = const Uuid().v4();

            // 1️⃣ INSERT SUPABASE (SOURCE DE VÉRITÉ)
            await _supabase.from('photos').insert({
              'id': photoId,
              'user_id': _user!.userId,
              'type': type,
              'remote_path': path,
              'status': 'pending', // 🔐 en attente de modération
              'has_watermark': hasWatermark,
              'display_order': displayOrder,
              'uploaded_at': DateTime.now().toIso8601String(),
            });

            // 2️⃣ CACHE LOCAL (ObjectBox)
            final photoEntity = PhotoEntity(
              photoId: photoId,
              userId: _user!.userId,
              type: type,
              localPath: '',
              remotePath: path,
              status: 'pending',
              hasWatermark: hasWatermark,
              uploadedAt: DateTime.now(),
              displayOrder: displayOrder,
            );

            await _objectBox.savePhoto(photoEntity);

            debugPrint('✅ Photo enregistrée (Supabase + ObjectBox): $photoId');
          }
        }
      } else if (_profilePhoto != null) {
        debugPrint('✅ Profile photo already exists, skip upload');
      }

      // Photos galerie (seulement nouvelles)
      final newGalleryPhotos = _galleryPhotos
          .where((p) => p.needsUpload)
          .toList();

      debugPrint(
        '📤 Uploading ${newGalleryPhotos.length} NEW gallery photos...',
      );

      for (var photo in newGalleryPhotos) {
        final url = await _imageService.uploadToStorage(
          imageFile: photo.localFile!,
          userId: userId,
          photoType: PhotoType.gallery,
        );

        if (url != null) {
          await _savePhotoEntity(
            url: url,
            type: 'gallery',
            displayOrder: photo.displayOrder,
            hasWatermark: false,
          );
        }
      }

      // ════════════════════════════════════════════════════════
      // 3. MISE À JOUR DU PROFIL
      // ════════════════════════════════════════════════════════
      final finalCompletion = completionPercentage;
      final isProfileComplete = !isSkipped && finalCompletion >= 80;

      debugPrint('📊 Completion: $finalCompletion%');
      debugPrint('📊 Profile complete: $isProfileComplete');

      final updateData = {
        'full_name': _user!.fullName,
        'date_of_birth': _user!.dateOfBirth?.toIso8601String(),
        'gender': _user!.gender,
        'looking_for': _user!.lookingFor,
        'bio': _user!.bio,
        'city': _user!.city,
        'country': _user!.country,
        'occupation': _user!.occupation,
        'education': _user!.education,
        'height_cm': _user!.heightCm,
        'relationship_status': _user!.relationshipStatus,
        'interests': _user!.interests,
        'social_links': _user!.socialLinks.map((e) => e.toJson()).toList(),
        'profile_completed': isProfileComplete,
        'completion_percentage': finalCompletion,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('profiles').update(updateData).eq('id', userId);
      debugPrint('✅ Supabase updated');

      // ════════════════════════════════════════════════════════
      // 4. MISE À JOUR LOCALE
      // ════════════════════════════════════════════════════════
      _user = _user!
        ..profileCompleted = isProfileComplete
        ..completionPercentage = finalCompletion
        ..updatedAt = DateTime.now();

      await _objectBox.saveUser(_user!);
      debugPrint('✅ ObjectBox updated');

      _isLoading = false;
      safeNotify();
      return true;
    } catch (e, stack) {
      debugPrint('❌ Save profile error: $e');
      debugPrint('Stack: $stack');
      _errorMessage = 'Erreur de sauvegarde: $e';
      _isLoading = false;
      safeNotify();
      return false;
    }
  }

  /// ✅ NOUVEAU : Supprimer une photo de Supabase (Storage + DB)
  Future<void> _deletePhotoFromSupabase(String photoId) async {
    try {
      // 1. Récupérer l'URL de la photo depuis la DB
      final photoData = await _supabase
          .from('photos')
          .select('remote_path')
          .eq('id', photoId)
          .maybeSingle();

      if (photoData != null && photoData['remote_path'] != null) {
        final url = photoData['remote_path'] as String;

        // 2. Supprimer du Storage
        final deleted = await _imageService.deleteFromStorage(url: url);
        if (deleted) {
          debugPrint('✅ Photo supprimée du Storage: $photoId');
        }
      }

      // 3. Supprimer de la table photos
      await _supabase.from('photos').delete().eq('id', photoId);
      debugPrint('✅ Photo supprimée de la DB: $photoId');
    } catch (e) {
      debugPrint('❌ Error deleting photo $photoId: $e');
      // Ne pas bloquer le processus même si la suppression échoue
    }
  }

  Future<void> _savePhotoEntity({
    required String url,
    required String type,
    required int displayOrder,
    required bool hasWatermark,
  }) async {
    final photoEntity = PhotoEntity(
      photoId: const Uuid().v4(),
      userId: _user!.userId,
      type: type,
      localPath: '',
      remotePath: url,
      status: 'pending',
      hasWatermark: hasWatermark,
      uploadedAt: DateTime.now(),
      displayOrder: displayOrder,
    );

    await _objectBox.savePhoto(photoEntity);
  }

  void reset() {
    _profilePhoto = null;
    _galleryPhotos.clear();
    _deletedPhotoIds.clear();
    _deletedProfilePhotoId = null;
    _errorMessage = null;
    safeNotify();
  }

  // ✅ FIX : Appeler notifyListeners(), PAS safeNotify()
  void safeNotify() {
    // Vérifier si on est dans une phase critique du scheduler
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      debugPrint('⚠️ safeNotify: deferring notification (build phase)');

      // Différer après le build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('✅ safeNotify: executing deferred notification');
        notifyListeners();
      });
    } else {
      debugPrint('✅ safeNotify: notifying immediately');
      notifyListeners();
    }
  }
}
