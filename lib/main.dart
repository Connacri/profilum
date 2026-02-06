import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_router.dart'; // ✅ Import du router
import 'auth/auth_screen.dart';
import 'claude/auth_provider_optimized.dart';
import 'claude/service_locator.dart';
import 'providers/theme_provider.dart';
import 'tami/admin_auth_provider_complete.dart';
import 'tami/admin_documents_provider_complete.dart';
import 'tami/document_provider_fixed.dart';
import 'tami/guest_mode_provider.dart';
import 'widgets/auth_rate_limiter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ═══════════════════════════════════════════════════════════════════
  // ✅ INITIALISATION UNIQUE - Remplace Supabase.initialize() + ObjectBox
  // ═══════════════════════════════════════════════════════════════════

  await services.init(
    supabaseUrl: 'https://ftaqbokfeahvfndorzuf.supabase.co',
    supabaseAnonKey:  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ0YXFib2tmZWFodmZuZG9yenVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3NDE5MDEsImV4cCI6MjA4MDMxNzkwMX0.I_pvSiN5S8Y31XS3NV2Gw5dVrCDNjXqmUUSloycXhcw',
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
        // ⏱️ Rate Limiter
        // ═══════════════════════════════════════════════════════════════
        ChangeNotifierProvider(create: (_) => AuthRateLimiter()),

        // ═══════════════════════════════════════════════════════════════
        // 🔐 AUTH PROVIDER (PRINCIPAL)
        // ═══════════════════════════════════════════════════════════════
        ChangeNotifierProvider(
          create: (context) => AuthProvider(
            services.supabase,
            rateLimiter: context.read<AuthRateLimiter>(),
          ),
        ),

        // ═══════════════════════════════════════════════════════════════
        // 👔 ADMIN AUTH PROVIDER
        // ═══════════════════════════════════════════════════════════════
        ChangeNotifierProvider(create: (_) => AdminAuthProvider()),

        // ═══════════════════════════════════════════════════════════════
        // 👤 GUEST MODE PROVIDER
        // ═══════════════════════════════════════════════════════════════
        ChangeNotifierProvider(create: (_) => GuestModeProvider()),

        // ═══════════════════════════════════════════════════════════════
        // 📄 DOCUMENT PROVIDERS
        // ═══════════════════════════════════════════════════════════════
        ChangeNotifierProvider(
          create: (_) => DocumentProvider(services.supabase),
        ),
        ChangeNotifierProvider(create: (_) => AdminDocumentsProvider()),
      ],
      child: Consumer2<ThemeProvider, AuthProvider>(
        builder: (context, themeProvider, authProvider, _) {
          // ✅ Mettre à jour le thème selon le genre de l'user
          if (authProvider.currentUser?.gender != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              themeProvider.setUserGender(authProvider.currentUser!.gender);
            });
          }

          // ═══════════════════════════════════════════════════════════════
          // ✅ ROUTING DÉCLARATIF (SOLUTION AU BUG)
          // ═══════════════════════════════════════════════════════════════
          return MaterialApp.router(
            title: 'Profilum',
            debugShowCheckedModeBanner: false,

            // ✅ Thèmes dynamiques
            theme: themeProvider.getLightTheme(),
            darkTheme: themeProvider.getDarkTheme(),
            themeMode: themeProvider.themeMode,

            // ✅ ROUTING CONFIGURATION (Au lieu de home:)
            routerDelegate: AppRouter(authProvider),
            routeInformationParser: AppRouteInformationParser(),

            // ✅ Builder pour gérer le chargement initial
            builder: (context, child) {
              // Afficher un splash pendant l'initialisation
              if (authProvider.status == AuthStatus.initial ||
                  authProvider.status == AuthStatus.loading) {
                return const _LoadingSplash();
              }

              return child ?? const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}

class _LoadingSplash extends StatelessWidget {
  const _LoadingSplash();

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
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'P',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Nom de l'app
              Text(
                'Profilum',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Connectez-vous avec authenticité',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),

              const SizedBox(height: 48),

              // Indicateur de chargement
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.8),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Chargement...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
              const Icon(
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


