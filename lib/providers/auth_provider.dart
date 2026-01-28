// // lib/providers/auth_provider.dart - VERSION CORRIGÉE
// import 'dart:async';
// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:uuid/uuid.dart';
//
// import '../objectbox_entities_complete.dart';
// import '../services/services.dart';
// import '../widgets/auth_rate_limiter.dart';
//
// enum AuthStatus {
//   initial,
//   authenticated,
//   unauthenticated,
//   emailVerificationPending,
//   profileIncomplete,
//   loading,
//   error,
//   accountDeleted,
// }
//
// class AuthProvider extends ChangeNotifier {
//   final SupabaseClient _supabase;
//  // final ObjectBoxService _objectBox;
//   final AuthRateLimiter? _rateLimiter; // ✅ NOUVEAU (optionnel)
//
//   AuthStatus _status = AuthStatus.initial;
//  // UserEntity? _currentUser;
//   String? _errorMessage;
//   Timer? _sessionTimer;
//   Timer? _heartbeatTimer;
//   StreamSubscription? _authSubscription;
//
//   static const Duration _sessionDuration = Duration(days: 30);
//   static const Duration _refreshBuffer = Duration(hours: 1);
//   static const Duration _heartbeatInterval = Duration(minutes: 5);
//
//   static const String _keyProfileSkipped = 'profile_completion_skipped';
//   static const String _keySkippedAt = 'profile_skipped_at';
//   static const String _keyLastReminder = 'last_completion_reminder';
//
//   // AuthProvider(this._supabase, this._objectBox) {
//   //   _initAuth();
//   // }
//   AuthProvider(
//     this._supabase,
//     this._objectBox, {
//     AuthRateLimiter? rateLimiter, // ✅ NOUVEAU
//   }) : _rateLimiter = rateLimiter {
//     _initAuth();
//   }
//   // Getters
//   AuthStatus get status => _status;
//   UserEntity? get currentUser => _currentUser;
//   String? get errorMessage => _errorMessage;
//   bool get isAuthenticated =>
//       _status == AuthStatus.authenticated ||
//       _status == AuthStatus.profileIncomplete;
//   bool get canAccessApp => isAuthenticated;
//
//   // ════════════════════════════════════════════════════════════════
//   // 🔧 PAS DE VÉRIFICATION PRÉALABLE
//   // ════════════════════════════════════════════════════════════════
//   // On tente directement le signup et on gère l'erreur "already exists"
//
//   // ════════════════════════════════════════════════════════════════
//   // 🔧 SIGNUP AMÉLIORÉ
//   // ════════════════════════════════════════════════════════════════
//
//   // Future<bool> signUp({
//   //   required String email,
//   //   required String password,
//   //   String? fullName,
//   // }) async {
//   //   debugPrint('════════════════════════════════════════');
//   //   debugPrint('🔵 SIGNUP START: $email');
//   //   debugPrint('════════════════════════════════════════');
//   //
//   //   _status = AuthStatus.loading;
//   //   _errorMessage = null;
//   //   notifyListeners();
//   //
//   //   try {
//   //     // ✅ ÉTAPE 1 : Tenter la création dans Supabase Auth
//   //     debugPrint('🔵 Step 1: Creating account in Supabase Auth...');
//   //
//   //     final response = await _supabase.auth.signUp(
//   //       email: email,
//   //       password: password,
//   //       data: {'full_name': fullName},
//   //       emailRedirectTo: 'io.supabase.profilum://email-verification',
//   //     );
//   //
//   //     if (response.user == null) {
//   //       throw Exception('Aucun utilisateur retourné par Supabase');
//   //     }
//   //
//   //     final user = response.user!;
//   //     debugPrint('✅ User created in Auth: ${user.id}');
//   //     debugPrint('   Email: ${user.email}');
//   //     debugPrint('   Confirmed: ${user.emailConfirmedAt != null}');
//   //
//   //     // ✅ ÉTAPE 2 : Créer le profil MANUELLEMENT dans la table profiles
//   //     debugPrint('🔵 Step 2: Creating profile in database...');
//   //     await _createUserProfile(
//   //       userId: user.id,
//   //       email: user.email!,
//   //       fullName: fullName,
//   //     );
//   //
//   //     // ✅ ÉTAPE 3 : Charger le profil créé
//   //     debugPrint('🔵 Step 3: Loading created profile...');
//   //     await _loadUserFromSupabase(user.id);
//   //
//   //     // ✅ ÉTAPE 4 : Déterminer le statut final
//   //     _status = user.emailConfirmedAt == null
//   //         ? AuthStatus.emailVerificationPending
//   //         : AuthStatus.profileIncomplete;
//   //
//   //     debugPrint('✅ SIGNUP SUCCESS');
//   //     debugPrint('   Status: $_status');
//   //     debugPrint('   User ID: ${user.id}');
//   //     debugPrint('════════════════════════════════════════');
//   //
//   //     notifyListeners();
//   //     return true;
//   //   } on AuthException catch (e) {
//   //     debugPrint('❌ AUTH EXCEPTION during signup');
//   //     debugPrint('   Status Code: ${e.statusCode}');
//   //     debugPrint('   Message: ${e.message}');
//   //
//   //     // ✅ GESTION SPÉCIALE : Email déjà existant
//   //     if (e.statusCode == '422' && _isEmailAlreadyRegistered(e.message)) {
//   //       debugPrint('⚠️ Email already registered, converting to signIn');
//   //       _errorMessage = 'Cet email existe déjà. Connexion en cours...';
//   //       notifyListeners();
//   //
//   //       // Attendre un peu pour que l'utilisateur voie le message
//   //       await Future.delayed(const Duration(milliseconds: 500));
//   //
//   //       // Convertir en signIn
//   //       return await signIn(email: email, password: password);
//   //     }
//   //
//   //     // Autres erreurs Auth
//   //     _errorMessage = _handleAuthError(e);
//   //     _status = AuthStatus.error;
//   //     notifyListeners();
//   //     return false;
//   //   } catch (e, stack) {
//   //     debugPrint('❌ UNEXPECTED ERROR during signup: $e');
//   //     debugPrint('Stack trace: $stack');
//   //
//   //     _errorMessage = 'Erreur inattendue: $e';
//   //     _status = AuthStatus.error;
//   //     notifyListeners();
//   //     return false;
//   //   }
//   // }
//   Future<bool> signUp({
//     required String email,
//     required String password,
//     String? fullName,
//   }) async {
//     debugPrint('════════════════════════════════════════');
//     debugPrint('🔵 SIGNUP START: $email');
//     debugPrint('════════════════════════════════════════');
//
//     _status = AuthStatus.loading;
//     _errorMessage = null;
//     notifyListeners();
//
//     try {
//       // ✅ ÉTAPE 1 : Tenter la création dans Supabase Auth
//       debugPrint('🔵 Step 1: Creating account in Supabase Auth...');
//
//       final response = await _supabase.auth.signUp(
//         email: email,
//         password: password,
//         data: {'full_name': fullName},
//         emailRedirectTo: 'io.supabase.profilum://email-verification',
//       );
//
//       if (response.user == null) {
//         throw Exception('Aucun utilisateur retourné par Supabase');
//       }
//
//       final user = response.user!;
//       debugPrint('✅ User created in Auth: ${user.id}');
//       debugPrint('   Email: ${user.email}');
//       debugPrint('   Confirmed: ${user.emailConfirmedAt != null}');
//
//       // ✅ ÉTAPE 2 : Créer le profil MANUELLEMENT dans la table profiles
//       debugPrint('🔵 Step 2: Creating profile in database...');
//       // await _createUserProfile(
//       //   userId: user.id,
//       //   email: user.email!,
//       //   fullName: fullName,
//       // );
//
//       // ✅ ÉTAPE 3 : Charger le profil créé
//       debugPrint('🔵 Step 3: Loading created profile...');
//       await _loadUserFromSupabase(user.id);
//
//       // ✅ ÉTAPE 4 : Déterminer le statut final
//       _status = user.emailConfirmedAt == null
//           ? AuthStatus.emailVerificationPending
//           : AuthStatus.profileIncomplete;
//
//       debugPrint('✅ SIGNUP SUCCESS');
//       debugPrint('   Status: $_status');
//       debugPrint('   User ID: ${user.id}');
//       debugPrint('════════════════════════════════════════');
//
//       notifyListeners();
//       return true;
//     } on AuthException catch (e) {
//       debugPrint('❌ AUTH EXCEPTION during signup');
//       debugPrint('   Status Code: ${e.statusCode}');
//       debugPrint('   Message: ${e.message}');
//
//       // ✅ GESTION SPÉCIALE : Email déjà existant
//       if (e.statusCode == '422' && _isEmailAlreadyRegistered(e.message)) {
//         debugPrint('⚠️ Email already registered, converting to signIn');
//         _errorMessage = 'Cet email existe déjà. Connexion en cours...';
//         notifyListeners();
//
//         // Attendre un peu pour que l'utilisateur voie le message
//         await Future.delayed(const Duration(milliseconds: 500));
//
//         // Convertir en signIn
//         return await signIn(email: email, password: password);
//       }
//
//       // Autres erreurs Auth
//       _errorMessage = _handleAuthError(e);
//       _status = AuthStatus.error;
//       notifyListeners();
//       return false;
//     } catch (e, stack) {
//       debugPrint('❌ UNEXPECTED ERROR during signup: $e');
//       debugPrint('Stack trace: $stack');
//
//       _errorMessage = 'Erreur inattendue: $e';
//       _status = AuthStatus.error;
//       notifyListeners();
//       return false;
//     }
//   }
//   // ════════════════════════════════════════════════════════════════
//   // 🆕 CRÉATION MANUELLE DU PROFIL (côté client)
//   // ════════════════════════════════════════════════════════════════
//
//   Future<void> _createUserProfile({
//     required String userId,
//     required String email,
//     String? fullName,
//   }) async {
//     debugPrint('🔧 Creating user profile for: $userId');
//
//     final now = DateTime.now();
//
//     try {
//       await _supabase.from('profiles').insert({
//         'id': userId, // ✅ Utiliser l'ID de Auth
//         'email': email,
//         'full_name': fullName ?? '',
//         'profile_completed': false,
//         'completion_percentage': 0,
//         'role': 'user',
//         'interests': [], // ✅ Array vide
//         'social_links': [], // ✅ JSONB vide
//         'created_at': now.toIso8601String(),
//         'updated_at': now.toIso8601String(),
//       });
//
//       debugPrint('✅ Profile created successfully in database');
//     } on PostgrestException catch (e) {
//       debugPrint('❌ PostgrestException: ${e.code} - ${e.message}');
//
//       // ✅ Gestion du doublon (si le profil existe déjà)
//       if (e.code == '23505') {
//         debugPrint('⚠️ Profile already exists (duplicate key)');
//         // Ne pas considérer comme une erreur fatale
//         return;
//       }
//
//       // Autres erreurs PostgreSQL
//       throw Exception('Erreur création profil: ${e.message}');
//     }
//   }
//
//   // ════════════════════════════════════════════════════════════════
//   // 🔍 HELPER : Détecter si l'email est déjà enregistré
//   // ════════════════════════════════════════════════════════════════
//
//   // bool _isEmailAlreadyRegistered(String errorMessage) {
//   //   final msg = errorMessage.toLowerCase();
//   //   return msg.contains('already') &&
//   //       (msg.contains('registered') ||
//   //           msg.contains('exists') ||
//   //           msg.contains('been registered'));
//   // }
//   bool _isEmailAlreadyRegistered(String message) {
//     final lowerMessage = message.toLowerCase();
//     return lowerMessage.contains('user already registered') ||
//         lowerMessage.contains('already in use') ||
//         lowerMessage.contains('déjà utilisé');
//   }
//
//   /// 🔍 NOUVEAU : Détecter si l'email n'existe pas dans Supabase
//   bool _isEmailNotFound(String errorMessage) {
//     final msg = errorMessage.toLowerCase();
//     return msg.contains('invalid login credentials') ||
//         msg.contains('user not found') ||
//         msg.contains('email not found');
//   }
//   // ════════════════════════════════════════════════════════════════
//   // 🔧 SIGNIN AMÉLIORÉ
//   // ════════════════════════════════════════════════════════════════
//
//   // ────────────────────────────────────────────────────────────────
//   // 2️⃣ MODIFIER LA MÉTHODE signIn() - AJOUTER CE BLOC DANS LE CATCH
//   // ────────────────────────────────────────────────────────────────
//
//   // Future<bool> signIn({required String email, required String password}) async {
//   //   debugPrint('════════════════════════════════════════');
//   //   debugPrint('🔵 SIGNIN START: $email');
//   //   debugPrint('════════════════════════════════════════');
//   //
//   //   _status = AuthStatus.loading;
//   //   _errorMessage = null;
//   //   notifyListeners();
//   //
//   //   try {
//   //     final response = await _supabase.auth.signInWithPassword(
//   //       email: email,
//   //       password: password,
//   //     );
//   //
//   //     if (response.user == null) {
//   //       throw Exception('Connexion échouée : aucun utilisateur retourné');
//   //     }
//   //
//   //     final user = response.user!;
//   //     debugPrint('✅ Signed in successfully');
//   //     debugPrint('   User ID: ${user.id}');
//   //     debugPrint('   Email confirmed: ${user.emailConfirmedAt != null}');
//   //
//   //     if (user.emailConfirmedAt == null) {
//   //       debugPrint('⚠️ Email not verified');
//   //       _status = AuthStatus.emailVerificationPending;
//   //       notifyListeners();
//   //       return true;
//   //     }
//   //
//   //     await _loadUserFromSupabase(user.id);
//   //     _startSessionManagement();
//   //
//   //     debugPrint('✅ SIGNIN SUCCESS');
//   //     debugPrint('   Status: $_status');
//   //     debugPrint('════════════════════════════════════════');
//   //
//   //     return true;
//   //   } on AuthException catch (e) {
//   //     debugPrint('❌ AUTH EXCEPTION during signin');
//   //     debugPrint('   Status Code: ${e.statusCode}');
//   //     debugPrint('   Message: ${e.message}');
//   //
//   //     // ✅ ========== AJOUTER CE BLOC ICI (AVANT LES AUTRES CONDITIONS) ==========
//   //
//   //     // 🔍 Détecter email inexistant → basculer vers signup
//   //     if (e.statusCode == '400' && _isEmailNotFound(e.message)) {
//   //       _errorMessage = 'email_not_found'; // ⚠️ Code spécial pour l'UI
//   //       _status = AuthStatus.error;
//   //       notifyListeners();
//   //       return false;
//   //     }
//   //
//   //     // ✅ ========== FIN DU BLOC À AJOUTER ==========
//   //
//   //     // Le reste du code existant continue...
//   //     _errorMessage = _handleAuthError(e);
//   //     _status = AuthStatus.error;
//   //     notifyListeners();
//   //     return false;
//   //   } catch (e, stack) {
//   //     debugPrint('❌ UNEXPECTED ERROR during signin: $e');
//   //     debugPrint('Stack trace: $stack');
//   //
//   //     _errorMessage = 'Erreur de connexion: $e';
//   //     _status = AuthStatus.error;
//   //     notifyListeners();
//   //     return false;
//   //   }
//   // }
//   Future<bool> signIn({required String email, required String password}) async {
//     debugPrint('════════════════════════════════════════');
//     debugPrint('🔵 SIGNIN START: $email');
//     debugPrint('════════════════════════════════════════');
//
//     _status = AuthStatus.loading;
//     _errorMessage = null;
//     notifyListeners();
//
//     try {
//       final response = await _supabase.auth.signInWithPassword(
//         email: email,
//         password: password,
//       );
//
//       if (response.user == null) {
//         throw Exception('Connexion échouée : aucun utilisateur retourné');
//       }
//
//       final user = response.user!;
//       debugPrint('✅ Signed in successfully');
//       debugPrint('   User ID: ${user.id}');
//       debugPrint('   Email confirmed: ${user.emailConfirmedAt != null}');
//
//       if (user.emailConfirmedAt == null) {
//         debugPrint('⚠️ Email not verified');
//         _status = AuthStatus.emailVerificationPending;
//         notifyListeners();
//         return true;
//       }
//
//       await _loadUserFromSupabase(user.id);
//       _startSessionManagement();
//
//       debugPrint('✅ SIGNIN SUCCESS');
//       debugPrint('   Status: $_status');
//       debugPrint('════════════════════════════════════════');
//
//       return true;
//     } on AuthException catch (e) {
//       debugPrint('❌ AUTH EXCEPTION during signin');
//       debugPrint('   Status Code: ${e.statusCode}');
//       debugPrint('   Message: ${e.message}');
//
//       _errorMessage = _handleAuthError(e);
//       _status = AuthStatus.error;
//       notifyListeners();
//       return false;
//     } catch (e, stack) {
//       debugPrint('❌ UNEXPECTED ERROR during signin: $e');
//       debugPrint('Stack trace: $stack');
//
//       _errorMessage = 'Erreur de connexion: $e';
//       _status = AuthStatus.error;
//       notifyListeners();
//       return false;
//     }
//   }
//   // ════════════════════════════════════════════════════════════════
//   // 🔧 GESTION DES ERREURS AUTH AMÉLIORÉE
//   // ════════════════════════════════════════════════════════════════
//
//   // ────────────────────────────────────────────────────────────────
//   // 3️⃣ AMÉLIORER _handleAuthError() (OPTIONNEL mais recommandé)
//   // ────────────────────────────────────────────────────────────────
//
//   // String _handleAuthError(AuthException e) {
//   //   debugPrint('🔍 Parsing Auth error: ${e.statusCode} - ${e.message}');
//   //
//   //   switch (e.statusCode) {
//   //     case '400':
//   //       if (e.message.contains('Invalid login credentials')) {
//   //         // ✅ Message générique (pour que le rate limiter détecte le password)
//   //         return 'Email ou mot de passe incorrect';
//   //       }
//   //       if (e.message.contains('Email not confirmed')) {
//   //         return 'Veuillez confirmer votre email avant de vous connecter';
//   //       }
//   //       return 'Requête invalide';
//   //
//   //     case '422':
//   //       if (e.message.contains('already registered') ||
//   //           e.message.contains('already been registered')) {
//   //         return 'Cet email est déjà utilisé';
//   //       }
//   //       if (e.message.contains('User already registered')) {
//   //         return 'Compte déjà existant';
//   //       }
//   //       return 'Données invalides';
//   //
//   //     case '429':
//   //       return 'Trop de tentatives. Réessayez dans quelques minutes';
//   //
//   //     case '500':
//   //       return 'Erreur serveur. Réessayez plus tard';
//   //
//   //     default:
//   //       debugPrint('⚠️ Unhandled Auth error code: ${e.statusCode}');
//   //       return e.message;
//   //   }
//   // }
//   String _handleAuthError(AuthException e) {
//     switch (e.statusCode) {
//       case '400':
//         return 'Email ou mot de passe invalide';
//       case '422':
//         return 'Données invalides';
//       case '429':
//         return 'Trop de tentatives. Réessayez plus tard';
//       default:
//         return e.message;
//     }
//   }
//   // ════════════════════════════════════════════════════════════════
//   // 🔧 CHARGEMENT PROFIL DEPUIS SUPABASE - AMÉLIORÉ
//   // ════════════════════════════════════════════════════════════════
//
//   Future<void> _loadUserFromSupabase(String userId) async {
//     debugPrint('════════════════════════════════════════');
//     debugPrint('🔵 Loading profile from Supabase');
//     debugPrint('   User ID: $userId');
//     debugPrint('════════════════════════════════════════');
//
//     try {
//       // ✅ ÉTAPE 1 : Vérifier que l'user existe dans Auth
//       final authUser = _supabase.auth.currentUser;
//       if (authUser == null || authUser.id != userId) {
//         throw Exception('Utilisateur non authentifié dans Auth');
//       }
//
//       debugPrint('✅ User confirmed in Auth: ${authUser.email}');
//
//       // ✅ ÉTAPE 2 : Charger le profil depuis la table profiles
//       debugPrint('🔍 Fetching profile from database...');
//
//       final data = await _supabase
//           .from('profiles')
//           .select()
//           .eq('id', userId)
//           .maybeSingle(); // ✅ Retourne null si inexistant
//
//       if (data == null) {
//         // ⚠️ Cela ne devrait JAMAIS arriver si le signup a bien fonctionné
//         debugPrint('❌ CRITICAL: Profile not found in database!');
//         debugPrint('🔧 Creating profile as fallback...');
//
//         await _createUserProfile(
//           userId: userId,
//           email: authUser.email ?? 'unknown@email.com',
//           fullName: authUser.userMetadata?['full_name'],
//         );
//
//         // Recharger après création
//         final newData = await _supabase
//             .from('profiles')
//             .select()
//             .eq('id', userId)
//             .single();
//
//         _currentUser = _mapToUserEntity(newData);
//         debugPrint('✅ Profile created and loaded (fallback)');
//       } else {
//         _currentUser = _mapToUserEntity(data);
//         debugPrint('✅ Profile loaded from database');
//       }
//
//       // ✅ ÉTAPE 3 : Charger les photos
//       debugPrint('🔍 Loading user photos...');
//       await _loadUserPhotos(userId);
//
//       // ✅ ÉTAPE 4 : Sauvegarder en local (ObjectBox)
//       debugPrint('💾 Saving to ObjectBox...');
//       await _objectBox.saveUser(_currentUser!);
//
//       // ✅ ÉTAPE 5 : Marquer la session active
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setBool('has_active_session', true);
//
//       // ✅ ÉTAPE 6 : Déterminer le statut
//       await _determineAuthStatus();
//
//       debugPrint('✅ Profile loading complete');
//       debugPrint('   Name: ${_currentUser!.fullName}');
//       debugPrint('   Email: ${_currentUser!.email}');
//       debugPrint('   Completed: ${_currentUser!.profileCompleted}');
//       debugPrint('   Status: $_status');
//       debugPrint('════════════════════════════════════════');
//     } catch (e, stack) {
//       debugPrint('❌ Error loading profile: $e');
//       debugPrint('Stack trace: $stack');
//
//       _errorMessage = 'Erreur de chargement du profil: $e';
//       _status = AuthStatus.error;
//       notifyListeners();
//       rethrow;
//     }
//   }
//
//   // ════════════════════════════════════════════════════════════════
//   // 📸 CHARGEMENT PHOTOS
//   // ════════════════════════════════════════════════════════════════
//
//   Future<void> _loadUserPhotos(String userId) async {
//     try {
//       final photos = await _supabase
//           .from('photos')
//           .select()
//           .eq('user_id', userId)
//           .eq('status', 'approved')
//           .order('display_order', ascending: true);
//
//       debugPrint('📸 Loaded ${photos.length} photos');
//
//       for (final photoData in photos) {
//         final photoEntity = PhotoEntity(
//           photoId: photoData['id'],
//           userId: userId,
//           type: photoData['type'],
//           localPath: '',
//           remotePath: photoData['remote_path'],
//           status: photoData['status'],
//           hasWatermark: photoData['has_watermark'] ?? false,
//           uploadedAt: DateTime.parse(photoData['uploaded_at']),
//           moderatedAt: photoData['moderated_at'] != null
//               ? DateTime.parse(photoData['moderated_at'])
//               : null,
//           moderatorId: photoData['moderator_id'],
//           rejectionReason: photoData['rejection_reason'],
//           displayOrder: photoData['display_order'],
//         );
//
//         await _objectBox.savePhoto(photoEntity);
//       }
//     } catch (e) {
//       debugPrint('⚠️ Error loading photos: $e');
//       // Ne pas bloquer le workflow si les photos échouent
//     }
//   }
//
//   // ════════════════════════════════════════════════════════════════
//   // 🎯 DÉTERMINATION DU STATUT - FIX: toujours notifier
//   // ════════════════════════════════════════════════════════════════
//
//   Future<void> _determineAuthStatus() async {
//     if (_currentUser == null) {
//       _status = AuthStatus.unauthenticated;
//       notifyListeners(); // ✅ FIX: Notifier systématiquement
//       return;
//     }
//
//     // ✅ FIX: Pour admin/moderator, toujours authenticated
//     if (_currentUser!.role == 'admin' || _currentUser!.role == 'moderator') {
//       _status = AuthStatus.authenticated;
//       notifyListeners(); // ✅ FIX: Notifier avant return
//       debugPrint('✅ Status determined: authenticated (${_currentUser!.role})');
//       return;
//     }
//
//     // Vérifier si le profil est complet (pour users normaux)
//     if (_currentUser!.profileCompleted) {
//       _status = AuthStatus.authenticated;
//       notifyListeners(); // ✅ FIX: Notifier avant return
//       debugPrint('✅ Status determined: authenticated (profile completed)');
//       return;
//     }
//
//     // Profil incomplet : vérifier si skip
//     final hasSkipped = await hasSkippedCompletion();
//
//     if (hasSkipped) {
//       _status = AuthStatus.authenticated; // Skip = accès autorisé
//     } else {
//       _status = AuthStatus.profileIncomplete; // Pas skip = proposer completion
//     }
//
//     notifyListeners(); // ✅ Déjà présent ici
//     debugPrint('✅ Status determined: $_status');
//   }
//
//   // ════════════════════════════════════════════════════════════════
//   // 🔄 RELOAD USER
//   // ════════════════════════════════════════════════════════════════
//
//   Future<void> reloadCurrentUser() async {
//     if (_currentUser == null) {
//       debugPrint('❌ reloadCurrentUser: No current user');
//       return;
//     }
//
//     final userId = _currentUser!.userId;
//     debugPrint('🔄 Reloading user: $userId');
//
//     try {
//       await _loadUserFromSupabase(userId);
//       debugPrint('✅ User reloaded successfully');
//     } catch (e, stack) {
//       debugPrint('❌ reloadCurrentUser error: $e');
//       debugPrint('Stack: $stack');
//       rethrow;
//     }
//   }
//
//   // ════════════════════════════════════════════════════════════════
//   // 🔧 HELPERS - Skip, Session, etc. (inchangés)
//   // ════════════════════════════════════════════════════════════════
//
//   Future<bool> hasSkippedCompletion() async {
//     if (_currentUser == null) return false;
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getBool('${_keyProfileSkipped}_${_currentUser!.userId}') ??
//         false;
//   }
//
//   Future<bool> skipProfileCompletion() async {
//     if (_currentUser == null) return false;
//
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final now = DateTime.now();
//
//       await prefs.setBool(
//         '${_keyProfileSkipped}_${_currentUser!.userId}',
//         true,
//       );
//       await prefs.setInt(
//         '${_keySkippedAt}_${_currentUser!.userId}',
//         now.millisecondsSinceEpoch,
//       );
//
//       _status = AuthStatus.authenticated;
//       notifyListeners();
//
//       return true;
//     } catch (e) {
//       debugPrint('❌ Skip error: $e');
//       return false;
//     }
//   }
//
//   Future<void> signOut() async {
//     debugPrint('════════════════════════════════════════');
//     debugPrint('🔵 SIGNOUT START');
//     debugPrint('════════════════════════════════════════');
//
//     try {
//       // ✅ ÉTAPE 1 : Déconnexion Supabase
//       await _supabase.auth.signOut();
//       debugPrint('✅ Supabase signOut done');
//
//       // ✅ ÉTAPE 2 : Clear local session
//       await _clearLocalSession();
//       debugPrint('✅ Local session cleared');
//
//       // ✅ ÉTAPE 3 : Stop session management
//       _stopSessionManagement();
//       debugPrint('✅ Session management stopped');
//
//       // ✅ ÉTAPE 4 : Reset AuthProvider state
//       _currentUser = null;
//       _errorMessage = null;
//       _status = AuthStatus.unauthenticated;
//       debugPrint('✅ AuthProvider state reset');
//
//       // ✅ ÉTAPE 5 : Clear rate limiter (si utilisé)
//       if (_rateLimiter != null) {
//         await _rateLimiter!.clear();
//         debugPrint('✅ Rate limiter cleared');
//       }
//
//       // ✅ ÉTAPE 6 : Notify listeners AVANT de reset les autres providers
//       notifyListeners();
//
//       debugPrint('✅ SIGNOUT SUCCESS');
//       debugPrint('════════════════════════════════════════');
//     } catch (e, stack) {
//       debugPrint('❌ SIGNOUT ERROR: $e');
//       debugPrint('Stack: $stack');
//
//       // Forcer le reset même en cas d'erreur
//       _currentUser = null;
//       _status = AuthStatus.unauthenticated;
//       notifyListeners();
//     }
//   }
//
//   Future<bool> resetPassword(String email) async {
//     try {
//       await _supabase.auth.resetPasswordForEmail(email);
//       return true;
//     } catch (e) {
//       _errorMessage = 'Erreur: $e';
//       return false;
//     }
//   }
//
//   // ════════════════════════════════════════════════════════════════
//   // 🔧 SESSION MANAGEMENT (inchangé)
//   // ════════════════════════════════════════════════════════════════
//
//   void _startSessionManagement() {
//     _stopSessionManagement();
//     _sessionTimer = Timer.periodic(_refreshBuffer, (_) async {
//       await _validateAndRefreshSession();
//     });
//     _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
//       await _updateLastActive();
//     });
//   }
//
//   void _stopSessionManagement() {
//     _sessionTimer?.cancel();
//     _heartbeatTimer?.cancel();
//     _sessionTimer = null;
//     _heartbeatTimer = null;
//   }
//
//   Future<void> _validateAndRefreshSession() async {
//     try {
//       final session = _supabase.auth.currentSession;
//       if (session == null) {
//         await signOut();
//         return;
//       }
//
//       final expiresAt = DateTime.fromMillisecondsSinceEpoch(
//         (session.expiresAt ?? 0) * 1000,
//       );
//       if (DateTime.now().isAfter(expiresAt.subtract(_refreshBuffer))) {
//         await _supabase.auth.refreshSession();
//       }
//     } catch (e) {
//       debugPrint('Session refresh error: $e');
//     }
//   }
//
//   Future<void> _updateLastActive() async {
//     if (_currentUser == null) return;
//     try {
//       await _supabase
//           .from('profiles')
//           .update({'last_active_at': DateTime.now().toIso8601String()})
//           .eq('id', _currentUser!.userId);
//     } catch (e) {
//       debugPrint('Last active update error: $e');
//     }
//   }
//
//   Future<void> _initAuth() async {
//     _status = AuthStatus.loading;
//     notifyListeners();
//
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final hasSession = prefs.getBool('has_active_session') ?? false;
//
//       if (hasSession) {
//         final session = _supabase.auth.currentSession;
//         if (session != null) {
//           await _loadUserFromLocal(session.user.id);
//           await _validateAndRefreshSession();
//           _startSessionManagement();
//         } else {
//           await _clearLocalSession();
//           _status = AuthStatus.unauthenticated;
//         }
//       } else {
//         _status = AuthStatus.unauthenticated;
//       }
//     } catch (e) {
//       _errorMessage = 'Erreur d\'initialisation: $e';
//       _status = AuthStatus.error;
//       debugPrint('Init auth error: $e');
//     }
//
//     notifyListeners();
//     _listenToAuthChanges();
//   }
//
//   void _listenToAuthChanges() {
//     _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
//       final event = data.event;
//       final session = data.session;
//
//       if (event == AuthChangeEvent.signedIn && session != null) {
//         _handleSignIn(session);
//       } else if (event == AuthChangeEvent.signedOut) {
//         _handleSignOut();
//       } else if (event == AuthChangeEvent.tokenRefreshed && session != null) {
//         _handleTokenRefresh(session);
//       } else if (event == AuthChangeEvent.userUpdated && session != null) {
//         if (session.user.emailConfirmedAt != null &&
//             _status == AuthStatus.emailVerificationPending) {
//           _handleSignIn(session);
//         }
//       }
//     });
//   }
//
//   Future<void> _handleSignIn(Session session) async {
//     await _loadUserFromSupabase(session.user.id);
//     _startSessionManagement();
//   }
//
//   void _handleSignOut() async {
//     await _clearLocalSession();
//     _stopSessionManagement();
//     _status = AuthStatus.unauthenticated;
//     _currentUser = null;
//     notifyListeners();
//   }
//
//   Future<void> _handleTokenRefresh(Session session) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('access_token', session.accessToken);
//     final expiresAt =
//         session.expiresAt ??
//         DateTime.now().add(_sessionDuration).millisecondsSinceEpoch ~/ 1000;
//     await prefs.setInt('token_expires_at', expiresAt);
//   }
//
//   Future<void> _loadUserFromLocal(String userId) async {
//     _currentUser = await _objectBox.getUser(userId);
//     await _determineAuthStatus();
//   }
//
//   Future<void> _clearLocalSession() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//
//       // ✅ Clear toutes les clés liées à l'auth
//       await prefs.remove('has_active_session');
//       await prefs.remove('access_token');
//       await prefs.remove('token_expires_at');
//
//       // ✅ Clear les clés de skip profile completion
//       final keys = prefs.getKeys();
//       for (final key in keys) {
//         if (key.startsWith(_keyProfileSkipped) ||
//             key.startsWith(_keySkippedAt) ||
//             key.startsWith(_keyLastReminder)) {
//           await prefs.remove(key);
//         }
//       }
//
//       debugPrint('✅ SharedPreferences cleared');
//     } catch (e) {
//       debugPrint('⚠️ Clear session error: $e');
//     }
//   }
//
//   UserEntity _mapToUserEntity(Map<String, dynamic> data) {
//     String _listToJson(dynamic value) {
//       if (value == null) return '[]';
//       if (value is List) return jsonEncode(value);
//       if (value is String) {
//         try {
//           jsonDecode(value);
//           return value;
//         } catch (e) {
//           return '[]';
//         }
//       }
//       return '[]';
//     }
//
//     return UserEntity(
//       userId: data['id'] ?? const Uuid().v4(),
//       email: data['email'] ?? '',
//       fullName: data['full_name'],
//       dateOfBirth: data['date_of_birth'] != null
//           ? DateTime.tryParse(data['date_of_birth'])
//           : null,
//       gender: data['gender'],
//       lookingFor: data['looking_for'],
//       bio: data['bio'],
//       profileCompleted: data['profile_completed'] ?? false,
//       completionPercentage: data['completion_percentage'] ?? 0,
//       occupation: data['occupation'],
//       interestsJson: _listToJson(data['interests']),
//       heightCm: data['height_cm'],
//       education: data['education'],
//       relationshipStatus: data['relationship_status'],
//       socialLinksJson: data['social_links'] != null
//           ? jsonEncode(data['social_links'])
//           : '[]',
//       city: data['city'],
//       country: data['country'],
//       latitude: data['latitude']?.toDouble(),
//       longitude: data['longitude']?.toDouble(),
//       role: data['role'] ?? 'user',
//       lastActiveAt: data['last_active_at'] != null
//           ? DateTime.tryParse(data['last_active_at'])
//           : null,
//       createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
//       updatedAt: DateTime.tryParse(data['updated_at'] ?? '') ?? DateTime.now(),
//       needsSync: false,
//     );
//   }
//
//   // Email verification
//   Future<bool> resendVerificationEmail() async {
//     try {
//       final user = _supabase.auth.currentUser;
//       if (user == null) return false;
//
//       await _supabase.auth.resend(type: OtpType.signup, email: user.email!);
//       return true;
//     } catch (e) {
//       debugPrint('❌ Resend verification error: $e');
//       _errorMessage = 'Erreur lors de l\'envoi: $e';
//       return false;
//     }
//   }
//
//   Future<bool> checkEmailVerification() async {
//     try {
//       final session = await _supabase.auth.refreshSession();
//       final user = session.user;
//
//       if (user == null) return false;
//
//       if (user.emailConfirmedAt != null) {
//         await _loadUserFromSupabase(user.id);
//         return true;
//       }
//
//       return false;
//     } catch (e) {
//       debugPrint('❌ Check verification error: $e');
//       return false;
//     }
//   }
//
//   // lib/providers/auth_provider.dart - FIX SUPPRESSION TABLES
//
//   /// 🔴 SUPPRESSION DÉFINITIVE DU COMPTE
//   Future<bool> deleteAccount({String? reason}) async {
//     if (_currentUser == null) return false;
//
//     debugPrint('════════════════════════════════════════');
//     debugPrint('🔴 ACCOUNT DELETION START');
//     debugPrint('════════════════════════════════════════');
//
//     try {
//       final userId = _currentUser!.userId;
//
//       // ✅ ÉTAPE 1 : Supprimer toutes les photos du storage
//       debugPrint('🗑️ Step 1: Deleting photos from storage...');
//       try {
//         final photos = await _objectBox.getUserPhotos(userId);
//         for (final photo in photos) {
//           if (photo.remotePath != null) {
//             try {
//               final uri = Uri.parse(photo.remotePath!);
//               final segments = uri.pathSegments;
//               final bucketIndex = segments.indexOf('profiles');
//               if (bucketIndex != -1) {
//                 final path = segments.sublist(bucketIndex + 1).join('/');
//                 await _supabase.storage.from('profiles').remove([path]);
//                 debugPrint('  ✓ Deleted: $path');
//               }
//             } catch (e) {
//               debugPrint('  ⚠️ Storage delete error: $e');
//             }
//           }
//         }
//       } catch (e) {
//         debugPrint('  ⚠️ Photos cleanup error: $e');
//       }
//
//       // ✅ ÉTAPE 2 : Supprimer de toutes les tables (SAFE MODE)
//       debugPrint('🗑️ Step 2: Deleting from database tables...');
//
//       // Helper pour supprimer en toute sécurité
//       Future<void> _safeDelete(String table, String condition) async {
//         try {
//           if (condition.contains('or(')) {
//             // Pour les OR conditions
//             final parts = condition
//                 .replaceAll('or(', '')
//                 .replaceAll(')', '')
//                 .split(',');
//             await _supabase.from(table).delete().or(parts.join(','));
//           } else {
//             // Pour les EQ conditions simples
//             final parts = condition.split('.eq.');
//             await _supabase.from(table).delete().eq(parts[0], parts[1]);
//           }
//           debugPrint('  ✓ $table deleted');
//         } catch (e) {
//           if (e.toString().contains('PGRST205') ||
//               e.toString().contains('Could not find the table')) {
//             debugPrint('  ⊘ $table table not found (skipped)');
//           } else {
//             debugPrint('  ⚠️ $table delete error: $e');
//           }
//         }
//       }
//
//       // Supprimer dans l'ordre (du moins au plus important)
//       await _safeDelete('notifications', 'user_id.eq.$userId');
//       await _safeDelete(
//         'matches',
//         'or(user_id_1.eq.$userId,user_id_2.eq.$userId)',
//       );
//       await _safeDelete('photos', 'user_id.eq.$userId');
//       await _safeDelete('preferences', 'user_id.eq.$userId');
//
//       // ✅ ÉTAPE 3 : Logger la raison (analytics - optionnel)
//       if (reason != null) {
//         try {
//           await _supabase.from('account_deletions').insert({
//             'user_id': userId,
//             'reason': reason,
//             'deleted_at': DateTime.now().toIso8601String(),
//           });
//           debugPrint('  ✓ Analytics logged');
//         } catch (e) {
//           debugPrint('  ⊘ Analytics table not found (skipped)');
//         }
//       }
//
//       // ✅ ÉTAPE 4 : Supprimer le profil
//       await _supabase.from('profiles').delete().eq('id', userId);
//       debugPrint('  ✓ Profile deleted');
//
//       // ✅ ÉTAPE 5 : Supprimer de Auth
//       try {
//         await _supabase.rpc('delete_user');
//         debugPrint('  ✓ Auth user deleted');
//       } catch (e) {
//         if (e.toString().contains('PGRST202')) {
//           // Function not found - fallback
//           debugPrint('  ⚠️ RPC delete_user not found, using admin API...');
//           // Note: L'admin API n'est accessible que côté serveur
//           // On continue quand même (le RLS empêchera les accès futurs)
//         } else {
//           rethrow;
//         }
//       }
//
//       // ✅ ÉTAPE 6 : Cleanup local
//       await _objectBox.deleteUser(userId);
//       await _clearLocalSession();
//       _stopSessionManagement();
//       debugPrint('  ✓ Local data cleared');
//
//       _currentUser = null;
//       _status = AuthStatus.accountDeleted;
//       notifyListeners();
//
//       debugPrint('✅ ACCOUNT DELETION SUCCESS');
//       debugPrint('════════════════════════════════════════');
//       return true;
//     } catch (e, stack) {
//       debugPrint('❌ ACCOUNT DELETION FAILED: $e');
//       debugPrint('Stack: $stack');
//       _errorMessage = 'Erreur de suppression: $e';
//       notifyListeners();
//       return false;
//     }
//   }
//
//   @override
//   void dispose() {
//     _authSubscription?.cancel();
//     _stopSessionManagement();
//     super.dispose();
//   }
// }
