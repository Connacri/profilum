// lib/services/service_locator.dart - 🎯 INITIALISATION CENTRALISÉE DES SERVICES
// Pattern : Service Locator sans package externe (GetIt replacement)

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/fix_photo_url_builder.dart';
import '../services/image_service.dart';
import '../services/photo_crud_service.dart';
import '../services/profile_image_service.dart';

import 'local_cache_service.dart';


import 'supabase_service.dart';

/// 🎯 Service Locator simple et performant
/// Remplace GetIt avec une solution native
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._();
  factory ServiceLocator() => _instance;
  ServiceLocator._();

  // ═══════════════════════════════════════════════════════════════════
  // 📦 SERVICES INSTANCES
  // ═══════════════════════════════════════════════════════════════════

  SupabaseClient? _supabaseClient;
  LocalCacheService? _localCache;
  SupabaseService? _supabaseService;
  ImageService? _imageService;
  PhotoUrlHelper? _photoUrlHelper;
  ProfileImageService? _profileImageService;
  PhotoCrudService? _photoCrudService;

  bool _isInitialized = false;

  // ═══════════════════════════════════════════════════════════════════
  // 🚀 INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════

  /// Initialiser tous les services
  Future<void> init({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    if (_isInitialized) {
      debugPrint('⚠️ Services already initialized');
      return;
    }

    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('🚀 INITIALIZING SERVICES');
    debugPrint('═══════════════════════════════════════════════════');

    try {
      // ✅ 1. Supabase Client
      debugPrint('📦 [1/7] Initializing Supabase...');
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _supabaseClient = Supabase.instance.client;
      debugPrint('✅ Supabase initialized');

      // ✅ 2. Local Cache Service
      debugPrint('💾 [2/7] Initializing Local Cache...');
      _localCache = await LocalCacheService.getInstance();
      debugPrint('✅ Local Cache initialized');

      // ✅ 3. Supabase Service (wrapper)
      debugPrint('🔐 [3/7] Initializing Supabase Service...');
      _supabaseService = await SupabaseService.getInstance(
        client: _supabaseClient!,
      );
      debugPrint('✅ Supabase Service initialized');

      // ✅ 4. Image Service
      debugPrint('🖼️ [4/7] Initializing Image Service...');
      _imageService = ImageService(_supabaseClient!);
      debugPrint('✅ Image Service initialized');

      // ✅ 5. Photo URL Helper
      debugPrint('🔗 [5/7] Initializing Photo URL Helper...');
      _photoUrlHelper = PhotoUrlHelper(_supabaseClient!);
      debugPrint('✅ Photo URL Helper initialized');

      // ✅ 6. Profile Image Service
      debugPrint('📸 [6/7] Initializing Profile Image Service...');
      _profileImageService = ProfileImageService(_supabaseClient!);
      debugPrint('✅ Profile Image Service initialized');

      // ✅ 7. Photo CRUD Service
      debugPrint('🔥 [7/7] Initializing Photo CRUD Service...');
      _photoCrudService = PhotoCrudService(
        supabase: _supabaseClient!,
        localCache: _localCache!,
        imageService: _imageService!,
        urlHelper: _photoUrlHelper!,
      );
      debugPrint('✅ Photo CRUD Service initialized');

      _isInitialized = true;

      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('✅ ALL SERVICES INITIALIZED SUCCESSFULLY');
      debugPrint('═══════════════════════════════════════════════════');
    } catch (e, stack) {
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('❌ SERVICE INITIALIZATION FAILED');
      debugPrint('Error: $e');
      debugPrint('Stack: $stack');
      debugPrint('═══════════════════════════════════════════════════');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 📲 GETTERS - Accès aux services
  // ═══════════════════════════════════════════════════════════════════

  /// Supabase Client
  SupabaseClient get supabase {
    _checkInitialized();
    return _supabaseClient!;
  }

  /// Local Cache Service
  LocalCacheService get cache {
    _checkInitialized();
    return _localCache!;
  }

  /// Supabase Service (wrapper avec helpers)
  SupabaseService get supabaseService {
    _checkInitialized();
    return _supabaseService!;
  }

  /// Image Service
  ImageService get imageService {
    _checkInitialized();
    return _imageService!;
  }

  /// Photo URL Helper
  PhotoUrlHelper get photoUrlHelper {
    _checkInitialized();
    return _photoUrlHelper!;
  }

  /// Profile Image Service
  ProfileImageService get profileImageService {
    _checkInitialized();
    return _profileImageService!;
  }

  /// Photo CRUD Service
  PhotoCrudService get photoCrudService {
    _checkInitialized();
    return _photoCrudService!;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔧 HELPERS
  // ═══════════════════════════════════════════════════════════════════

  /// Vérifier que les services sont initialisés
  void _checkInitialized() {
    if (!_isInitialized) {
      throw Exception(
        '❌ Services not initialized! Call ServiceLocator().init() first.',
      );
    }
  }

  /// Est-ce que les services sont initialisés ?
  bool get isInitialized => _isInitialized;

  // ═══════════════════════════════════════════════════════════════════
  // 🗑️ CLEANUP (pour tests ou reset)
  // ═══════════════════════════════════════════════════════════════════

  /// Reset tous les services (utile pour tests)
  Future<void> reset() async {
    debugPrint('🗑️ Resetting all services...');

    _supabaseClient = null;
    _localCache = null;
    _supabaseService = null;
    _imageService = null;
    _photoUrlHelper = null;
    _profileImageService = null;
    _photoCrudService = null;

    _isInitialized = false;

    debugPrint('✅ Services reset');
  }
}

// ═══════════════════════════════════════════════════════════════════
// 🎯 GLOBAL ACCESSOR (optionnel pour faciliter l'accès)
// ═══════════════════════════════════════════════════════════════════

/// Accès global facile aux services
/// Usage : services.photoCrudService.getPhotos(...)
final services = ServiceLocator();
