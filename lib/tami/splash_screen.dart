// ═══════════════════════════════════════════════════════════════════
// 🚀 SPLASH SCREEN - ROUTING INTELLIGENT
// ═══════════════════════════════════════════════════════════════════
// Logique de décision: User Guest Mode vs Admin Authentication
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../claude/auth_provider_optimized.dart';
import 'admin_auth_provider_complete.dart';
import 'app_router.dart';
import 'guest_mode_provider.dart';



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

    // Animations
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Démarrer logique de routing
    _initializeApp();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// ═══════════════════════════════════════════════════════════════════
  /// 🔍 LOGIQUE D'INITIALISATION
  /// ═══════════════════════════════════════════════════════════════════
  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    // ═══════════════════════════════════════════════════════════════
    // 1. DÉTECTION ROUTE ADMIN
    // ═══════════════════════════════════════════════════════════════
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isAdminRoute = AppRoutes.isAdminRoute(currentRoute);

    if (isAdminRoute) {
      await _handleAdminRouting();
      return;
    }

    // ═══════════════════════════════════════════════════════════════
    // 2. ROUTING USER NORMAL
    // ═══════════════════════════════════════════════════════════════
    await _handleUserRouting();
  }

  /// ═══════════════════════════════════════════════════════════════════
  /// 👔 ROUTING ADMIN
  /// ═══════════════════════════════════════════════════════════════════
  Future<void> _handleAdminRouting() async {
    final adminProvider = context.read<AdminAuthProvider>();

    // Vérifier si admin déjà authentifié
    await adminProvider.checkAuthStatus();

    if (!mounted) return;

    if (adminProvider.isAuthenticated) {
      // Déjà connecté → Dashboard
      Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
    } else {
      // Pas connecté → Login
      Navigator.pushReplacementNamed(context, AppRoutes.adminLogin);
    }
  }

  /// ═══════════════════════════════════════════════════════════════════
  /// 👤 ROUTING USER NORMAL
  /// ═══════════════════════════════════════════════════════════════════
  Future<void> _handleUserRouting() async {
    final authProvider = context.read<AuthProvider>();
    final guestProvider = context.read<GuestModeProvider>();

    // Charger documents guest
    await guestProvider.loadGuestDocuments();

    if (!mounted) return;

    // Vérifier session utilisateur
    // Note: _initAuth() est déjà appelé dans AuthProvider constructor
    // On attend juste que le status soit déterminé

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Décision de routing selon AuthStatus
    switch (authProvider.status) {
      case AuthStatus.authenticated:
        // Utilisateur connecté avec profil complet
        Navigator.pushReplacementNamed(context, AppRoutes.userHome);
        break;

      case AuthStatus.profileIncomplete:
        // Utilisateur connecté mais profil incomplet
        // Note: La logique de ProfileCompletionScreen existe dans main.dart
        // On redirige vers home qui gérera l'affichage du prompt
        Navigator.pushReplacementNamed(context, AppRoutes.userHome);
        break;

      case AuthStatus.emailVerificationPending:
        // Email non vérifié
        Navigator.pushReplacementNamed(context, AppRoutes.emailVerification);
        break;

      case AuthStatus.unauthenticated:
      case AuthStatus.initial:
      case AuthStatus.error:
      default:
        // Pas de session → Mode Guest par défaut
        Navigator.pushReplacementNamed(context, AppRoutes.welcome);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ═══════════════════════════════════════════════════
                  // LOGO
                  // ═══════════════════════════════════════════════════
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.document_scanner_rounded,
                      size: 64,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ═══════════════════════════════════════════════════
                  // APP NAME
                  // ═══════════════════════════════════════════════════
                  Text(
                    'Profilum',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'EHS Dr Medjbeur Tami',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ═══════════════════════════════════════════════════
                  // LOADING INDICATOR
                  // ═══════════════════════════════════════════════════
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Chargement...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
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

// ═══════════════════════════════════════════════════════════════════
// 🎨 SPLASH SCREEN AVEC GRADIENT (Alternative)
// ═══════════════════════════════════════════════════════════════════

class SplashScreenGradient extends StatelessWidget {
  const SplashScreenGradient({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.health_and_safety_rounded,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              Text(
                'Profilum',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
