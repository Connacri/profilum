// lib/services/auth_router.dart - ✅ ROUTAGE BASÉ SUR RÔLE + EMAIL

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🔐 Service de routage basé sur authentification, email et rôle
class AuthRouter {
  final SupabaseClient _supabase;

  AuthRouter(this._supabase);

  /// Obtenir la route initiale selon l'état de l'utilisateur
  Future<String> getInitialRoute() async {
    try {
      debugPrint('🔍 AuthRouter - Checking initial route...');

      // ═══════════════════════════════════════════════════════════
      // 1️⃣ VÉRIFIER SI UTILISATEUR CONNECTÉ
      // ═══════════════════════════════════════════════════════════
      final user = _supabase.auth.currentUser;

      if (user == null) {
        debugPrint('🔒 No user logged in → /login');
        return '/login';
      }

      debugPrint('✅ User logged in: ${user.id}');
      debugPrint('   - Email: ${user.email}');

      // ═══════════════════════════════════════════════════════════
      // 2️⃣ VÉRIFIER SI EMAIL CONFIRMÉ
      // ═══════════════════════════════════════════════════════════
      final emailConfirmed = user.emailConfirmedAt != null;

      debugPrint('📧 Email confirmation:');
      debugPrint('   - Confirmed: $emailConfirmed');
      debugPrint('   - ConfirmedAt: ${user.emailConfirmedAt}');

      if (!emailConfirmed) {
        debugPrint('⏳ Email not confirmed → /email-verification');
        return '/email-verification';
      }

      // ═══════════════════════════════════════════════════════════
      // 3️⃣ RÉCUPÉRER LE PROFIL ET LE RÔLE
      // ═══════════════════════════════════════════════════════════
      final profile = await _supabase
          .from('profiles')
          .select('role, profile_completed, profile_completion_skipped')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        debugPrint('⚠️ No profile found → /profile-completion');
        return '/profile-completion';
      }

      final role = profile['role'] as String? ?? 'user';
      final isCompleted = profile['profile_completed'] as bool? ?? false;
      final isSkipped = profile['profile_completion_skipped'] as bool? ?? false;

      debugPrint('👤 Profile info:');
      debugPrint('   - Role: $role');
      debugPrint('   - Completed: $isCompleted');
      debugPrint('   - Skipped: $isSkipped');

      // ═══════════════════════════════════════════════════════════
      // 4️⃣ ROUTER SELON LE RÔLE
      // ═══════════════════════════════════════════════════════════

      // ✅ ADMIN → Dashboard admin
      if (role == 'admin') {
        debugPrint('👑 Admin user → /admin');
        return '/admin';
      }

      // ✅ MODERATEUR → Dashboard modération
      if (role == 'moderator') {
        debugPrint('🛡️ Moderator user → /moderator');
        return '/moderator';
      }

      // ✅ UTILISATEUR NORMAL
      // Vérifier si profil complété ou passé
      if (!isCompleted && !isSkipped) {
        debugPrint('📝 Profile incomplete → /profile-completion');
        return '/profile-completion';
      }

      debugPrint('🎉 Regular user with valid profile → /home');
      return '/home';

    } catch (e, stack) {
      debugPrint('❌ Error in AuthRouter: $e');
      debugPrint('Stack: $stack');
      return '/login';
    }
  }

  /// Vérifier si l'utilisateur peut accéder à une route
  Future<bool> canAccess(String route) async {
    try {
      final user = _supabase.auth.currentUser;

      // Routes publiques
      if (route == '/login' || 
          route == '/register' || 
          route == '/email-verification') {
        return true;
      }

      // Utilisateur non connecté
      if (user == null) {
        return false;
      }

      // Email non confirmé → seulement /email-verification
      final emailConfirmed = user.emailConfirmedAt != null;
      if (!emailConfirmed) {
        return route == '/email-verification';
      }

      // Récupérer le rôle
      final profile = await _supabase
          .from('profiles')
          .select('role, profile_completed, profile_completion_skipped')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        return route == '/profile-completion';
      }

      final role = profile['role'] as String? ?? 'user';
      final isCompleted = profile['profile_completed'] as bool? ?? false;
      final isSkipped = profile['profile_completion_skipped'] as bool? ?? false;

      // Routes admin
      if (route.startsWith('/admin')) {
        return role == 'admin';
      }

      // Routes moderator
      if (route.startsWith('/moderator')) {
        return role == 'moderator' || role == 'admin';
      }

      // Route profile-completion toujours accessible
      if (route == '/profile-completion') {
        return true;
      }

      // Routes utilisateur normales
      // Nécessitent profil complété ou passé
      return isCompleted || isSkipped;

    } catch (e) {
      debugPrint('❌ Error checking access: $e');
      return false;
    }
  }

  /// Obtenir le label du rôle pour affichage
  String getRoleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'Administrateur';
      case 'moderator':
        return 'Modérateur';
      case 'user':
      default:
        return 'Utilisateur';
    }
  }

  /// Obtenir l'icône du rôle
  IconData getRoleIcon(String? role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'moderator':
        return Icons.shield;
      case 'user':
      default:
        return Icons.person;
    }
  }

  /// Stream pour écouter les changements d'authentification
  Stream<String> watchAuthState() async* {
    await for (final authState in _supabase.auth.onAuthStateChange) {
      if (authState.session == null) {
        yield '/login';
      } else {
        final route = await getInitialRoute();
        yield route;
      }
    }
  }

  /// Vérifier si l'utilisateur doit être encouragé à compléter son profil
  Future<bool> shouldShowCompletionNotification() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final profile = await _supabase
          .from('profiles')
          .select('role, profile_completed, profile_completion_skipped')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) return false;

      // Ne pas afficher pour admin/moderator
      final role = profile['role'] as String? ?? 'user';
      if (role == 'admin' || role == 'moderator') {
        return false;
      }

      final isCompleted = profile['profile_completed'] as bool? ?? false;
      final isSkipped = profile['profile_completion_skipped'] as bool? ?? false;

      // Afficher notification si profil passé mais pas complété
      return isSkipped && !isCompleted;

    } catch (e) {
      debugPrint('❌ Error checking notification: $e');
      return false;
    }
  }
}
