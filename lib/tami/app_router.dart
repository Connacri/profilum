// ═══════════════════════════════════════════════════════════════════
// 🛣️ APP ROUTER - NAVIGATION CONDITIONNELLE (CORRIGÉ)
// ═══════════════════════════════════════════════════════════════════
// Gestion intelligente du routing entre User (Guest) et Admin
// ✅ Toutes les erreurs corrigées
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Screens - User
import '../auth/auth_screen.dart';




// Main screens
import '../main.dart';
import 'admin_auth_provider_complete.dart';
import 'admin_login_screen.dart';
import 'home_screen.dart';
import 'models_unified.dart';
import 'splash_screen.dart';
import 'welcome_home_screen.dart'; // Pour EmailVerificationScreen, AccountDeletedScreen

// ═══════════════════════════════════════════════════════════════════
// 📋 ROUTES CONSTANTS
// ═══════════════════════════════════════════════════════════════════

class AppRoutes {
  // Splash & Common
  static const String splash = '/';

  // User Routes
  static const String welcome = '/welcome';
  static const String userAuth = '/auth';
  static const String userHome = '/home';
  static const String documentScan = '/scan';
  static const String documentDetail = '/document-detail';
  static const String emailVerification = '/email-verification';
  static const String accountDeleted = '/account-deleted';

  // Admin Routes
  static const String adminLogin = '/admin';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminDocuments = '/admin/documents';

  // Guards
  static bool isAdminRoute(String? route) {
    return route?.startsWith('/admin') ?? false;
  }
}

// ═══════════════════════════════════════════════════════════════════
// 🛣️ APP ROUTER
// ═══════════════════════════════════════════════════════════════════

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    debugPrint('🛣️ Navigating to: ${settings.name}');

    switch (settings.name) {
    // ═══════════════════════════════════════════════════════════════
    // SPLASH & COMMON
    // ═══════════════════════════════════════════════════════════════
      case AppRoutes.splash:
        return _buildRoute(const SplashScreen());

    // ═══════════════════════════════════════════════════════════════
    // USER ROUTES
    // ═══════════════════════════════════════════════════════════════
      case AppRoutes.welcome:
        return _buildRoute(const WelcomeHomeScreen());

      case AppRoutes.userAuth:
        return _buildRoute(const AuthScreenAdvanced());

      case AppRoutes.userHome:
        return _buildRoute(const HomeScreen());

      case AppRoutes.documentScan:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          DocumentScanScreen(
            initialType: args?['documentType'] as DocumentType?,
          ),
        );

      case AppRoutes.documentDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        final documentId = args?['documentId'] as String?;

        if (documentId == null) {
          return _buildErrorRoute('Document ID manquant');
        }

        return _buildRoute(
          DocumentDetailScreen(documentId: documentId),
        );

      case AppRoutes.emailVerification:
        return _buildRoute(const EmailVerificationScreen());

      case AppRoutes.accountDeleted:
        return _buildRoute(const AccountDeletedScreen());

    // ═══════════════════════════════════════════════════════════════
    // ADMIN ROUTES
    // ═══════════════════════════════════════════════════════════════
      case AppRoutes.adminLogin:
        return _buildRoute(
          const AdminLoginScreen(),
          isAdmin: true,
        );

      case AppRoutes.adminDashboard:
        return _buildRoute(
          const AdminDashboardScreen(),
          isAdmin: true,
          requiresAuth: true,
        );

      case AppRoutes.adminDocuments:
        return _buildRoute(
          const AdminDocumentsScreen(),
          isAdmin: true,
          requiresAuth: true,
        );

    // ═══════════════════════════════════════════════════════════════
    // DEFAULT / ERROR
    // ═══════════════════════════════════════════════════════════════
      default:
        return _buildErrorRoute('Route non trouvée: ${settings.name}');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🏗️ ROUTE BUILDERS
  // ═══════════════════════════════════════════════════════════════════

  static MaterialPageRoute _buildRoute(
      Widget page, {
        bool isAdmin = false,
        bool requiresAuth = false,
      }) {
    return MaterialPageRoute(
      builder: (context) {
        // Si route admin nécessite auth, on wrappe avec guard
        if (isAdmin && requiresAuth) {
          return AdminAuthGuard(child: page);
        }

        return page;
      },
    );
  }

  static MaterialPageRoute _buildErrorRoute(String message) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Erreur de Navigation',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // ✅ CORRIGÉ: Utilisation de context au lieu de _
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.welcome,
                        (route) => false,
                  );
                },
                child: const Text('Retour à l\'accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 🛡️ ADMIN AUTH GUARD
// ═══════════════════════════════════════════════════════════════════

class AdminAuthGuard extends StatelessWidget {
  final Widget child;

  const AdminAuthGuard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminAuthProvider>();
    final isAuthenticated = adminProvider.isAuthenticated;

    if (!isAuthenticated) {
      // Rediriger vers login admin
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.adminLogin);
      });

      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return child;
  }
}

// ═══════════════════════════════════════════════════════════════════
// 🧭 NAVIGATION HELPERS
// ═══════════════════════════════════════════════════════════════════

class NavigationHelpers {
  /// Naviguer vers la page de scan avec type de document
  static void navigateToScan(
      BuildContext context, {
        required DocumentType documentType,
      }) {
    Navigator.pushNamed(
      context,
      AppRoutes.documentScan,
      arguments: {'documentType': documentType},
    );
  }

  /// Naviguer vers détail document
  static void navigateToDocumentDetail(
      BuildContext context, {
        required String documentId,
      }) {
    Navigator.pushNamed(
      context,
      AppRoutes.documentDetail,
      arguments: {'documentId': documentId},
    );
  }

  /// Navigation admin
  static void navigateToAdminDashboard(BuildContext context) {
    Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
  }

  /// Retour à l'accueil (clear stack)
  static void navigateToWelcome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.welcome,
          (route) => false,
    );
  }

  /// Déconnexion (retour splash)
  static void logout(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.splash,
          (route) => false,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 📄 PLACEHOLDER SCREENS (À remplacer par vrais écrans)
// ═══════════════════════════════════════════════════════════════════

class DocumentScanScreen extends StatelessWidget {
  final DocumentType? initialType;

  const DocumentScanScreen({super.key, this.initialType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scanner ${initialType?.label ?? "Document"}'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.document_scanner_rounded,
              size: 100,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'Écran de scan à implémenter',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Type: ${initialType?.label ?? "Non spécifié"}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DocumentDetailScreen extends StatelessWidget {
  final String documentId;

  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail Document'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_rounded,
              size: 100,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'Détail du document',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ID: $documentId',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminDocumentsScreen extends StatelessWidget {
  const AdminDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents Admin'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 100,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'Liste des documents admin',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'À implémenter avec AdminDocumentsProvider',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}