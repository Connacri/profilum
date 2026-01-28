// lib/services/local_cache_service.dart - ✅ CACHE LOCAL OPTIMISÉ
// Remplace ObjectBox par SharedPreferences + Cache mémoire

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🗄️ Service de cache local léger et performant
/// Stratégie : SharedPreferences pour persistance + Cache mémoire pour vitesse
class LocalCacheService {
  static LocalCacheService? _instance;
  static SharedPreferences? _prefs;
  
  // 🧠 Cache mémoire pour performances (reset à chaque session)
  final Map<String, dynamic> _memoryCache = {};
  
  LocalCacheService._();
  
  /// Factory singleton
  static Future<LocalCacheService> getInstance() async {
    if (_instance != null) return _instance!;
    
    _instance = LocalCacheService._();
    _prefs = await SharedPreferences.getInstance();
    
    debugPrint('✅ LocalCacheService initialized');
    return _instance!;
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // 👤 USER DATA - Infos utilisateur courant
  // ═══════════════════════════════════════════════════════════════════
  
  /// Sauvegarder les données utilisateur
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    try {
      final userId = userData['user_id'] ?? userData['id'];
      if (userId == null) {
        debugPrint('❌ Cannot save user data: no user_id');
        return;
      }
      
      final key = 'user_$userId';
      
      // 🧠 Mémoire (accès instantané)
      _memoryCache[key] = userData;
      
      // 💾 Disque (persistance)
      await _prefs?.setString(key, jsonEncode(userData));
      
      debugPrint('✅ User data saved: $userId');
    } catch (e) {
      debugPrint('❌ Error saving user data: $e');
    }
  }
  
  /// Récupérer les données utilisateur
  Map<String, dynamic>? getUserData(String userId) {
    try {
      final key = 'user_$userId';
      
      // 🧠 Essayer le cache mémoire d'abord
      if (_memoryCache.containsKey(key)) {
        return _memoryCache[key] as Map<String, dynamic>;
      }
      
      // 💾 Sinon charger depuis le disque
      final jsonStr = _prefs?.getString(key);
      if (jsonStr == null) return null;
      
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      // Mettre en cache mémoire pour la prochaine fois
      _memoryCache[key] = data;
      
      return data;
    } catch (e) {
      debugPrint('❌ Error getting user data: $e');
      return null;
    }
  }
  
