// ═══════════════════════════════════════════════════════════════════
// 🛣️ APP ROUTER COMPLET - TOUTES LES ROUTES
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// 📋 DÉFINITION DES ROUTES
// ═══════════════════════════════════════════════════════════════════

class AppRoutes {
  // ═══════════════════════════════════════════════════════════════
  // ROUTES PUBLIQUES
  // ═══════════════════════════════════════════════════════════════
  static const String splash = '/';
  static const String welcome = '/welcome';

  // ═══════════════════════════════════════════════════════════════
  // ROUTES USER
  // ═══════════════════════════════════════════════════════════════
  static const String userAuth = '/auth';
  static const String userHome = '/home';
  static const String emailVerification = '/email-verification';
  static const String profileCompletion = '/profile-completion';
  static const String accountDeleted = '/account-deleted';

  // ═══════════════════════════════════════════════════════════════
  // ROUTES ADMIN
  // ═══════════════════════════════════════════════════════════════
  static const String adminLogin = '/admin/login';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminDocuments = '/admin/documents';
  static const String adminUsers = '/admin/users';
  static const String adminStats = '/admin/stats';

  // ═══════════════════════════════════════════════════════════════
  // ROUTES MODERATOR (FUTUR)
  // ═══════════════════════════════════════════════════════════════
  static const String moderatorLogin = '/moderator/login';
  static const String moderatorDashboard = '/moderator/dashboard';

  // ═══════════════════════════════════════════════════════════════
  // 🔍 HELPERS DE DÉTECTION
  // ═══════════════════════════════════════════════════════════════

  /// Vérifie si une route est une route admin
  static bool isAdminRoute(String? route) {
    if (route == null) return false;
    return route.startsWith('/admin');
  }

  /// Vérifie si une route est une route moderator
  static bool isModeratorRoute(String? route) {
    if (route == null) return false;
    return route.startsWith('/moderator');
  }

  /// Vérifie si une route nécessite une authentification
  static bool requiresAuth(String? route) {
    if (route == null) return false;

    final publicRoutes = [
      splash,
      welcome,
      userAuth,
      adminLogin,
      moderatorLogin,
    ];

    return !publicRoutes.contains(route);
  }
}

// ═══════════════════════════════════════════════════════════════════
// 🧭 NAVIGATION HELPERS
// ═══════════════════════════════════════════════════════════════════

class NavigationHelpers {
  // ═══════════════════════════════════════════════════════════════
  // NAVIGATION USER
  // ═══════════════════════════════════════════════════════════════

  /// Naviguer vers la page d'accueil
  static void navigateToHome(BuildContext context) {
    Navigator.pushReplacementNamed(context, AppRoutes.userHome);
  }

  /// Naviguer vers l'authentification
  static void navigateToAuth(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.userAuth);
  }

  /// Naviguer vers la vérification email
  static void navigateToEmailVerification(BuildContext context) {
    Navigator.pushReplacementNamed(context, AppRoutes.emailVerification);
  }

  /// Naviguer vers la complétion de profil
  static void navigateToProfileCompletion(BuildContext context) {
    Navigator.pushReplacementNamed(context, AppRoutes.profileCompletion);
  }

  /// Naviguer vers welcome et clear stack
  static void navigateToWelcome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.welcome,
          (route) => false,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // NAVIGATION ADMIN
  // ═══════════════════════════════════════════════════════════════

  /// Naviguer vers login admin
  static void navigateToAdminLogin(BuildContext context) {
    Navigator.pushReplacementNamed(context, AppRoutes.adminLogin);
  }

  /// Naviguer vers dashboard admin
  static void navigateToAdminDashboard(BuildContext context) {
    Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
  }

  /// Naviguer vers documents admin
  static void navigateToAdminDocuments(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.adminDocuments);
  }

  // ═══════════════════════════════════════════════════════════════
  // DÉCONNEXION
  // ═══════════════════════════════════════════════════════════════

  /// Déconnexion complète (retour splash)
  static void logout(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.splash,
          (route) => false,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════════

  /// Afficher une confirmation de déconnexion
  static Future<bool> showLogoutConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  /// Afficher un message d'erreur
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Afficher un message de succès
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}