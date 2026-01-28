// lib/main.dart - ✅ VERSION COMPLÈTE MIGRÉE SANS OBJECTBOX

import 'package:flutter/material.dart';
import 'package:profilum/tami/admin_auth_provider_complete.dart';
import 'package:provider/provider.dart';

import 'auth/auth_screen.dart';
import 'claude/auth_provider_optimized.dart';
import 'claude/profile_completion_screen_example.dart';
import 'claude/service_locator.dart';

import 'providers/theme_provider.dart';

import 'screens/home_screen.dart';


import 'tami/admin_documents_provider_complete.dart';
import 'tami/document_provider_fixed.dart';
import 'tami/guest_mode_provider.dart';
import 'tami/ocr_provider.dart';
import 'tami/splash_screen.dart';
import 'widgets/auth_rate_limiter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ═══════════════════════════════════════════════════════════════════
  // ✅ INITIALISATION UNIQUE - Remplace Supabase.initialize() + ObjectBox
  // ═══════════════════════════════════════════════════════════════════

  await services.init(
    supabaseUrl: 'https://uuosdbxqegnnwaojqxec.supabase.co',
    supabaseAnonKey:  'sb_publishable_lv4LuXnpZBxLZMw_j-rg_Q_omNBoE5A',
  );
//   await Supabase.initialize(
//     url: 'https://uuosdbxqegnnwaojqxec.supabase.co',
//     anonKey: 'sb_publishable_lv4LuXnpZBxLZMw_j-rg_Q_omNBoE5A',
//     realtimeClientOptions: const RealtimeClientOptions(
//       eventsPerSecond: 10, // Limite les events pour éviter spam
//     ),
//   );
  debugPrint('✅ Services initialized successfully');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ═══════════════════════════════════════════════════════════════
        // 🎨 Theme Provider
        // ═══════════════════════════════════════════════════════════════
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        // ═══════════════════════════════════════════════════════════════
        // ⏱️ Rate Limiter (optionnel)
        // ═══════════════════════════════════════════════════════════════
        ChangeNotifierProvider(create: (_) => AuthRateLimiter()),

        // ═══════════════════════════════════════════════════════════════
        // 🔐 Auth Provider - ✅ SANS ObjectBoxService
        // ═══════════════════════════════════════════════════════════════
        // ═══════════════════════════════════════════════════════════════
        // 👔 ADMIN AUTH PROVIDER
        // ═══════════════════════════════════════════════════════════════
        ChangeNotifierProvider(
          create: (_) => AdminAuthProvider(),
        ),

        // ═══════════════════════════════════════════════════════════════
        // 👤 GUEST MODE PROVIDER (nouveau)
        // ═══════════════════════════════════════════════════════════════
        ChangeNotifierProvider(
          create: (_) => GuestModeProvider(),
        ),

        // ═══════════════════════════════════════════════════════════════
        // 📄 DOCUMENT PROVIDER (avec SupabaseClient)
        // ═══════════════════════════════════════════════════════════════
        ChangeNotifierProvider(
          create: (_) => DocumentProvider(services.supabase),
        ),

        // ═══════════════════════════════════════════════════════════════
        // 📚 ADMIN DOCUMENTS PROVIDER
        // ═══════════════════════════════════════════════════════════════
        ChangeNotifierProvider(
          create: (_) => AdminDocumentsProvider(),
        ),



      ],
      child: Consumer2<ThemeProvider, AuthProvider>(
        builder: (context, themeProvider, authProvider, _) {
          // ✅ Mettre à jour le thème selon le genre de l'user
          if (authProvider.currentUser?.gender != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              themeProvider.setUserGender(authProvider.currentUser!.gender);
            });
          }

          return MaterialApp(
            title: 'Profilum',
            debugShowCheckedModeBanner: false,

            // ✅ Thèmes dynamiques
            theme: themeProvider.getLightTheme(),
            darkTheme: themeProvider.getDarkTheme(),
            themeMode: themeProvider.themeMode,

            // ✅ Navigation selon AuthStatus
            home: const SplashScreen(),//_buildHomeScreen(authProvider),
          );
        },
      ),
    );
  }

  Widget _buildHomeScreen(AuthProvider authProvider) {
    debugPrint('🔍 Auth Status: ${authProvider.status}');

    switch (authProvider.status) {
      case AuthStatus.initial:
      case AuthStatus.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );

      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const AuthScreenAdvanced();

      case AuthStatus.emailVerificationPending:
        return const EmailVerificationScreen();

      case AuthStatus.profileIncomplete:
        return const ProfileCompletionScreen();

      case AuthStatus.authenticated:
        return const HomeScreen();

      case AuthStatus.accountDeleted:
      // Rediriger vers écran de confirmation
        return const AccountDeletedScreen();

      default:
        return const AuthScreenAdvanced();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// 📧 Email Verification Screen
// ═══════════════════════════════════════════════════════════════════

class EmailVerificationScreen extends StatelessWidget {
  const EmailVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.email_outlined,
                size: 100,
                color: theme.colorScheme.primary,
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

              Text(
                'Nous avons envoyé un lien de vérification à votre adresse email.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              FilledButton.icon(
                onPressed: () async {
                  final success = await authProvider.checkEmailVerification();

                  if (!context.mounted) return;

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Email vérifié avec succès !'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Email pas encore vérifié'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Vérifier'),
              ),

              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: () async {
                  final success = await authProvider.resendVerificationEmail();

                  if (!context.mounted) return;

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Email renvoyé !'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.send),
                label: const Text('Renvoyer l\'email'),
              ),

              const SizedBox(height: 32),

              TextButton(
                onPressed: () => authProvider.signOut(),
                child: const Text('Se déconnecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 🗑️ Account Deleted Screen
// ═══════════════════════════════════════════════════════════════════

class AccountDeletedScreen extends StatelessWidget {
  const AccountDeletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 100,
                color: Colors.green,
              ),

              const SizedBox(height: 32),

              Text(
                'Compte supprimé',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                'Votre compte a été supprimé définitivement.\n'
                    'Nous espérons vous revoir bientôt !',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              FilledButton(
                onPressed: () {
                  // Rediriger vers auth screen
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const AuthScreenAdvanced(),
                    ),
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
//   await Supabase.initialize(
//     url: 'https://uuosdbxqegnnwaojqxec.supabase.co',
//     anonKey: 'sb_publishable_lv4LuXnpZBxLZMw_j-rg_Q_omNBoE5A',
//     realtimeClientOptions: const RealtimeClientOptions(
//       eventsPerSecond: 10, // Limite les events pour éviter spam
//     ),
//   );