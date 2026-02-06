import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import 'claude/auth_provider_optimized.dart';
import 'claude/service_locator.dart';

import 'providers/photos_provider.dart';
import 'providers/theme_provider.dart';
import 'tami/admin_auth_provider_complete.dart';
import 'tami/admin_documents_provider_complete.dart';
import 'tami/document_provider_fixed.dart';
import 'tami/guest_mode_provider.dart';
import 'widgets/auth_rate_limiter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ═══════════════════════════════════════════════════════════════
  // ✅ INITIALISATION SERVICES
  // ═══════════════════════════════════════════════════════════════
  await services.init(
    supabaseUrl: 'https://ftaqbokfeahvfndorzuf.supabase.co',
    supabaseAnonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ0YXFib2tmZWFodmZuZG9yenVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3NDE5MDEsImV4cCI6MjA4MDMxNzkwMX0.I_pvSiN5S8Y31XS3NV2Gw5dVrCDNjXqmUUSloycXhcw',
  );
  debugPrint('✅ Services initialized');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ═══════════════════════════════════════════════════════════
        // 🎨 THEME
        // ═══════════════════════════════════════════════════════════
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        // ═══════════════════════════════════════════════════════════
        // ⏱️ RATE LIMITER
        // ═══════════════════════════════════════════════════════════
        ChangeNotifierProvider(create: (_) => AuthRateLimiter()),

        // ═══════════════════════════════════════════════════════════
        // 🔐 AUTH PROVIDERS
        // ═══════════════════════════════════════════════════════════
        ChangeNotifierProvider(
          create: (context) => AuthProvider(
            services.supabase,
            rateLimiter: context.read<AuthRateLimiter>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => AdminAuthProvider()),

        // ═══════════════════════════════════════════════════════════
        // 👤 GUEST MODE
        // ═══════════════════════════════════════════════════════════
        ChangeNotifierProvider(create: (_) => GuestModeProvider()),

        // ═══════════════════════════════════════════════════════════
        // 📄 DOCUMENTS
        // ═══════════════════════════════════════════════════════════
        ChangeNotifierProvider(
          create: (_) => DocumentProvider(services.supabase),
        ),
        ChangeNotifierProvider(create: (_) => AdminDocumentsProvider()),

        // ═══════════════════════════════════════════════════════════
        // 📸 PHOTOS
        // ═══════════════════════════════════════════════════════════
        ChangeNotifierProxyProvider<AuthProvider, PhotosProvider>(
          create: (context) => PhotosProvider(
            userId: context.read<AuthProvider>().currentUser!.userId,
          ),
          update: (context, authProvider, previous) => PhotosProvider(
            userId: authProvider.currentUser!.userId,
          ),
        ),
      ],
      child: Consumer2<ThemeProvider, AuthProvider>(
        builder: (context, themeProvider, authProvider, _) {
          // ═══════════════════════════════════════════════════════════
          // 🎨 MISE À JOUR THÈME SELON GENRE
          // ═══════════════════════════════════════════════════════════
          if (authProvider.currentUser?.gender != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              themeProvider.setUserGender(authProvider.currentUser!.gender);
            });
          }

          // ═══════════════════════════════════════════════════════════
          // 🛣️ ROUTER CONFIGURATION
          // ═══════════════════════════════════════════════════════════
          final adminAuthProvider = context.watch<AdminAuthProvider>();

          return MaterialApp.router(
            title: 'Profilum',
            debugShowCheckedModeBanner: false,

            // Thèmes
            theme: themeProvider.getLightTheme(),
            darkTheme: themeProvider.getDarkTheme(),
            themeMode: themeProvider.themeMode,

            // Router optimisé
            routerDelegate: AppRouterDelegate(
              authProvider: authProvider,
              adminAuthProvider: adminAuthProvider,
            ),
            routeInformationParser: AppRouteInformationParser(),
          );
        },
      ),
    );
  }
}