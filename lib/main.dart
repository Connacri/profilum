// lib/main.dart
import 'package:flutter/material.dart';
import 'package:profilum/services/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/profile_completion_provider.dart';
import 'providers/theme_provider.dart';
import 'services/image_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase - REMPLACE PAR TES VALEURS
  await Supabase.initialize(
    url: 'https://uuosdbxqegnnwaojqxec.supabase.co',
    anonKey: 'sb_publishable_lv4LuXnpZBxLZMw_j-rg_Q_omNBoE5A',
  );

  // Initialize ObjectBox
  final objectBox = await ObjectBoxService.create();

  runApp(ProfilumApp(objectBox: objectBox));
}

class ProfilumApp extends StatelessWidget {
  final ObjectBoxService objectBox;

  const ProfilumApp({super.key, required this.objectBox});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services
        Provider<ObjectBoxService>.value(value: objectBox),
        Provider<SupabaseClient>(create: (_) => SupabaseService.client),

        // Network Service
        ChangeNotifierProvider<NetworkService>(create: (_) => NetworkService()),

        // Theme Provider
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),

        // Auth Provider
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            context.read<SupabaseClient>(),
            context.read<ObjectBoxService>(),
            context.read<NetworkService>(),
          ),
        ),

        // Image Service
        Provider<ImageService>(
          create: (context) => ImageService(context.read<SupabaseClient>()),
        ),

        // Profile Completion Provider
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
          // Mettre à jour le thème selon le genre
          if (authProvider.currentUser?.gender != null) {
            themeProvider.setUserGender(authProvider.currentUser!.gender);
          }

          return MaterialApp.router(
            title: 'Profilum',
            debugShowCheckedModeBanner: false,

            // Theme
            theme: themeProvider.getLightTheme(),
            darkTheme: themeProvider.getDarkTheme(),
            themeMode: themeProvider.themeMode,

            // CORRECTION: Utilisation de AppRouteInformationParser
            routerDelegate: AppRouter(authProvider),
            routeInformationParser: AppRouteInformationParser(),

            // Network Status Listener
            builder: (context, child) {
              return Consumer<NetworkService>(
                builder: (context, networkService, _) {
                  return Stack(
                    children: [
                      child ?? const SizedBox.shrink(),

                      if (!networkService.isConnected)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _NetworkBanner(),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NetworkBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: const [
              Icon(Icons.wifi_off, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aucune connexion Internet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
