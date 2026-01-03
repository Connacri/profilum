// lib/core/providers/profile_completion_provider.dart
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

  // Champs obligatoires pour complétion
  Map<String, bool> _completionFields = {};

  ProfileCompletionProvider(
    this._supabase,
    this._objectBox,
    this._imageService,
  );

  int get completionPercentage {
    if (_completionFields.isEmpty) return 0;
    final completed = _completionFields.values.where((v) => v).length;
    return ((completed / _completionFields.length) * 100).round();
  }

  bool get isComplete => completionPercentage == 100;
  bool get hasMinimumPhotos => _selectedPhotos.length >= 3;
  List<File> get selectedPhotos => _selectedPhotos;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserEntity? get user => _user;

  // CORRECTION: Helpers moved outside initializer
  List<String> _decodeList(String json) =>
      json.isEmpty ? [] : List<String>.from(jsonDecode(json));

  String _encodeList(List<String> list) => jsonEncode(list);

  void initialize(UserEntity user) {
    _user = user;
    _initializeCompletionFields();
    _updateCompletionFields();
    notifyListeners();
  }

  void _initializeCompletionFields() {
    _completionFields = {
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
  }

  void _updateCompletionFields() {
    if (_user == null) return;

    final photos = _decodeList(_user!.photosJson);
    final interests = _decodeList(_user!.interestsJson);

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
    _completionFields['interests'] = interests.length >= 3;
    _completionFields['photos'] =
        photos.length >= 3 || _selectedPhotos.length >= 3;
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

  // CORRECTION: Logique corrigée
  Future<bool> saveProfile({bool isSkipped = false}) async {
    if (_user == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Upload photos nouvelles
      final uploadedUrls = <String>[];
      for (var i = 0; i < _selectedPhotos.length; i++) {
        final url = await _imageService.uploadToStorage(
          imageFile: _selectedPhotos[i],
          userId: _user!.userId,
          bucket: 'profiles',
          folder: 'gallery',
        );

        if (url != null) {
          uploadedUrls.add(url);

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
        }
      }

      // CORRECTION: Combine photos existantes + nouvelles
      final existingPhotos = _decodeList(_user!.photosJson);
      final allPhotos = [...existingPhotos, ...uploadedUrls];

      // Mise à jour Supabase
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
        'photos': allPhotos,
        'profile_completed': !isSkipped && isComplete,
        'completion_percentage': completionPercentage,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('profiles')
          .update(updateData)
          .eq('id', _user!.userId);

      // Mise à jour locale
      _user = _user!
        ..photos = allPhotos
        ..profileCompleted = !isSkipped && isComplete
        ..completionPercentage = completionPercentage
        ..updatedAt = DateTime.now();

      await _objectBox.saveUser(_user!);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur sauvegarde: $e';
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
