// lib/providers/profile_completion_provider.dart - FIX ENCODING

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../objectbox_entities_complete.dart';
import '../services/image_service.dart';
import '../services/services.dart';

class ProfileCompletionProvider extends ChangeNotifier {
  final SupabaseClient _supabase;
  final ObjectBoxService _objectBox;
  final ImageService _imageService;

  UserEntity? _user;
  List<File> _selectedPhotos = [];
  List<PhotoEntity> _photoEntities = [];
  bool _isLoading = false;
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
    'photos': false,
  };

  ProfileCompletionProvider(
    this._supabase,
    this._objectBox,
    this._imageService,
  );

  int get completionPercentage {
    final completed = _completionFields.values.where((v) => v).length;
    return ((completed / _completionFields.length) * 100).round();
  }

  bool get isComplete => completionPercentage == 100;
  bool get hasMinimumPhotos => _selectedPhotos.length >= 3;
  List<File> get selectedPhotos => _selectedPhotos;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserEntity? get user => _user;
  ImageService get imageService => _imageService;

  // FIX: Décoder correctement les listes
  List<String> _decodeList(String json) {
    if (json.isEmpty || json == '[]') return [];

    try {
      // Si c'est déjà du JSON valide
      return List<String>.from(jsonDecode(json));
    } catch (e) {
      // Sinon c'est encodé en URI (legacy)
      try {
        final decoded = Uri.decodeComponent(json);
        return decoded.split(',').where((s) => s.isNotEmpty).toList();
      } catch (e2) {
        debugPrint('❌ Error decoding list: $json - $e2');
        return [];
      }
    }
  }

  // Initialisation silencieuse (sans notifyListeners)
  void initialize(UserEntity user) {
    _user = user;
    _updateCompletionFields();
    // PAS de notifyListeners() ici
  }

  // Initialisation avec notification différée (pour les cas où c'est nécessaire)
  void initializeWithNotification(UserEntity user) {
    _user = user;
    _updateCompletionFields();

    // Notification différée après le build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
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
    _completionFields['photos'] = _user!.photos.length >= 3;

    // PAS de notifyListeners() ici non plus
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
      case 'instagram_handle':
        _user = _user!..instagramHandle = value;
        break;
      case 'spotify_anthem':
        _user = _user!..spotifyAnthem = value;
        break;
    }

    _updateCompletionFields();
    notifyListeners();
  }

  Future<void> addPhotosFromCamera() async {
    final photo = await _imageService.captureFromCamera();
    if (photo != null) {
      _selectedPhotos.add(photo);
      _updateCompletionFields();
      notifyListeners();
    }
  }

  Future<void> addPhotosFromGallery() async {
    final photos = await _imageService.pickMultipleFromGallery(
      maxImages: 6 - _selectedPhotos.length,
    );
    _selectedPhotos.addAll(photos);
    _updateCompletionFields();
    notifyListeners();
  }

  void removePhoto(int index) {
    if (index < _selectedPhotos.length) {
      _selectedPhotos.removeAt(index);
      _updateCompletionFields();
      notifyListeners();
    }
  }

  // lib/providers/profile_completion_provider.dart - SECTION À REMPLACER

  // ✅ FIX: saveProfile avec logs et vérification
  Future<bool> saveProfile({bool isSkipped = false}) async {
    if (_user == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final uploadedPhotos = <String>[];

      // Upload des photos
      for (var i = 0; i < _selectedPhotos.length; i++) {
        debugPrint('📤 Uploading photo ${i + 1}/${_selectedPhotos.length}...');

        final url = await _imageService.uploadToStorage(
          imageFile: _selectedPhotos[i],
          userId: _user!.userId,
          bucket: 'profiles',
          folder: 'gallery',
        );

        if (url != null) {
          uploadedPhotos.add(url);
          debugPrint('✅ Photo ${i + 1} uploaded');

          // Sauvegarder dans ObjectBox
          final photoEntity = PhotoEntity(
            photoId: const Uuid().v4(),
            userId: _user!.userId,
            localPath: _selectedPhotos[i].path,
            remotePath: url,
            status: 'pending',
            hasWatermark: true,
            uploadedAt: DateTime.now(),
            isProfilePhoto: i == 0,
            displayOrder: i,
          );

          await _objectBox.savePhoto(photoEntity);
          _photoEntities.add(photoEntity);
        } else {
          debugPrint('❌ Failed to upload photo ${i + 1}');
          _errorMessage = 'Erreur d\'upload des photos';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // ✅ Calculer le pourcentage final
      final finalCompletion = completionPercentage;
      final isProfileComplete = !isSkipped && finalCompletion == 100;

      debugPrint('📊 Completion percentage: $finalCompletion%');
      debugPrint('📊 Profile will be marked as complete: $isProfileComplete');

      // ✅ FIX: Mise à jour du profil dans Supabase
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
        'instagram_handle': _user!.instagramHandle,
        'spotify_anthem': _user!.spotifyAnthem,
        'photos': uploadedPhotos,
        'photo_url': _user!.photoUrl, // ✅ AJOUT: photo de profil
        'profile_completed': isProfileComplete,
        'completion_percentage': finalCompletion,
        'updated_at': DateTime.now().toIso8601String(),
      };

      debugPrint(
        '📤 Updating Supabase with profile_completed: $isProfileComplete',
      );

      await _supabase
          .from('profiles')
          .update(updateData)
          .eq('id', _user!.userId);

      debugPrint('✅ Supabase updated successfully');

      // ✅ Mise à jour locale
      _user = _user!
        ..photos = uploadedPhotos
        ..profileCompleted =
            isProfileComplete // ✅ IMPORTANT
        ..completionPercentage = finalCompletion
        ..updatedAt = DateTime.now();

      debugPrint('💾 Saving to ObjectBox...');
      await _objectBox.saveUser(_user!);
      debugPrint('✅ ObjectBox updated');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Save profile error: $e');
      debugPrint('Stack trace: $stackTrace');

      _errorMessage = 'Erreur lors de la sauvegarde : ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> scheduleSkipReminder() async {
    debugPrint('Skip reminder scheduled for 24h');
  }

  void reset() {
    _selectedPhotos.clear();
    _photoEntities.clear();
    _errorMessage = null;
    notifyListeners();
  }
}
