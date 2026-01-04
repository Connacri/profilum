// lib/providers/profile_completion_provider.dart - REFACTORISÉ

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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

  // ✅ NOUVEAU: Séparation des 3 types de photos
  File? _profilePhoto; // 1 photo de profil
  List<File> _coverPhotos = []; // 3 covers max
  List<File> _galleryPhotos = []; // 6 gallery max

  bool _isLoading = false;
  String? _errorMessage;

  // Champs de completion (13 champs au total)
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
  String? get errorMessage => _errorMessage;
  UserEntity? get user => _user;
  ImageService get imageService => _imageService;

  // ✅ NOUVEAU: Getters pour les photos
  File? get profilePhoto => _profilePhoto;
  List<File> get coverPhotos => _coverPhotos;
  List<File> get galleryPhotos => _galleryPhotos;

  bool get hasProfilePhoto => _profilePhoto != null;
  bool get hasMinCovers => _coverPhotos.isNotEmpty;
  bool get hasMinGallery => _galleryPhotos.length >= 3;

  /// Initialisation silencieuse (sans notification)
  void initialize(UserEntity user) {
    _user = user;
    _updateCompletionFields();
  }

  // ✅ Calcul async avec debounce
  void _scheduleCompletionCalculation() {
    _calculationTimer?.cancel();
    _calculationTimer = Timer(const Duration(milliseconds: 300), () {
      _updateCompletionFieldsAsync();
    });
  }

  Future<void> _updateCompletionFieldsAsync() async {
    if (_user == null) return;

    // ✅ Calcul en isolate si computation lourde
    final result = await compute(_calculateCompletion, _user!);

    _completionFields.addAll(result);
    notifyListeners();
  }

  // ✅ Fonction pure pour isolate
  static Map<String, bool> _calculateCompletion(UserEntity user) {
    return {
      'full_name': user.fullName?.isNotEmpty ?? false,
      'date_of_birth': user.dateOfBirth != null,
      'gender': user.gender?.isNotEmpty ?? false,
      'looking_for': user.lookingFor?.isNotEmpty ?? false,
      'bio': (user.bio?.length ?? 0) >= 50,
      'city': user.city?.isNotEmpty ?? false,
      'country': user.country?.isNotEmpty ?? false,
      'occupation': user.occupation?.isNotEmpty ?? false,
      'education': user.education?.isNotEmpty ?? false,
      'height_cm': user.heightCm != null,
      'relationship_status': user.relationshipStatus?.isNotEmpty ?? false,
      'interests': user.interests.length >= 3,
      'social_links': user.socialLinks.isNotEmpty,
    };
  }

  /// Mise à jour des champs de complétion
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
  }

  /// Mettre à jour un champ du profil
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

    // _updateCompletionFields();
    _scheduleCompletionCalculation(); // ✅ Au lieu de _updateCompletionFields()
    notifyListeners();
  }

  /// ✅ NOUVEAU: Ajouter une photo de profil
  Future<void> setProfilePhoto({required bool fromCamera}) async {
    final photo = fromCamera
        ? await _imageService.captureFromCamera()
        : await _imageService.pickFromGallery();

    if (photo != null) {
      _profilePhoto = photo;
      notifyListeners();
    }
  }

  /// ✅ NOUVEAU: Supprimer la photo de profil
  void removeProfilePhoto() {
    _profilePhoto = null;
    notifyListeners();
  }

  /// ✅ NOUVEAU: Ajouter des covers (max 3)
  Future<void> addCoverPhotos({required bool fromCamera}) async {
    if (_coverPhotos.length >= 3) {
      _errorMessage = 'Maximum 3 photos de couverture';
      notifyListeners();
      return;
    }

    if (fromCamera) {
      final photo = await _imageService.captureFromCamera();
      if (photo != null) {
        _coverPhotos.add(photo);
        notifyListeners();
      }
    } else {
      final remainingSlots = 3 - _coverPhotos.length;
      final photos = await _imageService.pickMultipleFromGallery(
        maxImages: remainingSlots,
      );
      _coverPhotos.addAll(photos);
      notifyListeners();
    }
  }

  /// ✅ NOUVEAU: Supprimer une cover
  void removeCoverPhoto(int index) {
    if (index < _coverPhotos.length) {
      _coverPhotos.removeAt(index);
      notifyListeners();
    }
  }

  /// ✅ NOUVEAU: Ajouter des photos de galerie (max 6)
  Future<void> addGalleryPhotos({required bool fromCamera}) async {
    if (_galleryPhotos.length >= 6) {
      _errorMessage = 'Maximum 6 photos de galerie';
      notifyListeners();
      return;
    }

    if (fromCamera) {
      final photo = await _imageService.captureFromCamera();
      if (photo != null) {
        _galleryPhotos.add(photo);
        notifyListeners();
      }
    } else {
      final remainingSlots = 6 - _galleryPhotos.length;
      final photos = await _imageService.pickMultipleFromGallery(
        maxImages: remainingSlots,
      );
      _galleryPhotos.addAll(photos);
      notifyListeners();
    }
  }

  /// ✅ NOUVEAU: Supprimer une photo de galerie
  void removeGalleryPhoto(int index) {
    if (index < _galleryPhotos.length) {
      _galleryPhotos.removeAt(index);
      notifyListeners();
    }
  }

  /// ✅ NOUVEAU: Sauvegarder le profil complet
  Future<bool> saveProfile({bool isSkipped = false}) async {
    if (_user == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // ════════════════════════════════════════════════════════
      // 1. UPLOAD PHOTO DE PROFIL (optionnel)
      // ════════════════════════════════════════════════════════
      String? profilePhotoUrl;
      if (_profilePhoto != null) {
        debugPrint('📤 Uploading profile photo...');
        profilePhotoUrl = await _imageService.uploadToStorage(
          imageFile: _profilePhoto!,
          userId: _user!.userId,
          photoType: PhotoType.profile,
        );

        if (profilePhotoUrl != null) {
          debugPrint('✅ Profile photo uploaded');
          // Créer l'entité PhotoEntity
          await _savePhotoEntity(
            url: profilePhotoUrl,
            type: 'profile',
            displayOrder: 0,
            hasWatermark: true, // Selon la source
          );
        }
      }

      // ════════════════════════════════════════════════════════
      // 2. UPLOAD COVER PHOTOS (optionnel, max 3)
      // ════════════════════════════════════════════════════════
      for (var i = 0; i < _coverPhotos.length; i++) {
        debugPrint('📤 Uploading cover photo ${i + 1}...');
        final url = await _imageService.uploadToStorage(
          imageFile: _coverPhotos[i],
          userId: _user!.userId,
          photoType: PhotoType.cover,
        );

        if (url != null) {
          await _savePhotoEntity(
            url: url,
            type: 'cover',
            displayOrder: i,
            hasWatermark: false,
          );
        }
      }

      // ════════════════════════════════════════════════════════
      // 3. UPLOAD GALLERY PHOTOS (optionnel, max 6)
      // ════════════════════════════════════════════════════════
      for (var i = 0; i < _galleryPhotos.length; i++) {
        debugPrint('📤 Uploading gallery photo ${i + 1}...');
        final url = await _imageService.uploadToStorage(
          imageFile: _galleryPhotos[i],
          userId: _user!.userId,
          photoType: PhotoType.gallery,
        );

        if (url != null) {
          await _savePhotoEntity(
            url: url,
            type: 'gallery',
            displayOrder: i,
            hasWatermark: false,
          );
        }
      }

      // ════════════════════════════════════════════════════════
      // 4. MISE À JOUR DU PROFIL DANS SUPABASE
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

      await _supabase
          .from('profiles')
          .update(updateData)
          .eq('id', _user!.userId);

      debugPrint('✅ Supabase updated');

      // ════════════════════════════════════════════════════════
      // 5. MISE À JOUR LOCALE (OBJECTBOX)
      // ════════════════════════════════════════════════════════
      _user = _user!
        ..profileCompleted = isProfileComplete
        ..completionPercentage = finalCompletion
        ..updatedAt = DateTime.now();

      await _objectBox.saveUser(_user!);
      debugPrint('✅ ObjectBox updated');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e, stack) {
      debugPrint('❌ Save profile error: $e');
      debugPrint('Stack: $stack');
      _errorMessage = 'Erreur de sauvegarde: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Helper: Sauvegarder une PhotoEntity
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
      localPath: '', // Pas nécessaire après upload
      remotePath: url,
      status: 'pending', // ✅ Toutes les photos sont modérées
      hasWatermark: hasWatermark,
      uploadedAt: DateTime.now(),
      displayOrder: displayOrder,
    );

    await _objectBox.savePhoto(photoEntity);
  }

  /// Reset du provider
  void reset() {
    _profilePhoto = null;
    _coverPhotos.clear();
    _galleryPhotos.clear();
    _errorMessage = null;
    notifyListeners();
  }
}
