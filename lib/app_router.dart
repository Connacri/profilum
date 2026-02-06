// ═══════════════════════════════════════════════════════════════════
// 🛣️ APP ROUTER OPTIMISÉ - GESTION INTELLIGENTE DES RÔLES
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../tami/admin_auth_provider_complete.dart';
import 'claude/auth_provider_optimized.dart';
import 'screens/email_verification_screen.dart';

// ═══════════════════════════════════════════════════════════════════
// 📋 ROUTES CENTRALISÉES
// ═══════════════════════════════════════════════════════════════════

class AppRoutes {
  // Public
  static const String splash = '/';
  static const String welcome = '/welcome';

  // Auth commune
  static const String emailVerification = '/email-verification';

  // User
  static const String userAuth = '/auth';
  static const String userHome = '/home';

  // Admin
  static const String adminLogin = '/admin/login';
  static const String adminDashboard = '/admin/dashboard';

  // Moderator (futur)
  static const String moderatorLogin = '/moderator/login';
  static const String moderatorDashboard = '/moderator/dashboard';
}

// ═══════════════════════════════════════════════════════════════════
// 🛡️ ROUTER DELEGATE PRINCIPAL
// ═══════════════════════════════════════════════════════════════════

class AppRouterDelegate extends RouterDelegate<AppRoutePath>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppRoutePath> {

  @override
  final GlobalKey<NavigatorState> navigatorKey;

  final AuthProvider authProvider;
  final AdminAuthProvider adminAuthProvider;

  AppRouterDelegate({
    required this.authProvider,
    required this.adminAuthProvider,
  }) : navigatorKey = GlobalKey<NavigatorState>() {
    authProvider.addListener(notifyListeners);
    adminAuthProvider.addListener(notifyListeners);
  }

  @override
  AppRoutePath get currentConfiguration {
    // Retourner la route actuelle pour deep linking
    return AppRoutePath.home();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: _buildPages(),
      onPopPage: (route, result) {
        if (!route.didPop(result)) return false;
        notifyListeners();
        return true;
      },
    );
  }

  List<Page> _buildPages() {
    // ═══════════════════════════════════════════════════════════════
    // 🔍 DÉTECTION DU RÔLE ET DE L'ÉTAT
    // ═══════════════════════════════════════════════════════════════

    // 1. Loading initial
    if (authProvider.status == AuthStatus.initial) {
      return [_buildSplashPage()];
    }

    // 2. Admin authentifié
    if (adminAuthProvider.isAuthenticated) {
      return _buildAdminPages();
    }

    // 3. User authentifié
    if (authProvider.status == AuthStatus.authenticated) {
      return _buildUserPages();
    }

    // 4. Email non vérifié
    if (authProvider.status == AuthStatus.emailVerificationPending) {
      return [_buildEmailVerificationPage()];
    }

    // 5. Profil incomplet
    if (authProvider.status == AuthStatus.profileIncomplete) {
      return [_buildProfileCompletionPage()];
    }

    // 6. Non authentifié (default)
    return [_buildWelcomePage()];
  }

  // ═══════════════════════════════════════════════════════════════
  // 📄 CONSTRUCTION DES PAGES
  // ═══════════════════════════════════════════════════════════════

  MaterialPage _buildSplashPage() {
    return const MaterialPage(
      key: ValueKey('SplashPage'),
      child: SplashScreen(),
    );
  }

  MaterialPage _buildWelcomePage() {
    return const MaterialPage(
      key: ValueKey('WelcomePage'),
      child: WelcomeHomeScreen(),
    );
  }

  MaterialPage _buildEmailVerificationPage() {
    return const MaterialPage(
      key: ValueKey('EmailVerificationPage'),
      child: EmailVerificationScreen(),
    );
  }

  MaterialPage _buildProfileCompletionPage() {
    return const MaterialPage(
      key: ValueKey('ProfileCompletionPage'),
      child: ProfileCompletionScreen(),
    );
  }

  List<Page> _buildUserPages() {
    return [
      const MaterialPage(
        key: ValueKey('UserHomePage'),
        child: HomeScreen(),
      ),
    ];
  }

  List<Page> _buildAdminPages() {
    return [
      const MaterialPage(
        key: ValueKey('AdminDashboardPage'),
        child: AdminDashboardScreen(),
      ),
    ];
  }

  @override
  Future<void> setNewRoutePath(AppRoutePath configuration) async {
    // Gérer les deep links
  }

  @override
  void dispose() {
    authProvider.removeListener(notifyListeners);
    adminAuthProvider.removeListener(notifyListeners);
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════
// 🧭 ROUTE INFORMATION PARSER
// ═══════════════════════════════════════════════════════════════════

class AppRouteInformationParser extends RouteInformationParser<AppRoutePath> {
  @override
  Future<AppRoutePath> parseRouteInformation(
      RouteInformation routeInformation,
      ) async {
    final uri = Uri.parse(routeInformation.location ?? '/');

    // Admin routes
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'admin') {
      if (uri.pathSegments.length > 1) {
        if (uri.pathSegments[1] == 'dashboard') {
          return AppRoutePath.adminDashboard();
        }
      }
      return AppRoutePath.adminLogin();
    }

    // User routes
    if (uri.pathSegments.isEmpty) {
      return AppRoutePath.home();
    }

    return AppRoutePath.unknown();
  }

  @override
  RouteInformation? restoreRouteInformation(AppRoutePath configuration) {
    if (configuration.isUnknown) {
      return const RouteInformation(location: '/404');
    }
    if (configuration.isAdminDashboard) {
      return const RouteInformation(location: '/admin/dashboard');
    }
    if (configuration.isAdminLogin) {
      return const RouteInformation(location: '/admin/login');
    }
    return const RouteInformation(location: '/');
  }
}

// ═══════════════════════════════════════════════════════════════════
// 🗺️ ROUTE PATH CONFIGURATION
// ═══════════════════════════════════════════════════════════════════

class AppRoutePath {
  final bool isUnknown;
  final bool isAdminLogin;
  final bool isAdminDashboard;

  AppRoutePath.home()
      : isUnknown = false,
        isAdminLogin = false,
        isAdminDashboard = false;

  AppRoutePath.adminLogin()
      : isUnknown = false,
        isAdminLogin = true,
        isAdminDashboard = false;

  AppRoutePath.adminDashboard()
      : isUnknown = false,
        isAdminLogin = false,
        isAdminDashboard = true;

  AppRoutePath.unknown()
      : isUnknown = true,
        isAdminLogin = false,
        isAdminDashboard = false;
}

// ═══════════════════════════════════════════════════════════════════
// 📱 PLACEHOLDERS SCREENS (À REMPLACER)
// ═══════════════════════════════════════════════════════════════════

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class WelcomeHomeScreen extends StatelessWidget {
  const WelcomeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome'),
            ElevatedButton(
              onPressed: () {
                // Navigate to auth
              },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileCompletionScreen extends StatelessWidget {
  const ProfileCompletionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Complete your profile'),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Home'),
      ),
    );
  }
}

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Admin Dashboard'),
      ),
    );
  }
}