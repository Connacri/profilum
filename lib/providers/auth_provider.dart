// lib/core/providers/auth_provider.dart
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
  profileIncomplete,
  loading,
  error,
  accountDeleted,
}

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase;
  final ObjectBoxService _objectBox;
  //final NetworkService _networkService;

  AuthStatus _status = AuthStatus.initial;
  UserEntity? _currentUser;
  String? _errorMessage;
  Timer? _sessionTimer;
  Timer? _heartbeatTimer;
  StreamSubscription? _authSubscription;

  static const Duration _sessionDuration = Duration(days: 30);
  static const Duration _refreshBuffer = Duration(hours: 1);
  static const Duration _heartbeatInterval = Duration(minutes: 5);

  AuthProvider(this._supabase, this._objectBox /*this._networkService*/) {
    _initAuth();
  }

  AuthStatus get status => _status;
  UserEntity? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get canAccessApp => _currentUser?.profileCompleted ?? false;

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
  // lib/providers/auth_provider.dart - VERSION SIMPLE (le trigger marche maintenant)

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
      // if (!_networkService.isConnected) {
      //   debugPrint('❌ SIGNUP ERROR: No internet');
      //   throw Exception('Aucune connexion Internet');
      // }

      debugPrint('🔵 Calling Supabase signUp...');
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );

      debugPrint('🔵 Supabase response: ${response.user?.id}');

      if (response.user != null) {
        debugPrint('✅ User created: ${response.user!.id}');

        // Attendre que le trigger finisse (max 2 sec)
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
      // if (!_networkService.isConnected) {
      //   final cachedUser = await _objectBox.getUserByEmail(email);
      //   if (cachedUser != null) {
      //     _currentUser = cachedUser;
      //     _status = AuthStatus.authenticated;
      //     notifyListeners();
      //     return true;
      //   }
      //   throw Exception('Aucune connexion Internet');
      // }

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
      // if (!_networkService.isConnected) {
      //   throw Exception('Aucune connexion Internet');
      // }

      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      _errorMessage = 'Erreur: $e';
      return false;
    }
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
    //  if (_currentUser == null || !_networkService.isConnected) return;

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
  void _startGracePeriodTimer(String userId) {
    Timer(const Duration(days: 30), () async {
      try {
        final response = await _supabase
            .from('profiles')
            .select('created_at')
            .eq('id', userId)
            .single();

        if (response != null) {
          await _supabase.from('profiles').delete().eq('id', userId);
          await _objectBox.deleteUser(userId);
        }
      } catch (e) {
        debugPrint('Grace period cleanup error: $e');
      }
    });
  }

  Future<bool> _checkEmailExists(String email) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('email', email)
          .single();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> _createUserProfile(
    String userId,
    String email,
    String? fullName,
  ) async {
    final now = DateTime.now();
    await _supabase.from('profiles').insert({
      'id': userId,
      'email': email,
      'full_name': fullName,
      'profile_completed': false,
      'completion_percentage': 0,
      'role': 'user',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  Future<void> _loadUserFromSupabase(String userId) async {
    try {
      debugPrint('Chargement du profil pour userId: $userId');
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      if (data == null) {
        debugPrint(
          'Aucun profil trouvé pour userId: $userId. Création d\'un profil minimal...',
        );
        await _createMinimalUserProfile(userId, 'email@inconnu.com', null);
        _errorMessage = 'Profil créé. Veuillez compléter vos informations.';
        _status = AuthStatus.profileIncomplete;
        notifyListeners();
        return;
      }

      _currentUser = _mapToUserEntity(data);
      await _objectBox.saveUser(_currentUser!);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_active_session', true);
      _determineAuthStatus();
    } catch (e) {
      _errorMessage = 'Erreur de chargement du profil: $e';
      _status = AuthStatus.error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _loadUserFromLocal(String userId) async {
    _currentUser = await _objectBox.getUser(userId);
    _determineAuthStatus();
  }

  void _determineAuthStatus() {
    if (_currentUser == null) {
      _status = AuthStatus.unauthenticated;
    } else if (!_currentUser!.profileCompleted) {
      _status = AuthStatus.profileIncomplete;
    } else {
      _status = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  Future<void> _saveUnverifiedUser(String userId, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('unverified_user_id', userId);
    await prefs.setString('unverified_email', email);
  }

  Future<void> _clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  UserEntity _mapToUserEntity(Map<String, dynamic> data) {
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
      photosJson: jsonEncode(data['photos'] ?? []),
      photoUrl: data['photo_url'],
      coverUrl: data['cover_url'],
      profileCompleted: data['profile_completed'] ?? false,
      completionPercentage: data['completion_percentage'] ?? 0,
      occupation: data['occupation'],
      interestsJson: jsonEncode(data['interests'] ?? []),
      heightCm: data['height_cm'],
      education: data['education'],
      relationshipStatus: data['relationship_status'],
      instagramHandle: data['instagram_handle'],
      spotifyAnthem: data['spotify_anthem'],
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
