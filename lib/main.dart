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

  // Initialize Supabase
  await SupabaseService.initialize(
    url: 'https://uuosdbxqegnnwaojqxec.supabase.co', // Remplacer par votre URL
    anonKey:
        'sb_publishable_lv4LuXnpZBxLZMw_j-rg_Q_omNBoE5A', // Remplacer par votre clé
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

            // Routing
            routerDelegate: AppRouter(authProvider),
            routeInformationParser: _RouteInformationParser(),

            // Network Status Listener
            builder: (context, child) {
              return Consumer<NetworkService>(
                builder: (context, networkService, _) {
                  return Stack(
                    children: [
                      child ?? const SizedBox.shrink(),

                      // Network Banner
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

class _RouteInformationParser extends RouteInformationParser<void> {
  @override
  Future<void> parseRouteInformation(RouteInformation routeInformation) async {}
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
            children: [
              const Icon(Icons.wifi_off, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aucune connexion Internet',
                  style: const TextStyle(
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

// lib/core/constants/app_constants.dart
class AppConstants {
  // API
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // Storage Buckets
  static const String profilesBucket = 'profiles';
  static const String groupsBucket = 'groups';

  // Validation
  static const int minPhotoCount = 3;
  static const int maxPhotoCount = 6;
  static const int minBioLength = 50;
  static const int maxBioLength = 500;
  static const int minInterestsCount = 3;

  // Session
  static const Duration sessionDuration = Duration(days: 30);
  static const Duration gracePeriod = Duration(days: 30);
  static const Duration skipReminderDelay = Duration(hours: 24);

  // Image Processing
  static const int imageMaxWidth = 1920;
  static const int imageMaxHeight = 1920;
  static const int imageQuality = 85;
  static const String watermarkText = 'profilum';
}

// lib/core/utils/validators.dart
class Validators {
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email requis';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Email invalide';
    }

    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mot de passe requis';
    }

    if (value.length < 8) {
      return 'Minimum 8 caractères';
    }

    return null;
  }

  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName requis';
    }

    return null;
  }

  static String? minLength(String? value, int minLength, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName requis';
    }

    if (value.length < minLength) {
      return '$fieldName doit contenir au moins $minLength caractères';
    }

    return null;
  }

  static String? age(DateTime? birthDate) {
    if (birthDate == null) {
      return 'Date de naissance requise';
    }

    final now = DateTime.now();
    final age =
        now.year -
        birthDate.year -
        (now.month < birthDate.month ||
                (now.month == birthDate.month && now.day < birthDate.day)
            ? 1
            : 0);

    if (age < 18) {
      return 'Vous devez avoir au moins 18 ans';
    }

    if (age > 100) {
      return 'Date de naissance invalide';
    }

    return null;
  }
}

// README.md instructions
/*
# Profilum - Application de rencontre moderne

## Architecture

### Stack technique
- Flutter 3.16+ avec Material 3
- Supabase (Auth + Database + Storage)
- ObjectBox (Cache local)
- Provider (State management)

### Structure du projet
```
lib/
├── core/
│   ├── constants/
│   ├── database/
│   │   ├── entities/
│   │   └── objectbox_service.dart
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── profile_completion_provider.dart
│   │   └── theme_provider.dart
│   ├── routing/
│   │   └── app_router.dart
│   ├── services/
│   │   ├── image_service.dart
│   │   ├── network_service.dart
│   │   └── supabase_service.dart
│   └── utils/
├── features/
│   ├── admin/
│   ├── auth/
│   ├── home/
│   ├── moderator/
│   └── profile/
└── main.dart
```

## Configuration

### 1. Supabase Setup

1. Créer un projet sur supabase.com
2. Exécuter le SQL fourni dans `supabase_tables.sql`
3. Configurer RLS (Row Level Security)
4. Créer les buckets Storage: `profiles`, `groups`
5. Activer Email Auth dans Authentication

### 2. Configuration App

Dans `lib/main.dart`, remplacer:
```dart
url: 'YOUR_SUPABASE_URL',
anonKey: 'YOUR_SUPABASE_ANON_KEY',
```

### 3. ObjectBox

Générer le code ObjectBox:
```bash
flutter pub run build_runner build
```

### 4. Assets

Ajouter dans `assets/`:
- `images/` - Logo, images par défaut
- `avatars/` - Avatars par défaut selon genre

## Fonctionnalités principales

### Auth Flow
1. Login/Signup unifié
2. Email existant → Login automatique
3. Email verification avec période de grâce 30j
4. Suppression auto si email non vérifié

### Profile Completion
- Champs obligatoires avec barre de progression
- Upload 3-6 photos (WebP compression)
- Watermark automatique sur photos caméra
- Skip temporaire (rappel 24h)
- Blocage albums sans 3 photos

### Modération
- Validation manuelle photos
- Dashboard temps réel
- Notifications in-app
- Swipe approve/reject

### Thèmes
- Adaptation selon genre (male, female, mtf, ftm)
- Mode clair/sombre
- Material 3 Design

### Session Management
- 30 jours avec refresh automatique
- Heartbeat toutes les 5 min
- Gestion network failure
- Cache local avec ObjectBox

## Workflow UX

### Nouvel utilisateur
1. Signup → Email verification
2. Profile completion (ou skip)
3. Upload photos
4. Attente validation modération
5. Accès complet après validation

### Utilisateur existant
1. Login
2. Vérification profile completed
3. Redirection selon rôle:
   - User → Home (selon genre)
   - Moderator → Panel modération
   - Admin → Dashboard

## Commandes utiles

```bash
# Installation dépendances
flutter pub get

# Génération ObjectBox
flutter pub run build_runner build --delete-conflicting-outputs

# Run
flutter run

# Build
flutter build apk --release
flutter build windows --release
```

## Notes importantes

1. **Photos**: Toutes les photos sont en WebP, compressées à 85%
2. **Modération**: Aucune photo visible avant validation
3. **Session**: Expire après 30j inactivité
4. **Network**: Mode offline avec sync auto
5. **RLS**: Configuré pour sécurité maximale
6. **Messagerie**: Placeholder pour P2P futur

## Prochaines étapes

1. Implémenter messagerie P2P
2. Système de matching
3. Géolocalisation
4. Filtres avancés
5. Groupes fonctionnels
*/
