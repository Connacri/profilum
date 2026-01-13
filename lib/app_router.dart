// lib/app_router.dart - SYSTÈME DE ROUTING COMPLET
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_screen.dart';
import 'providers/auth_provider.dart';
import 'screens/admin_dashboard.dart';
import 'screens/home_screen.dart';
import 'screens/moderator_panel_complete.dart';
import 'screens/profile_completion_screen.dart';

// ════════════════════════════════════════════════════════════════
// 📱 EMAIL VERIFICATION SCREEN
// ════════════════════════════════════════════════════════════════

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _checkTimer;
  bool _isChecking = false;
  bool _isResending = false;
  bool _emailSent = false;
  int _checkCount = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startAutoCheck();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startAutoCheck() {
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_isChecking) {
        _checkEmailVerification();
      }
    });
  }

  Future<void> _checkEmailVerification() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      _checkCount++;
    });

    final authProvider = context.read<AuthProvider>();
    final verified = await authProvider.checkEmailVerification();

    if (mounted) {
      setState(() => _isChecking = false);

      if (verified) {
        _checkTimer?.cancel();
        _showSuccessAndRedirect();
      }
    }
  }

  void _showSuccessAndRedirect() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 16),
            Text(
              'Email vérifié !',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connexion automatique...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _resendEmail() async {
    if (_isResending) return;

    setState(() => _isResending = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resendVerificationEmail();

    if (mounted) {
      setState(() {
        _isResending = false;
        _emailSent = success;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Email de vérification renvoyé !')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _emailSent = false);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              authProvider.errorMessage ?? 'Erreur lors de l\'envoi',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final userEmail = authProvider.currentUser?.email ?? 'votre email';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.1),
              theme.colorScheme.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.email_outlined,
                        size: 60,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Vérifiez votre email',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      userEmail,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text(
                                    '1',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Consultez votre boîte mail',
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text(
                                    '2',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Cliquez sur le lien de vérification',
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Connexion automatique !',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isChecking)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Vérification en cours...',
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _isResending ? null : _resendEmail,
                    icon: _isResending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _emailSent ? Icons.check_circle : Icons.refresh,
                            color: _emailSent ? Colors.green : null,
                          ),
                    label: Text(
                      _emailSent ? 'Email envoyé !' : 'Renvoyer l\'email',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      side: BorderSide(
                        color: _emailSent
                            ? Colors.green
                            : theme.colorScheme.primary,
                      ),
                      foregroundColor: _emailSent
                          ? Colors.green
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pensez à vérifier vos spams',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_checkCount > 0)
                    Text(
                      'Vérifications: $_checkCount',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[400],
                        fontSize: 10,
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
// 🎯 ROUTER CONFIGURATION
// ════════════════════════════════════════════════════════════════

enum AppRoute {
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
// 🎯 ROUTER DELEGATE
// ════════════════════════════════════════════════════════════════

class AppRouter extends RouterDelegate<AppRouteConfiguration>
    with
        ChangeNotifier,
        PopNavigatorRouterDelegateMixin<AppRouteConfiguration> {
  @override
  final GlobalKey<NavigatorState> navigatorKey;

  final AuthProvider authProvider;

  AppRouter(this.authProvider) : navigatorKey = GlobalKey<NavigatorState>() {
    authProvider.addListener(notifyListeners);
  }

  @override
  void dispose() {
    authProvider.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  AppRouteConfiguration? get currentConfiguration {
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
        // Check role pour admin/moderator
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

    debugPrint('🔵 AppRouter build: status=$status, role=${user?.role}');

    return Navigator(
      key: navigatorKey,
      pages: [
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
          // Admin Dashboard
          if (user?.role == 'admin')
            const MaterialPage(child: AdminDashboardScreen())
          // Moderator Panel
          else if (user?.role == 'moderator')
            const MaterialPage(child: ModeratorPanelScreen())
          // Home (Regular User)
          else
            MaterialPage(child: HomeScreen(gender: user?.gender)),
        ],
      ],
      onPopPage: (route, result) {
        if (!route.didPop(result)) {
          return false;
        }

        // Ne pas permettre de retour arrière sur auth/email verification
        if (status == AuthStatus.unauthenticated ||
            status == AuthStatus.emailVerificationPending) {
          return false;
        }

        return true;
      },
    );
  }

  @override
  Future<void> setNewRoutePath(AppRouteConfiguration configuration) async {
    // Cette méthode est appelée lors de la navigation deep linking
    // Pour l'instant, on ne gère pas le deep linking
    return;
  }
}

// ════════════════════════════════════════════════════════════════
// 🎯 ROUTE INFORMATION PARSER
// ════════════════════════════════════════════════════════════════

class AppRouteInformationParser
    extends RouteInformationParser<AppRouteConfiguration> {
  @override
  Future<AppRouteConfiguration> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = Uri.parse(routeInformation.location ?? '/');

    // Parse deep links si nécessaire
    if (uri.pathSegments.isEmpty) {
      return AppRouteConfiguration(route: AppRoute.auth);
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
      case AppRoute.auth:
        return const RouteInformation(location: '/');
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

// ════════════════════════════════════════════════════════════════
// 🎯 HELPERS
// ════════════════════════════════════════════════════════════════

extension NavigationExtension on BuildContext {
  /// Navigate to a specific route programmatically
  void navigateTo(AppRoute route) {
    // Cette méthode peut être utilisée pour forcer la navigation
    // mais le routing déclaratif gère déjà tout automatiquement
  }
}
