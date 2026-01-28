// lib/services/supabase_service.dart - ✅ SERVICE SUPABASE OPTIMISÉ
// Gestion centralisée de Supabase + Auth + User Data

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_cache_service.dart';

/// 🔐 Service centralisé pour Supabase
class SupabaseService {
  static SupabaseService? _instance;
  final SupabaseClient _client;
  final LocalCacheService _localCache;

  SupabaseService._({
    required SupabaseClient client,
    required LocalCacheService localCache,
  })  : _client = client,
        _localCache = localCache {
    _setupAuthListener();
  }

  /// Factory singleton
  static Future<SupabaseService> getInstance({
    required SupabaseClient client,
  }) async {
    if (_instance != null) return _instance!;

    final localCache = await LocalCacheService.getInstance();
    _instance = SupabaseService._(
      client: client,
      localCache: localCache,
    );

    debugPrint('✅ SupabaseService initialized');
    return _instance!;
  }

  /// Accès au client Supabase
  SupabaseClient get client => _client;

  /// Accès à l'auth
  GoTrueClient get auth => _client.auth;

  /// User courant
  User? get currentUser => _client.auth.currentUser;

  /// User ID courant
  String? get currentUserId => currentUser?.id;

  /// Est connecté ?
  bool get isAuthenticated => currentUser != null;

  // ═══════════════════════════════════════════════════════════════════
  // 🔐 AUTH LISTENER
  // ═══════════════════════════════════════════════════════════════════

  void _setupAuthListener() {
    _client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      debugPrint('🔐 Auth event: $event');

      switch (event) {
        case AuthChangeEvent.signedIn:
          debugPrint('✅ User signed in: ${session?.user.id}');
          if (session?.user.id != null) {
            await _syncUserData(session!.user.id);
          }
          break;

        case AuthChangeEvent.signedOut:
          debugPrint('🚪 User signed out');
          await _clearUserCache();
          break;

        case AuthChangeEvent.tokenRefreshed:
          debugPrint('🔄 Token refreshed');
          break;

        default:
          break;
      }
    });
  }

  /// Synchroniser les données user après connexion
  Future<void> _syncUserData(String userId) async {
    try {
      debugPrint('🔄 Syncing user data...');

      final userData = await _client
          .from('users')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (userData != null) {
        await _localCache.saveUserData(userData);
        debugPrint('✅ User data synced');
      }
    } catch (e) {
      debugPrint('❌ Error syncing user data: $e');
    }
  }

  /// Vider le cache utilisateur
  Future<void> _clearUserCache() async {
    await _localCache.clearAll();
    debugPrint('🧹 User cache cleared');
  }

  // ═══════════════════════════════════════════════════════════════════
  // 👤 USER MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════

  /// Récupérer les données du user courant (cache-first)
  Future<Map<String, dynamic>?> getCurrentUserData({
    bool forceRefresh = false,
  }) async {
    if (currentUserId == null) return null;

    try {
      // Cache-first
      if (!forceRefresh) {
        final cached = _localCache.getUserData(currentUserId!);
        if (cached != null) {
          debugPrint('💾 Using cached user data');
          return cached;
        }
      }

      // Fetch from Supabase
      debugPrint('🌐 Fetching user data from Supabase...');
      
      final userData = await _client
          .from('users')
          .select()
          .eq('user_id', currentUserId!)
          .maybeSingle();

      if (userData != null) {
        await _localCache.saveUserData(userData);
      }

      return userData;
    } catch (e) {
      debugPrint('❌ Error getting user data: $e');
      
      // Fallback to cache
      return _localCache.getUserData(currentUserId!);
    }
  }

  /// Mettre à jour les données du user courant
  Future<bool> updateCurrentUserData(Map<String, dynamic> updates) async {
    if (currentUserId == null) return false;

    try {
      debugPrint('✏️ Updating user data...');

      // Update Supabase
      await _client
          .from('users')
          .update({
            ...updates,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', currentUserId!);

      // Update cache
      final currentData = _localCache.getUserData(currentUserId!) ?? {};
      await _localCache.saveUserData({...currentData, ...updates});

      debugPrint('✅ User data updated');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating user data: $e');
      return false;
    }
  }

  /// Récupérer les données d'un autre user
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      // Essayer le cache d'abord
      final cached = _localCache.getUserData(userId);
      if (cached != null) return cached;

      // Fetch depuis Supabase
      final userData = await _client
          .from('users')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (userData != null) {
        await _localCache.saveUserData(userData);
      }

      return userData;
    } catch (e) {
      debugPrint('❌ Error getting user data for $userId: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔄 SYNC
  // ═══════════════════════════════════════════════════════════════════

  /// Force refresh de toutes les données du user courant
  Future<void> syncCurrentUser() async {
    if (currentUserId == null) return;

    debugPrint('🔄 Force syncing current user...');

    // Clear cache
    await _localCache.clearUserCache(currentUserId!);

    // Re-fetch
    await getCurrentUserData(forceRefresh: true);

    debugPrint('✅ Current user synced');
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔍 QUERIES HELPERS
  // ═══════════════════════════════════════════════════════════════════

  /// Vérifier si un email existe déjà
  Future<bool> emailExists(String email) async {
    try {
      final result = await _client
          .from('users')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      return result != null;
    } catch (e) {
      debugPrint('❌ Error checking email: $e');
      return false;
    }
  }

  /// Obtenir le profil completion status
  Future<bool> isProfileCompleted() async {
    final userData = await getCurrentUserData();
    return userData?['profile_completed'] == true;
  }

  /// Obtenir le pourcentage de completion
  Future<int> getCompletionPercentage() async {
    final userData = await getCurrentUserData();
    return (userData?['completion_percentage'] as int?) ?? 0;
  }
}
