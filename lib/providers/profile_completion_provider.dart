import 'dart:async';

import 'package:flutter/foundation.dart';
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

  // ✅ NOUVEAU : Système unifié de photos
  PhotoItem? _profilePhoto;
  List<PhotoItem> _galleryPhotos = [];

  bool _isLoading = false;
  bool _isLoadingPhotos = false;
  String? _errorMessage;

  // Champs de completion
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
  bool get isLoadingPhotos => _isLoadingPhotos;
  String? get errorMessage => _errorMessage;
  UserEntity? get user => _user;
  ImageService get imageService => _imageService;

  PhotoItem? get profilePhoto => _profilePhoto;
  List<PhotoItem> get galleryPhotos => _galleryPhotos;

  bool get hasProfilePhoto => _profilePhoto != null;
  bool get hasMinGallery => _galleryPhotos.length >= 3;

  /// ✅ Initialisation avec chargement des photos
  Future<void> initialize(UserEntity user) async {
    _user = user;
    _updateCompletionFields();

    // ✅ Charger les photos existantes
    await _loadExistingPhotos();
  }

  /// ✅ NOUVEAU : Charger les photos depuis ObjectBox
  Future<void> _loadExistingPhotos() async {
    if (_user == null) return;

    _isLoadingPhotos = true;
    notifyListeners();

    try {
      final photos = await _objectBox.getUserPhotos(_user!.userId);
      final approved = photos.where((p) => p.status == 'approved').toList();
      approved.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      // Photo de profil
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
        );
      }

      // Photos galerie
      _galleryPhotos = approved
          .where((p) => p.type == 'gallery' && p.remotePath != null)
          .map(
            (p) => PhotoItem(
              id: p.photoId,
              source: PhotoSource.remote,
              remotePath: p.remotePath,
              displayOrder: p.displayOrder,
              type: 'gallery',
            ),
          )
          .toList();

      debugPrint('✅ Loaded ${_galleryPhotos.length} existing photos');
    } catch (e) {
      debugPrint('❌ Error loading photos: $e');
    } finally {
      _isLoadingPhotos = false;
      notifyListeners();
    }
  }

  void _scheduleCompletionCalculation() {
    _calculationTimer?.cancel();
    _calculationTimer = Timer(const Duration(milliseconds: 300), () {
      _updateCompletionFieldsAsync();
    });
  }

  Future<void> _updateCompletionFieldsAsync() async {
    if (_user == null) return;
    final result = await compute(_calculateCompletion, _user!);
    _completionFields.addAll(result);
    notifyListeners();
  }

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

    _scheduleCompletionCalculation();
    notifyListeners();
  }

  /// ✅ NOUVEAU : Ajouter/Remplacer photo de profil
  Future<void> setProfilePhoto({required bool fromCamera}) async {
    final photo = fromCamera
        ? await _imageService.captureFromCamera()
        : await _imageService.pickFromGallery();

    if (photo != null) {
      _profilePhoto = PhotoItem(
        id: const Uuid().v4(),
        source: PhotoSource.local,
        localFile: photo,
        displayOrder: 0,
        type: 'profile',
        isModified: true,
      );
      notifyListeners();
    }
  }

  /// ✅ Supprimer photo de profil
  void removeProfilePhoto() {
    _profilePhoto = null;
    notifyListeners();
  }

  /// ✅ NOUVEAU : Ajouter photos galerie
  Future<void> addGalleryPhotos({required bool fromCamera}) async {
    if (_galleryPhotos.length >= 6) {
      _errorMessage = 'Maximum 6 photos de galerie';
      notifyListeners();
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
        notifyListeners();
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
      notifyListeners();
    }
  }

  /// ✅ NOUVEAU : Supprimer photo galerie
  Future<void> removeGalleryPhoto(int index) async {
    if (index >= _galleryPhotos.length) return;

    final photo = _galleryPhotos[index];

    // Si photo distante, la supprimer de Supabase
    if (photo.source == PhotoSource.remote && photo.remotePath != null) {
      await _imageService.deleteFromStorage(url: photo.remotePath!);

      // Supprimer de la table photos
      try {
        await _supabase.from('photos').delete().eq('id', photo.id);
      } catch (e) {
        debugPrint('❌ Error deleting photo from DB: $e');
      }
    }

    _galleryPhotos.removeAt(index);

    // Réordonner
    for (var i = 0; i < _galleryPhotos.length; i++) {
      _galleryPhotos[i] = _galleryPhotos[i].copyWith(displayOrder: i);
    }

    notifyListeners();
  }

  /// ✅ SAUVEGARDE INTELLIGENTE (upload seulement nouvelles photos)
  Future<bool> saveProfile({bool isSkipped = false}) async {
    if (_user == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _user!.userId;

      // ════════════════════════════════════════════════════════
      // 1. UPLOAD SEULEMENT LES NOUVELLES PHOTOS
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
          await _savePhotoEntity(
            url: url,
            type: 'profile',
            displayOrder: 0,
            hasWatermark: true,
          );
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

      for (var i = 0; i < newGalleryPhotos.length; i++) {
        final photo = newGalleryPhotos[i];
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
      // 2. MISE À JOUR DU PROFIL
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

      try {
        await _supabase.from('profiles').update(updateData).eq('id', userId);

        debugPrint('✅ Supabase updated');
      } on PostgrestException catch (e) {
        if (e.code == '42883' &&
            e.message.contains('calculate_profile_completion')) {
          debugPrint('⚠️ Trigger SQL error ignored');
        } else {
          rethrow;
        }
      }

      // ════════════════════════════════════════════════════════
      // 3. MISE À JOUR LOCALE
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
    _errorMessage = null;
    notifyListeners();
  }
}
