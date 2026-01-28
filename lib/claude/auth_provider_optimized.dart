import 'dart:async';

import 'package:flutter/material.dart';
import 'package:profilum/claude/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';

import '../widgets/auth_rate_limiter.dart';

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
  final AuthRateLimiter? _rateLimiter;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _currentUser;
  String? _errorMessage;
  Timer? _sessionTimer;
  Timer? _heartbeatTimer;
  StreamSubscription? _authSubscription;

  static const Duration _sessionDuration = Duration(days: 30);
  static const Duration _refreshBuffer = Duration(hours: 1);
  static const Duration _heartbeatInterval = Duration(minutes: 5);

  static const String _keyProfileSkipped = 'profile_completion_skipped';
  static const String _keySkippedAt = 'profile_skipped_at';
  static const String _keyLastReminder = 'last_completion_reminder';

  AuthProvider(
      this._supabase, {
        AuthRateLimiter? rateLimiter,
      }) : _rateLimiter = rateLimiter {
    _initAuth();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔍 GETTERS
  // ═══════════════════════════════════════════════════════════════════

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated ||
          _status == AuthStatus.profileIncomplete;
  bool get canAccessApp => isAuthenticated;

  // ═══════════════════════════════════════════════════════════════════
  // 📝 SIGNUP
  // ═══════════════════════════════════════════════════════════════════

  Future<bool> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('🔵 SIGNUP START: $email');
    debugPrint('═══════════════════════════════════════════════════');

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // ✅ 1. Créer dans Supabase Auth
      debugPrint('🔵 Step 1: Creating account in Supabase Auth...');

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
        emailRedirectTo: 'io.supabase.profilum://email-verification',
      );

      if (response.user == null) {
        throw Exception('Aucun utilisateur retourné par Supabase');
      }

      final user = response.user!;
      debugPrint('✅ User created in Auth: ${user.id}');

      // ✅ 2. Charger le profil créé (trigger database fait le travail)
      debugPrint('🔵 Step 2: Loading created profile...');
      await _loadUserFromSupabase(user.id);

      // ✅ 3. Déterminer le statut
      _status = user.emailConfirmedAt == null
          ? AuthStatus.emailVerificationPending
          : AuthStatus.profileIncomplete;

      debugPrint('✅ SIGNUP SUCCESS - Status: $_status');
      debugPrint('═══════════════════════════════════════════════════');

      notifyListeners();
      return true;
    } on AuthException catch (e) {
      debugPrint('❌ AUTH EXCEPTION: ${e.statusCode} - ${e.message}');

      // ✅ Email déjà existant → switch to signin
      if (e.statusCode == '422' && _isEmailAlreadyRegistered(e.message)) {
        _errorMessage = 'Cet email existe déjà. Connexion en cours...';
        notifyListeners();

        await Future.delayed(const Duration(milliseconds: 500));
        return await signIn(email: email, password: password);
      }

      _errorMessage = _handleAuthError(e);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e, stack) {
      debugPrint('❌ SIGNUP ERROR: $e');
      debugPrint('Stack: $stack');

      _errorMessage = 'Erreur inattendue: $e';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔐 SIGNIN
  // ═══════════════════════════════════════════════════════════════════

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('🔵 SIGNIN START: $email');
    debugPrint('═══════════════════════════════════════════════════');

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Connexion échouée : aucun utilisateur retourné');
      }

      final user = response.user!;
      debugPrint('✅ Signed in: ${user.id}');

      if (user.emailConfirmedAt == null) {
        _status = AuthStatus.emailVerificationPending;
        notifyListeners();
        return true;
      }

      await _loadUserFromSupabase(user.id);
      _startSessionManagement();

      debugPrint('✅ SIGNIN SUCCESS - Status: $_status');
      debugPrint('═══════════════════════════════════════════════════');

      return true;
    } on AuthException catch (e) {
      debugPrint('❌ AUTH EXCEPTION: ${e.statusCode} - ${e.message}');

      _errorMessage = _handleAuthError(e);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e, stack) {
      debugPrint('❌ SIGNIN ERROR: $e');
      debugPrint('Stack: $stack');

      _errorMessage = 'Erreur de connexion: $e';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 📥 LOAD USER - DEPUIS SUPABASE
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _loadUserFromSupabase(String userId) async {
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('🔵 Loading profile from Supabase: $userId');
    debugPrint('═══════════════════════════════════════════════════');

    try {
      // ✅ 1. Vérifier auth
      final authUser = _supabase.auth.currentUser;
      if (authUser == null || authUser.id != userId) {
        throw Exception('Utilisateur non authentifié');
      }

      // ✅ 2. Charger depuis Supabase
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) {
        throw Exception('Profile not found');
      }

      // ✅ 3. Créer UserModel
      _currentUser = UserModel.fromSupabase(data);
      debugPrint('✅ Profile loaded: ${_currentUser!.fullName}');

      // ✅ 4. Sauvegarder en cache local
      await services.cache.saveUserData(data);
      debugPrint('💾 Cached locally');

      // ✅ 5. Marquer session active
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_active_session', true);

      // ✅ 6. Déterminer status
      await _determineAuthStatus();

      debugPrint('✅ Profile loading complete');
      debugPrint('═══════════════════════════════════════════════════');
    } catch (e, stack) {
      debugPrint('❌ Load profile error: $e');
      debugPrint('Stack: $stack');

      _errorMessage = 'Erreur de chargement du profil: $e';
      _status = AuthStatus.error;
      notifyListeners();
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🎯 DETERMINE STATUS
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _determineAuthStatus() async {
    if (_currentUser == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // Admin/Moderator → toujours authenticated
    if (_currentUser!.role == 'admin' || _currentUser!.role == 'moderator') {
      _status = AuthStatus.authenticated;
      notifyListeners();
      return;
    }

    // Profil complet → authenticated
    if (_currentUser!.profileCompleted) {
      _status = AuthStatus.authenticated;
      notifyListeners();
      return;
    }

    // Profil incomplet : vérifier skip
    final hasSkipped = await hasSkippedCompletion();
    _status = hasSkipped
        ? AuthStatus.authenticated
        : AuthStatus.profileIncomplete;

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔄 RELOAD USER
  // ═══════════════════════════════════════════════════════════════════

  Future<void> reloadCurrentUser() async {
    if (_currentUser == null) return;

    try {
      await _loadUserFromSupabase(_currentUser!.userId);
    } catch (e) {
      debugPrint('❌ Reload error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🚪 SIGNOUT
  // ═══════════════════════════════════════════════════════════════════

  Future<void> signOut() async {
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('🔵 SIGNOUT START');
    debugPrint('═══════════════════════════════════════════════════');

    try {
      // 1. Signout Supabase
      await _supabase.auth.signOut();

      // 2. Clear local session
      await _clearLocalSession();

      // 3. Stop timers
      _stopSessionManagement();

      // 4. Reset state
      _currentUser = null;
      _errorMessage = null;
      _status = AuthStatus.unauthenticated;

      // 5. Clear rate limiter
      if (_rateLimiter != null) {
        await _rateLimiter!.clear();
      }

      notifyListeners();

      debugPrint('✅ SIGNOUT SUCCESS');
      debugPrint('═══════════════════════════════════════════════════');
    } catch (e) {
      debugPrint('❌ SIGNOUT ERROR: $e');

      // Force reset même en cas d'erreur
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🗑️ DELETE ACCOUNT
  // ═══════════════════════════════════════════════════════════════════

  Future<bool> deleteAccount({String? reason}) async {
    if (_currentUser == null) return false;

    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('🔴 ACCOUNT DELETION START');
    debugPrint('═══════════════════════════════════════════════════');

    try {
      final userId = _currentUser!.userId;

      // 1. Supprimer toutes les photos
      debugPrint('🗑️ [1/4] Deleting photos...');
      await services.photoCrudService.deleteAllUserPhotos(userId: userId);

      // 2. Supprimer des tables
      debugPrint('🗑️ [2/4] Deleting from tables...');

      await _safeDelete('notifications', 'user_id', userId);
      await _safeDelete('matches', 'user_id_1', userId, orField: 'user_id_2');
      await _safeDelete('preferences', 'user_id', userId);

      // 3. Logger la raison
      if (reason != null) {
        try {
          await _supabase.from('account_deletions').insert({
            'user_id': userId,
            'reason': reason,
            'deleted_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('⊘ Analytics table not found (skipped)');
        }
      }

      // 4. Supprimer le profil
      debugPrint('🗑️ [3/4] Deleting profile...');
      await _supabase.from('profiles').delete().eq('id', userId);

      // 5. Supprimer de Auth
      debugPrint('🗑️ [4/4] Deleting auth user...');
      try {
        await _supabase.rpc('delete_user');
      } catch (e) {
        debugPrint('⚠️ RPC delete_user not found');
      }

      // 6. Cleanup local
      await services.cache.clearAll();
      await _clearLocalSession();
      _stopSessionManagement();

      _currentUser = null;
      _status = AuthStatus.accountDeleted;
      notifyListeners();

      debugPrint('✅ ACCOUNT DELETED');
      debugPrint('═══════════════════════════════════════════════════');
      return true;
    } catch (e, stack) {
      debugPrint('❌ DELETE ACCOUNT ERROR: $e');
      debugPrint('Stack: $stack');

      _errorMessage = 'Erreur de suppression: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> _safeDelete(
      String table,
      String field,
      String value, {
        String? orField,
      }) async {
    try {
      if (orField != null) {
        await _supabase
            .from(table)
            .delete()
            .or('$field.eq.$value,$orField.eq.$value');
      } else {
        await _supabase.from(table).delete().eq(field, value);
      }
      debugPrint('  ✓ $table deleted');
    } catch (e) {
      debugPrint('  ⊘ $table not found (skipped)');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔧 HELPERS
  // ═══════════════════════════════════════════════════════════════════

  bool _isEmailAlreadyRegistered(String message) {
    final lower = message.toLowerCase();
    return lower.contains('user already registered') ||
        lower.contains('already in use') ||
        lower.contains('déjà utilisé');
  }

  String _handleAuthError(AuthException e) {
    switch (e.statusCode) {
      case '400':
        return 'Email ou mot de passe invalide';
      case '422':
        return 'Données invalides';
      case '429':
        return 'Trop de tentatives. Réessayez plus tard';
      default:
        return e.message;
    }
  }

  Future<bool> hasSkippedCompletion() async {
    if (_currentUser == null) return false;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${_keyProfileSkipped}_${_currentUser!.userId}') ?? false;
  }

  Future<bool> skipProfileCompletion() async {
    if (_currentUser == null) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      await prefs.setBool(
        '${_keyProfileSkipped}_${_currentUser!.userId}',
        true,
      );
      await prefs.setInt(
        '${_keySkippedAt}_${_currentUser!.userId}',
        now.millisecondsSinceEpoch,
      );

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Skip error: $e');
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      _errorMessage = 'Erreur: $e';
      return false;
    }
  }

  Future<bool> resendVerificationEmail() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase.auth.resend(type: OtpType.signup, email: user.email!);
      return true;
    } catch (e) {
      _errorMessage = 'Erreur: $e';
      return false;
    }
  }

  Future<bool> checkEmailVerification() async {
    try {
      final session = await _supabase.auth.refreshSession();
      final user = session.user;

      if (user == null) return false;

      if (user.emailConfirmedAt != null) {
        await _loadUserFromSupabase(user.id);
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔄 SESSION MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════

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

  Future<void> _clearLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('has_active_session');
      await prefs.remove('access_token');
      await prefs.remove('token_expires_at');

      // Clear skip keys
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_keyProfileSkipped) ||
            key.startsWith(_keySkippedAt) ||
            key.startsWith(_keyLastReminder)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Clear session error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🚀 INIT AUTH
  // ═══════════════════════════════════════════════════════════════════

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
      debugPrint('Init auth error: $e');
      _errorMessage = 'Erreur d\'initialisation: $e';
      _status = AuthStatus.error;
    }

    notifyListeners();
    _listenToAuthChanges();
  }

  Future<void> _loadUserFromLocal(String userId) async {
    final cachedData = services.cache.getUserData(userId);

    if (cachedData != null) {
      _currentUser = UserModel.fromSupabase(cachedData);
      await _determineAuthStatus();
    }
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
      } else if (event == AuthChangeEvent.userUpdated && session != null) {
        if (session.user.emailConfirmedAt != null &&
            _status == AuthStatus.emailVerificationPending) {
          _handleSignIn(session);
        }
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

    final expiresAt = session.expiresAt ??
        DateTime.now().add(_sessionDuration).millisecondsSinceEpoch ~/ 1000;
    await prefs.setInt('token_expires_at', expiresAt);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _stopSessionManagement();
    super.dispose();
  }
}