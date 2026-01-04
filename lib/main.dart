// lib/main.dart - NETTOYÉ
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

  await Supabase.initialize(
    url: 'https://uuosdbxqegnnwaojqxec.supabase.co',
    anonKey: 'sb_publishable_lv4LuXnpZBxLZMw_j-rg_Q_omNBoE5A',
  );

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
        Provider<ObjectBoxService>.value(value: objectBox),
        Provider<SupabaseClient>(create: (_) => Supabase.instance.client),

        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),

        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            context.read<SupabaseClient>(),
            context.read<ObjectBoxService>(),
          ),
        ),

        Provider<ImageService>(
          create: (context) => ImageService(context.read<SupabaseClient>()),
        ),

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
          if (authProvider.currentUser?.gender != null) {
            themeProvider.setUserGender(authProvider.currentUser!.gender!);
          } // Mettre à jour le gender APRÈS le build
          final currentGender = authProvider.currentUser?.gender;
          if (currentGender != null &&
              themeProvider.userGender != currentGender) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              themeProvider.setUserGender(currentGender);
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
