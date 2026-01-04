// lib/providers/auth_provider.dart - FIX pour la navigation après skip

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../objectbox_entities_complete.dart';
import '../services/services.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  emailVerificationPending,
  profileIncomplete, // Profil incomplet mais peut skip
  loading,
  error,
  accountDeleted,
}

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase;
  final ObjectBoxService _objectBox;

  AuthStatus _status = AuthStatus.initial;
  UserEntity? _currentUser;
  String? _errorMessage;
  Timer? _sessionTimer;
  Timer? _heartbeatTimer;
  StreamSubscription? _authSubscription;

  static const Duration _sessionDuration = Duration(days: 30);
  static const Duration _refreshBuffer = Duration(hours: 1);
  static const Duration _heartbeatInterval = Duration(minutes: 5);

  // Clés SharedPreferences pour le skip
  static const String _keyProfileSkipped = 'profile_completion_skipped';
  static const String _keySkippedAt = 'profile_skipped_at';
  static const String _keyLastReminder = 'last_completion_reminder';

  AuthProvider(this._supabase, this._objectBox) {
    _initAuth();
  }

  // Getters
  AuthStatus get status => _status;
  UserEntity? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated ||
      _status == AuthStatus.profileIncomplete;
  bool get canAccessApp => isAuthenticated;

  // Vérifier si l'user a skip la completion
  Future<bool> hasSkippedCompletion() async {
    if (_currentUser == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${_keyProfileSkipped}_${_currentUser!.userId}') ??
        false;
  }

  // Obtenir la date du skip
  Future<DateTime?> getSkippedDate() async {
    if (_currentUser == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('${_keySkippedAt}_${_currentUser!.userId}');
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  // Vérifier si besoin d'un rappel
  Future<bool> needsCompletionReminder() async {
    if (_currentUser == null || _currentUser!.profileCompleted) return false;

    final hasSkipped = await hasSkippedCompletion();
    if (!hasSkipped) return false;

    final prefs = await SharedPreferences.getInstance();
    final skippedAt = await getSkippedDate();
    if (skippedAt == null) return false;

    final lastReminder = prefs.getInt(
      '${_keyLastReminder}_${_currentUser!.userId}',
    );
    final timeSinceSkip = DateTime.now().difference(skippedAt);

    if (lastReminder == null && timeSinceSkip.inHours >= 24) {
      return true;
    }

    if (lastReminder != null) {
      final lastReminderDate = DateTime.fromMillisecondsSinceEpoch(
        lastReminder,
      );
      final timeSinceLastReminder = DateTime.now().difference(lastReminderDate);
      return timeSinceLastReminder.inDays >= 7;
    }

    return false;
  }

  // ✅ Méthode reloadCurrentUser (à ajouter)
  Future<void> reloadCurrentUser() async {
    if (_currentUser == null) {
      debugPrint('❌ reloadCurrentUser: No current user');
      return;
    }

    final userId = _currentUser!.userId;
    debugPrint('🔵 Reloading user: $userId');

    try {
      await _loadUserFromSupabase(userId);

      debugPrint('✅ User reloaded successfully');
      debugPrint('   Profile completed: ${_currentUser?.profileCompleted}');
      debugPrint('   Completion %: ${_currentUser?.completionPercentage}');
      debugPrint('   New status: $_status');
    } catch (e, stack) {
      debugPrint('❌ reloadCurrentUser error: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  // ✅ Version améliorée de _loadUserFromSupabase (remplace l'existante)
  Future<void> _loadUserFromSupabase(String userId) async {
    try {
      debugPrint('🔵 Loading profile for userId: $userId');

      // 1️⃣ Charger le profil
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      if (data == null) {
        debugPrint('❌ No profile found for userId: $userId');
        await _createMinimalUserProfile(userId, 'email@inconnu.com', null);
        _errorMessage = 'Profil créé. Veuillez compléter vos informations.';
        _status = AuthStatus.profileIncomplete;
        notifyListeners();
        return;
      }

      debugPrint('✅ Profile data loaded from Supabase');
      _currentUser = _mapToUserEntity(data);

      // 2️⃣ ✅ NOUVEAU: Charger les photos depuis la table `photos`
      await _loadUserPhotos(userId);

      debugPrint('💾 Saving to ObjectBox...');
      await _objectBox.saveUser(_currentUser!);
      debugPrint('✅ Saved to ObjectBox successfully');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_active_session', true);

      debugPrint('🔵 Determining auth status...');
      await _determineAuthStatus();

      debugPrint('✅ Final status: $_status');
    } catch (e, stack) {
      debugPrint('❌ Load user error: $e');
      debugPrint('Stack: $stack');
      _errorMessage = 'Erreur de chargement du profil: $e';
      _status = AuthStatus.error;
      notifyListeners();
      rethrow;
    }
  }

  // 🆕 NOUVELLE MÉTHODE: Charger les photos depuis la table photos
  Future<void> _loadUserPhotos(String userId) async {
    try {
      final photos = await _supabase
          .from('photos')
          .select()
          .eq('user_id', userId)
          .eq('status', 'approved') // ✅ Seulement les photos approuvées
          .order('display_order', ascending: true);

      debugPrint('📸 Loaded ${photos.length} photos');

      // Sauvegarder chaque photo dans ObjectBox
      for (final photoData in photos) {
        final photoEntity = PhotoEntity(
          photoId: photoData['id'],
          userId: userId,
          type: photoData['type'],
          localPath: '', // Pas de path local pour les photos distantes
          remotePath: photoData['remote_path'],
          status: photoData['status'],
          hasWatermark: photoData['has_watermark'] ?? false,
          uploadedAt: DateTime.parse(photoData['uploaded_at']),
          moderatedAt: photoData['moderated_at'] != null
              ? DateTime.parse(photoData['moderated_at'])
              : null,
          moderatorId: photoData['moderator_id'],
          rejectionReason: photoData['rejection_reason'],
          displayOrder: photoData['display_order'],
        );

        await _objectBox.savePhoto(photoEntity);
      }

      debugPrint('✅ Photos saved to ObjectBox');
    } catch (e) {
      debugPrint('⚠️ Error loading photos: $e');
      // Ne pas bloquer le chargement du profil si les photos échouent
    }
  }

  // ✅ Version améliorée de _determineAuthStatus (remplace l'existante)
  Future<void> _determineAuthStatus() async {
    debugPrint('════════════════════════════════════════');
    debugPrint('🔍 DETERMINING AUTH STATUS');
    debugPrint('════════════════════════════════════════');

    if (_currentUser == null) {
      _status = AuthStatus.unauthenticated;
      debugPrint('❌ No user → unauthenticated');
    } else {
      debugPrint('✅ User found:');
      debugPrint('   - Email: ${_currentUser!.email}');
      debugPrint('   - Name: ${_currentUser!.fullName}');
      debugPrint('   - Profile completed: ${_currentUser!.profileCompleted}');
      debugPrint('   - Completion %: ${_currentUser!.completionPercentage}%');

      if (_currentUser!.profileCompleted) {
        _status = AuthStatus.authenticated;
        debugPrint('✅ Profile complete → authenticated');
      } else {
        // Profil incomplet : vérifier si skip
        final hasSkipped = await hasSkippedCompletion();
        debugPrint('   - Has skipped: $hasSkipped');

        if (hasSkipped) {
          final skippedDate = await getSkippedDate();
          debugPrint('   - Skipped at: $skippedDate');

          _status = AuthStatus.authenticated; // Skip = accès autorisé
          debugPrint('✅ Profile incomplete but skipped → authenticated');
        } else {
          _status =
              AuthStatus.profileIncomplete; // Pas skip = proposer completion
          debugPrint(
            '⚠️ Profile incomplete and not skipped → profileIncomplete',
          );
        }
      }
    }

    debugPrint('════════════════════════════════════════');
    debugPrint('📊 FINAL STATUS: $_status');
    debugPrint('════════════════════════════════════════');

    notifyListeners();
  }

  // La méthode _loadUserFromSupabase existe déjà, mais voici sa version
  // avec des logs supplémentaires si tu veux la remplacer :

  Future<void> _initAuth() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSession = prefs.getBool('has_active_session') ?? false;

      if (hasSession) {
        final session = _supabase.auth.currentSession;
        if (session != null) {
          await _loadUserFromLocal(session.user.id);
          await _validateAndRefreshSession();
          _startSessionManagement();
        } else {
          await _clearLocalSession();
          _status = AuthStatus.unauthenticated;
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _errorMessage = 'Erreur d\'initialisation: $e';
      _status = AuthStatus.error;
      debugPrint('Init auth error: $e');
    }

    notifyListeners();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        _handleSignIn(session);
      } else if (event == AuthChangeEvent.signedOut) {
        _handleSignOut();
      } else if (event == AuthChangeEvent.tokenRefreshed && session != null) {
        _handleTokenRefresh(session);
      }
    });
  }

  Future<void> _handleSignIn(Session session) async {
    await _loadUserFromSupabase(session.user.id);
    _startSessionManagement();
  }

  void _handleSignOut() async {
    await _clearLocalSession();
    _stopSessionManagement();
    _status = AuthStatus.unauthenticated;
    _currentUser = null;
    notifyListeners();
  }

  Future<void> _handleTokenRefresh(Session session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', session.accessToken);
    final expiresAt =
        session.expiresAt ??
        DateTime.now().add(_sessionDuration).millisecondsSinceEpoch ~/ 1000;
    await prefs.setInt('token_expires_at', expiresAt);
  }

  // ===== SIGNUP =====
  Future<bool> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    debugPrint('🔵 SIGNUP START: $email');
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('🔵 Calling Supabase signUp...');
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );

      debugPrint('🔵 Supabase response: ${response.user?.id}');

      if (response.user != null) {
        debugPrint('✅ User created: ${response.user!.id}');

        await Future.delayed(const Duration(seconds: 2));

        debugPrint('🔵 Loading user profile...');
        await _loadUserFromSupabase(response.user!.id);

        _status = response.user!.emailConfirmedAt == null
            ? AuthStatus.emailVerificationPending
            : AuthStatus.profileIncomplete;

        debugPrint('✅ SIGNUP SUCCESS - Status: $_status');
        notifyListeners();
        return true;
      }

      debugPrint('❌ SIGNUP ERROR: No user returned');
      throw Exception('Échec signup');
    } on AuthException catch (e) {
      debugPrint('❌ AUTH EXCEPTION: ${e.message} (${e.statusCode})');
      if (e.message.contains('already')) {
        debugPrint('🔵 Email exists, converting to login...');
        return await signIn(email: email, password: password);
      }
      _errorMessage = _handleAuthError(e);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e, stack) {
      debugPrint('❌ SIGNUP ERROR: $e');
      debugPrint('Stack: $stack');
      _errorMessage = 'Erreur: $e';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> _createMinimalUserProfile(
    String userId,
    String email,
    String? fullName,
  ) async {
    final now = DateTime.now();
    await _supabase.from('profiles').upsert({
      'id': userId,
      'email': email,
      'full_name': fullName ?? '',
      'profile_completed': false,
      'completion_percentage': 0,
      'role': 'user',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  // ===== LOGIN =====
  Future<bool> signIn({required String email, required String password}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _loadUserFromSupabase(response.user!.id);
        _startSessionManagement();
        return true;
      }

      throw Exception('Échec de connexion');
    } on AuthException catch (e) {
      _errorMessage = _handleAuthError(e);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erreur: $e';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  // ===== RESET PASSWORD =====
  Future<bool> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      _errorMessage = 'Erreur: $e';
      return false;
    }
  }

  // ✨ FIX: Méthode pour skipper la completion
  Future<bool> skipProfileCompletion() async {
    if (_currentUser == null) {
      debugPrint('❌ Skip failed: No current user');
      return false;
    }

    try {
      debugPrint('🔵 Starting skip process for user: ${_currentUser!.userId}');

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // Sauvegarder le skip en local
      await prefs.setBool(
        '${_keyProfileSkipped}_${_currentUser!.userId}',
        true,
      );
      await prefs.setInt(
        '${_keySkippedAt}_${_currentUser!.userId}',
        now.millisecondsSinceEpoch,
      );

      debugPrint('✅ Skip saved to SharedPreferences');

      // ✨ FIX: Changer le statut IMMÉDIATEMENT pour débloquer le router
      _status = AuthStatus.authenticated;

      debugPrint('✅ Status changed to: $_status');

      // ✨ FIX: Notifier AVANT le return pour que le router se rebuild
      notifyListeners();

      debugPrint('✅ Listeners notified - router should rebuild now');

      return true;
    } catch (e, stack) {
      debugPrint('❌ Skip error: $e');
      debugPrint('Stack: $stack');
      _errorMessage = 'Erreur lors du skip: $e';
      return false;
    }
  }

  // Marquer qu'un rappel a été envoyé
  Future<void> markReminderSent() async {
    if (_currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '${_keyLastReminder}_${_currentUser!.userId}',
      DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
  }

  // ===== LOGOUT =====
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await _clearLocalSession();
    _stopSessionManagement();
    _status = AuthStatus.unauthenticated;
    _currentUser = null;
    notifyListeners();
  }

  // ===== DELETE ACCOUNT =====
  Future<bool> deleteAccount() async {
    if (_currentUser == null) return false;

    try {
      final userId = _currentUser!.userId;

      await _supabase.from('profiles').delete().eq('id', userId);
      await _objectBox.deleteUser(userId);
      await _clearLocalSession();

      _status = AuthStatus.accountDeleted;
      _currentUser = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur suppression: $e';
      return false;
    }
  }

  // ===== SESSION MANAGEMENT =====
  void _startSessionManagement() {
    _stopSessionManagement();

    _sessionTimer = Timer.periodic(_refreshBuffer, (_) async {
      await _validateAndRefreshSession();
    });

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      await _updateLastActive();
    });
  }

  void _stopSessionManagement() {
    _sessionTimer?.cancel();
    _heartbeatTimer?.cancel();
    _sessionTimer = null;
    _heartbeatTimer = null;
  }

  Future<void> _validateAndRefreshSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        await signOut();
        return;
      }

      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        (session.expiresAt ?? 0) * 1000,
      );

      if (DateTime.now().isAfter(expiresAt.subtract(_refreshBuffer))) {
        await _supabase.auth.refreshSession();
      }
    } catch (e) {
      debugPrint('Session refresh error: $e');
    }
  }

  Future<void> _updateLastActive() async {
    if (_currentUser == null) return;

    try {
      await _supabase
          .from('profiles')
          .update({'last_active_at': DateTime.now().toIso8601String()})
          .eq('id', _currentUser!.userId);
    } catch (e) {
      debugPrint('Last active update error: $e');
    }
  }

  // ===== HELPERS =====

  Future<void> _loadUserFromLocal(String userId) async {
    _currentUser = await _objectBox.getUser(userId);
    await _determineAuthStatus();
  }

  Future<void> _clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();

    // Garder les infos de skip si présentes
    final userId = _currentUser?.userId;
    Map<String, dynamic> skipData = {};

    if (userId != null) {
      final skipped = prefs.getBool('${_keyProfileSkipped}_$userId');
      final skippedAt = prefs.getInt('${_keySkippedAt}_$userId');
      final lastReminder = prefs.getInt('${_keyLastReminder}_$userId');

      if (skipped != null) skipData['skipped'] = skipped;
      if (skippedAt != null) skipData['skippedAt'] = skippedAt;
      if (lastReminder != null) skipData['lastReminder'] = lastReminder;
    }

    await prefs.clear();

    // Restaurer les infos de skip
    if (userId != null && skipData.isNotEmpty) {
      if (skipData['skipped'] != null) {
        await prefs.setBool(
          '${_keyProfileSkipped}_$userId',
          skipData['skipped'],
        );
      }
      if (skipData['skippedAt'] != null) {
        await prefs.setInt('${_keySkippedAt}_$userId', skipData['skippedAt']);
      }
      if (skipData['lastReminder'] != null) {
        await prefs.setInt(
          '${_keyLastReminder}_$userId',
          skipData['lastReminder'],
        );
      }
    }
  }

  UserEntity _mapToUserEntity(Map<String, dynamic> data) {
    String _listToJson(dynamic value) {
      if (value == null) return '[]';
      if (value is List) return jsonEncode(value);
      if (value is String) {
        try {
          jsonDecode(value);
          return value;
        } catch (e) {
          return '[]';
        }
      }
      return '[]';
    }

    return UserEntity(
      userId: data['id'] ?? const Uuid().v4(),
      email: data['email'] ?? '',
      fullName: data['full_name'],
      dateOfBirth: data['date_of_birth'] != null
          ? DateTime.tryParse(data['date_of_birth'])
          : null,
      gender: data['gender'],
      lookingFor: data['looking_for'],
      bio: data['bio'],

      // ✅ SUPPRIMÉ: photosJson, photoUrl, coverUrl
      profileCompleted: data['profile_completed'] ?? false,
      completionPercentage: data['completion_percentage'] ?? 0,
      occupation: data['occupation'],
      interestsJson: _listToJson(data['interests']),
      heightCm: data['height_cm'],
      education: data['education'],
      relationshipStatus: data['relationship_status'],

      // ✅ NOUVEAU: Social links depuis JSONB
      socialLinksJson: data['social_links'] != null
          ? jsonEncode(data['social_links'])
          : '[]',

      city: data['city'],
      country: data['country'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      role: data['role'] ?? 'user',
      lastActiveAt: data['last_active_at'] != null
          ? DateTime.tryParse(data['last_active_at'])
          : null,
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at'] ?? '') ?? DateTime.now(),
      needsSync: false,
    );
  }

  String _handleAuthError(AuthException e) {
    switch (e.statusCode) {
      case '400':
        return 'Email ou mot de passe invalide';
      case '422':
        return 'Email déjà utilisé';
      case '429':
        return 'Trop de tentatives. Réessayez plus tard';
      default:
        return e.message;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _stopSessionManagement();
    super.dispose();
  }
}
