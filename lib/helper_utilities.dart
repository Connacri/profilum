// lib/core/utils/validators.dart
// lib/core/utils/app_logger.dart

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  static String? password(String? value, {bool isSignup = false}) {
    if (value == null || value.isEmpty) {
      return 'Mot de passe requis';
    }

    if (isSignup && value.length < 8) {
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
        ((now.month < birthDate.month ||
                (now.month == birthDate.month && now.day < birthDate.day))
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

// lib/core/utils/date_utils.dart

class DateUtils {
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} an${(difference.inDays / 365).floor() > 1 ? 's' : ''}';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} mois';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}min';
    } else {
      return 'À l\'instant';
    }
  }

  static int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}

// lib/core/utils/string_extensions.dart
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}$suffix';
  }

  bool isValidEmail() {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(this);
  }

  String? toNullIfEmpty() {
    return isEmpty ? null : this;
  }
}

// lib/core/utils/number_extensions.dart
extension IntExtension on int {
  String toKFormat() {
    if (this >= 1000000) {
      return '${(this / 1000000).toStringAsFixed(1)}M';
    } else if (this >= 1000) {
      return '${(this / 1000).toStringAsFixed(1)}K';
    }
    return toString();
  }
}

// lib/core/utils/list_extensions.dart
extension ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;

  List<T> distinct() {
    return toSet().toList();
  }

  List<T> whereNotNull() {
    return where((e) => e != null).toList();
  }
}

class ErrorHandler {
  static String handleError(dynamic error) {
    if (error is AuthException) {
      return _handleAuthError(error);
    } else if (error is PostgrestException) {
      return _handlePostgrestError(error);
    } else if (error is StorageException) {
      return _handleStorageError(error);
    }

    return 'Une erreur est survenue : ${error.toString()}';
  }

  static String _handleAuthError(AuthException error) {
    switch (error.statusCode) {
      case '400':
        return 'Email ou mot de passe invalide';
      case '422':
        if (error.message.contains('already registered')) {
          return 'Cet email est déjà utilisé';
        }
        return 'Données invalides';
      case '429':
        return 'Trop de tentatives. Réessayez plus tard';
      default:
        return error.message;
    }
  }

  static String _handlePostgrestError(PostgrestException error) {
    if (error.code == '23505') {
      return 'Cette donnée existe déjà';
    }
    return error.message;
  }

  static String _handleStorageError(StorageException error) {
    if (error.statusCode == '413') {
      return 'Fichier trop volumineux';
    }
    return error.message;
  }

  static void showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class AppLogger {
  static void log(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log(message, name: tag ?? 'Profilum', time: DateTime.now());
    }
  }

  static void error(String message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      developer.log(
        message,
        name: 'ERROR',
        error: error,
        stackTrace: stackTrace,
        time: DateTime.now(),
      );
    }
  }

  static void warn(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'WARNING', time: DateTime.now());
    }
  }

  static void info(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'INFO', time: DateTime.now());
    }
  }
}

// lib/core/constants/app_constants.dart
class AppConstants {
  // API
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'YOUR_SUPABASE_URL',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );

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
  static const Duration heartbeatInterval = Duration(minutes: 5);

  // Image Processing
  static const int imageMaxWidth = 1920;
  static const int imageMaxHeight = 1920;
  static const int imageQuality = 85;
  static const String watermarkText = 'profilum';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;

  // Distance
  static const int defaultMaxDistance = 100; // km
  static const int maxDistance = 500; // km

  // Age
  static const int minAge = 18;
  static const int maxAge = 99;

  // Roles
  static const String roleUser = 'user';
  static const String roleModerator = 'moderator';
  static const String roleAdmin = 'admin';

  // Photo Status
  static const String photoStatusPending = 'pending';
  static const String photoStatusApproved = 'approved';
  static const String photoStatusRejected = 'rejected';

  // Match Status
  static const String matchStatusPending = 'pending';
  static const String matchStatusMatched = 'matched';
  static const String matchStatusUnmatched = 'unmatched';
}

// lib/core/constants/assets.dart
class Assets {
  static const String imagesPath = 'assets/images/';
  static const String avatarsPath = 'assets/avatars/';
  static const String iconsPath = 'assets/icons/';

  // Images
  static const String logo = '${imagesPath}logo.png';
  static const String logoWhite = '${imagesPath}logo_white.png';
  static const String splash = '${imagesPath}splash.png';

  // Avatars par défaut
  static const String defaultAvatarMale = '${avatarsPath}default_male.png';
  static const String defaultAvatarFemale = '${avatarsPath}default_female.png';
  static const String defaultAvatarMtf = '${avatarsPath}default_mtf.png';
  static const String defaultAvatarFtm = '${avatarsPath}default_ftm.png';

  static String getDefaultAvatar(String? gender) {
    switch (gender) {
      case 'male':
        return defaultAvatarMale;
      case 'female':
        return defaultAvatarFemale;
      case 'mtf':
        return defaultAvatarMtf;
      case 'ftm':
        return defaultAvatarFtm;
      default:
        return defaultAvatarMale;
    }
  }
}
