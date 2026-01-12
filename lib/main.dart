// lib/main.dart - FIX : Ne pas appeler setUserGender pendant le build

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // ✅ AJOUTER
import 'package:profilum/services/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/profile_completion_provider.dart';
import 'providers/theme_provider.dart';
import 'services/image_service.dart';
import 'services/profile_image_service.dart';
import 'widgets/auth_rate_limiter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ AJOUTER - Initialiser les locales français
  await initializeDateFormatting('fr_FR', null);

  await Supabase.initialize(
    url: 'https://uuosdbxqegnnwaojqxec.supabase.co',
    anonKey: 'sb_publishable_lv4LuXnpZBxLZMw_j-rg_Q_omNBoE5A',
    realtimeClientOptions: const RealtimeClientOptions(
      eventsPerSecond: 10, // Limite les events pour éviter spam
    ),
  );

  final objectBox = await ObjectBoxService.create();
  // Configure timeago en français
  timeago.setLocaleMessages('fr', timeago.FrMessages());

  runApp(ProfilumApp(objectBox: objectBox));
}

class ProfilumApp extends StatelessWidget {
  final ObjectBoxService objectBox;

  const ProfilumApp({super.key, required this.objectBox});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ════════════════════════════════════════════════════════
        // 🔹 NIVEAU 1 : Providers sans dépendances
        // ════════════════════════════════════════════════════════
        Provider<ObjectBoxService>.value(value: objectBox),

        Provider<SupabaseClient>(create: (_) => Supabase.instance.client),

        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),

        // ✅ AJOUT CRITIQUE : AuthRateLimiter AVANT AuthProvider
        ChangeNotifierProvider<AuthRateLimiter>(
          create: (_) => AuthRateLimiter(),
        ),

        // ════════════════════════════════════════════════════════
        // 🔹 NIVEAU 2 : Providers avec dépendances simples
        // ════════════════════════════════════════════════════════
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            context.read<SupabaseClient>(),
            context.read<ObjectBoxService>(),
            rateLimiter: context.read<AuthRateLimiter>(), // ✅ Maintenant OK
          ),
        ),

        Provider<ImageService>(
          create: (context) => ImageService(context.read<SupabaseClient>()),
        ),
        Provider<ProfileImageService>(
          create: (_) => ProfileImageService(Supabase.instance.client),
        ),
        // ════════════════════════════════════════════════════════
        // 🔹 NIVEAU 3 : Providers avec dépendances complexes
        // ════════════════════════════════════════════════════════
        ChangeNotifierProvider<ProfileCompletionProvider>(
          create: (context) => ProfileCompletionProvider(
            context.read<SupabaseClient>(),
            context.read<ObjectBoxService>(),
            context.read<ImageService>(),
          ),
        ),
      ],
      child: Consumer2<ThemeProvider, AuthProvider>(
        builder: (context, themeProvider, authProvider, _) {
          // ✅ FIX: Mettre à jour le gender SEULEMENT après le build
          final currentGender = authProvider.currentUser?.gender;
          if (currentGender != null &&
              themeProvider.userGender != currentGender) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                themeProvider.setUserGender(currentGender);
              }
            });
          }

          // ✅ NOUVEAU : Reset ProfileCompletionProvider au signOut
          if (authProvider.status == AuthStatus.unauthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                // Reset le provider de completion
                context.read<ProfileCompletionProvider>().reset();

                // Reset le theme gender (optionnel)
                themeProvider.setUserGender(null);

                debugPrint('🧹 All providers reset after signOut');
              }
            });
          }

          return MaterialApp.router(
            title: 'Profilum',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.getLightTheme(),
            darkTheme: themeProvider.getDarkTheme(),
            themeMode: themeProvider.themeMode,
            routerDelegate: AppRouter(authProvider),
            routeInformationParser: AppRouteInformationParser(),
          );
        },
      ),
    );
  }
}
