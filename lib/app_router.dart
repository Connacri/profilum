// lib/app_router.dart - ✅ VERSION AVEC SPLASH SCREEN INTÉGRÉ

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_screen.dart';
import 'claude/auth_provider_optimized.dart';
import 'claude/profile_completion_screen_example.dart';
import 'screens/admin_dashboard.dart';
import 'screens/home_screen.dart';
import 'screens/moderator_panel_complete.dart';
import 'screens/profile_completion_screen.dart';

// ════════════════════════════════════════════════════════════════
// 🎯 ROUTER CONFIGURATION (avec Splash)
// ════════════════════════════════════════════════════════════════

enum AppRoute {
  splash,           // ✅ AJOUT
  auth,
  emailVerification,
  profileCompletion,
  home,
  adminDashboard,
  moderatorPanel,
}

class AppRouteConfiguration {
  final AppRoute route;
  final String? gender;

  AppRouteConfiguration({required this.route, this.gender});
}

// ════════════════════════════════════════════════════════════════
// 🎯 ROUTER DELEGATE (avec Splash)
// ════════════════════════════════════════════════════════════════

class AppRouter extends RouterDelegate<AppRouteConfiguration>
    with
        ChangeNotifier,
        PopNavigatorRouterDelegateMixin<AppRouteConfiguration> {
  @override
  final GlobalKey<NavigatorState> navigatorKey;

  final AuthProvider authProvider;

  // ✅ Flag pour savoir si le splash est terminé
  bool _splashCompleted = false;

  AppRouter(this.authProvider) : navigatorKey = GlobalKey<NavigatorState>() {
    authProvider.addListener(notifyListeners);

    // ✅ Simuler la fin du splash après 2 secondes
    _initSplash();
  }

  void _initSplash() {
    Future.delayed(const Duration(seconds: 2), () {
      _splashCompleted = true;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    authProvider.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  AppRouteConfiguration? get currentConfiguration {
    // ✅ Afficher splash si pas encore terminé
    if (!_splashCompleted) {
      return AppRouteConfiguration(route: AppRoute.splash);
    }

    final status = authProvider.status;
    final user = authProvider.currentUser;

    switch (status) {
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
      case AuthStatus.accountDeleted:
        return AppRouteConfiguration(route: AppRoute.auth);

      case AuthStatus.emailVerificationPending:
        return AppRouteConfiguration(route: AppRoute.emailVerification);

      case AuthStatus.profileIncomplete:
        return AppRouteConfiguration(route: AppRoute.profileCompletion);

      case AuthStatus.authenticated:
        if (user?.role == 'admin') {
          return AppRouteConfiguration(route: AppRoute.adminDashboard);
        } else if (user?.role == 'moderator') {
          return AppRouteConfiguration(route: AppRoute.moderatorPanel);
        }
        return AppRouteConfiguration(
          route: AppRoute.home,
          gender: user?.gender,
        );

      case AuthStatus.initial:
      case AuthStatus.loading:
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = authProvider.status;
    final user = authProvider.currentUser;

    debugPrint('🔵 AppRouter build: splash=$_splashCompleted, status=$status');

    return Navigator(
      key: navigatorKey,
      pages: [
        // ✅ SPLASH SCREEN (Toujours en premier tant que pas terminé)
        if (!_splashCompleted)
          const MaterialPage(child: SplashScreen()),

        // ✅ Reste du flux (identique)
        if (_splashCompleted) ...[
          // Loading
          if (status == AuthStatus.initial || status == AuthStatus.loading)
            const MaterialPage(
              child: Scaffold(body: Center(child: CircularProgressIndicator())),
            ),

          // Auth Screen
          if (status == AuthStatus.unauthenticated ||
              status == AuthStatus.error ||
              status == AuthStatus.accountDeleted)
            const MaterialPage(child: AuthScreenAdvanced()),

          // Email Verification
          if (status == AuthStatus.emailVerificationPending)
            const MaterialPage(child: EmailVerificationScreen()),

          // Profile Completion
          if (status == AuthStatus.profileIncomplete)
            const MaterialPage(child: ProfileCompletionScreen()),

          // Authenticated Routes
          if (status == AuthStatus.authenticated) ...[
            if (user?.role == 'admin')
              const MaterialPage(child: AdminDashboardScreen())
            else if (user?.role == 'moderator')
              const MaterialPage(child: ModeratorPanelScreen())
            else
              MaterialPage(child: HomeScreen(gender: user?.gender)),
          ],
        ],
      ],
      onPopPage: (route, result) {
        if (!route.didPop(result)) {
          return false;
        }

        // Ne pas permettre de retour arrière sur splash/auth/email
        if (!_splashCompleted ||
            status == AuthStatus.unauthenticated ||
            status == AuthStatus.emailVerificationPending) {
          return false;
        }

        return true;
      },
    );
  }

  @override
  Future<void> setNewRoutePath(AppRouteConfiguration configuration) async {
    return;
  }
}

// ════════════════════════════════════════════════════════════════
// 🎨 SPLASH SCREEN STANDALONE (Version Complexe)
// ════════════════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    // ✅ Vous pouvez ajouter ici des vérifications :
    // - Permissions
    // - Mises à jour
    // - Préchargement de données
    _performInitialChecks();
  }

  Future<void> _performInitialChecks() async {
    // Exemple : vérifier permissions, updates, etc.
    await Future.delayed(const Duration(seconds: 1));

    // Aucune navigation ici ! Le router s'en charge automatiquement
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.secondary,
              theme.colorScheme.tertiary,
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo animé
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'P',
                        style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  Text(
                    'Profilum',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Connectez-vous avec authenticité',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Indicateur de chargement stylisé
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Initialisation en cours...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.7),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 📧 EMAIL VERIFICATION SCREEN (conservé)
// ════════════════════════════════════════════════════════════════
// ... (garde ton code existant)

class EmailVerificationScreen extends StatelessWidget {
  const EmailVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Ton code existant
    return const Scaffold(
      body: Center(child: Text('Email Verification')),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 🎯 ROUTE INFORMATION PARSER (conservé)
// ════════════════════════════════════════════════════════════════

class AppRouteInformationParser
    extends RouteInformationParser<AppRouteConfiguration> {
  @override
  Future<AppRouteConfiguration> parseRouteInformation(
      RouteInformation routeInformation,
      ) async {
    final uri = Uri.parse(routeInformation.location ?? '/');

    if (uri.pathSegments.isEmpty) {
      return AppRouteConfiguration(route: AppRoute.splash);
    }

    final path = uri.pathSegments.first;

    switch (path) {
      case 'home':
        return AppRouteConfiguration(route: AppRoute.home);
      case 'admin':
        return AppRouteConfiguration(route: AppRoute.adminDashboard);
      case 'moderator':
        return AppRouteConfiguration(route: AppRoute.moderatorPanel);
      case 'profile-completion':
        return AppRouteConfiguration(route: AppRoute.profileCompletion);
      case 'email-verification':
        return AppRouteConfiguration(route: AppRoute.emailVerification);
      default:
        return AppRouteConfiguration(route: AppRoute.auth);
    }
  }

  @override
  RouteInformation? restoreRouteInformation(
      AppRouteConfiguration configuration,
      ) {
    switch (configuration.route) {
      case AppRoute.splash:
        return const RouteInformation(location: '/');
      case AppRoute.auth:
        return const RouteInformation(location: '/auth');
      case AppRoute.emailVerification:
        return const RouteInformation(location: '/email-verification');
      case AppRoute.profileCompletion:
        return const RouteInformation(location: '/profile-completion');
      case AppRoute.home:
        return const RouteInformation(location: '/home');
      case AppRoute.adminDashboard:
        return const RouteInformation(location: '/admin');
      case AppRoute.moderatorPanel:
        return const RouteInformation(location: '/moderator');
    }
  }
}