  /// Supprimer les données utilisateur
  Future<void> deleteUserData(String userId) async {
    final key = 'user_$userId';
    _memoryCache.remove(key);
    await _prefs?.remove(key);
    debugPrint('🗑️ User data deleted: $userId');
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // 📸 PHOTOS CACHE - Cache des métadonnées photos
  // ═══════════════════════════════════════════════════════════════════
  
  /// Sauvegarder la liste des photos d'un user
  Future<void> saveUserPhotos(String userId, List<Map<String, dynamic>> photos) async {
    try {
      final key = 'photos_$userId';
      
      // 🧠 Mémoire
      _memoryCache[key] = photos;
      
      // 💾 Disque
      await _prefs?.setString(key, jsonEncode(photos));
      
      debugPrint('✅ Photos cached: ${photos.length} for user $userId');
    } catch (e) {
      debugPrint('❌ Error saving photos: $e');
    }
  }
  
  /// Récupérer les photos d'un user depuis le cache
  List<Map<String, dynamic>>? getUserPhotos(String userId) {
    try {
      final key = 'photos_$userId';
      
      // 🧠 Cache mémoire
      if (_memoryCache.containsKey(key)) {
        return List<Map<String, dynamic>>.from(_memoryCache[key]);
      }
      
      // 💾 Disque
      final jsonStr = _prefs?.getString(key);
      if (jsonStr == null) return null;
      
      final photos = List<Map<String, dynamic>>.from(jsonDecode(jsonStr));
      
      // Mettre en cache mémoire
      _memoryCache[key] = photos;
      
      return photos;
    } catch (e) {
      debugPrint('❌ Error getting photos: $e');
      return null;
    }
  }
  
  /// Ajouter une photo au cache
  Future<void> addPhoto(String userId, Map<String, dynamic> photo) async {
    final photos = getUserPhotos(userId) ?? [];
    photos.add(photo);
    await saveUserPhotos(userId, photos);
  }
  
  /// Mettre à jour une photo dans le cache
  Future<void> updatePhoto(String userId, String photoId, Map<String, dynamic> updates) async {
    final photos = getUserPhotos(userId);
    if (photos == null) return;
    
    final index = photos.indexWhere((p) => p['id'] == photoId);
    if (index == -1) return;
    
    photos[index] = {...photos[index], ...updates};
    await saveUserPhotos(userId, photos);
  }
  
  /// Supprimer une photo du cache
  Future<void> deletePhoto(String userId, String photoId) async {
    final photos = getUserPhotos(userId);
    if (photos == null) return;
    
    photos.removeWhere((p) => p['id'] == photoId);
    await saveUserPhotos(userId, photos);
  }
  
  /// Vider le cache photos d'un user
  Future<void> clearUserPhotos(String userId) async {
    final key = 'photos_$userId';
    _memoryCache.remove(key);
    await _prefs?.remove(key);
    debugPrint('🗑️ Photos cache cleared for user $userId');
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // ⚙️ PREFERENCES - Paramètres utilisateur
  // ═══════════════════════════════════════════════════════════════════
  
  /// Sauvegarder une préférence
  Future<void> savePreference(String key, dynamic value) async {
    try {
      if (value is String) {
        await _prefs?.setString(key, value);
      } else if (value is int) {
        await _prefs?.setInt(key, value);
      } else if (value is double) {
        await _prefs?.setDouble(key, value);
      } else if (value is bool) {
        await _prefs?.setBool(key, value);
      } else {
        await _prefs?.setString(key, jsonEncode(value));
      }
      
      _memoryCache[key] = value;
    } catch (e) {
      debugPrint('❌ Error saving preference $key: $e');
    }
  }
  
  /// Récupérer une préférence
  T? getPreference<T>(String key, {T? defaultValue}) {
    try {
      // Cache mémoire
      if (_memoryCache.containsKey(key)) {
        return _memoryCache[key] as T?;
      }
      
      // Disque
      final value = _prefs?.get(key);
      if (value == null) return defaultValue;
      
      // Si c'est un JSON
      if (value is String && (value.startsWith('{') || value.startsWith('['))) {
        final decoded = jsonDecode(value);
        _memoryCache[key] = decoded;
        return decoded as T?;
      }
      
      _memoryCache[key] = value;
      return value as T? ?? defaultValue;
    } catch (e) {
      debugPrint('❌ Error getting preference $key: $e');
      return defaultValue;
    }
  }
  
  /// Supprimer une préférence
  Future<void> deletePreference(String key) async {
    _memoryCache.remove(key);
    await _prefs?.remove(key);
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // 🔐 AUTH TOKENS - Gestion des tokens
  // ═══════════════════════════════════════════════════════════════════
  
  /// Sauvegarder le token d'authentification
  Future<void> saveAuthToken(String token) async {
    await _prefs?.setString('auth_token', token);
    _memoryCache['auth_token'] = token;
    debugPrint('✅ Auth token saved');
  }
  
  /// Récupérer le token
  String? getAuthToken() {
    if (_memoryCache.containsKey('auth_token')) {
      return _memoryCache['auth_token'] as String?;
    }
    
    final token = _prefs?.getString('auth_token');
    if (token != null) {
      _memoryCache['auth_token'] = token;
    }
    return token;
  }
  
  /// Supprimer le token (logout)
  Future<void> deleteAuthToken() async {
    _memoryCache.remove('auth_token');
    await _prefs?.remove('auth_token');
    debugPrint('🗑️ Auth token deleted');
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // 🧹 CLEANUP - Nettoyage
  // ═══════════════════════════════════════════════════════════════════
  
  /// Vider tout le cache mémoire (garde les données sur disque)
  void clearMemoryCache() {
    _memoryCache.clear();
    debugPrint('🧹 Memory cache cleared');
  }
  
  /// Vider TOUT (mémoire + disque)
  Future<void> clearAll() async {
    _memoryCache.clear();
    await _prefs?.clear();
    debugPrint('🧹 All cache cleared');
  }
  
  /// Vider seulement les données d'un user spécifique
  Future<void> clearUserCache(String userId) async {
    await deleteUserData(userId);
    await clearUserPhotos(userId);
    debugPrint('🧹 User cache cleared: $userId');
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // 📊 DIAGNOSTICS
  // ═══════════════════════════════════════════════════════════════════
  
  /// Obtenir des stats sur le cache
  Map<String, dynamic> getCacheStats() {
    final allKeys = _prefs?.getKeys() ?? {};
    
    return {
      'memory_items': _memoryCache.length,
      'disk_items': allKeys.length,
      'memory_keys': _memoryCache.keys.toList(),
      'disk_keys': allKeys.toList(),
    };
  }
  
  /// Logger les stats
  void logStats() {
    final stats = getCacheStats();
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('📊 CACHE STATS');
    debugPrint('   Memory items: ${stats['memory_items']}');
    debugPrint('   Disk items: ${stats['disk_items']}');
    debugPrint('═══════════════════════════════════════════════════');
  }
}
