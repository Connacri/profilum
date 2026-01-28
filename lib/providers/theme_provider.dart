// lib/providers/theme_provider.dart - ✅ VERSION COMPATIBLE UserModel

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String? _userGender;

  ThemeMode get themeMode => _themeMode;
  String? get userGender => _userGender;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode');
    if (isDark != null) {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', mode == ThemeMode.dark);
    notifyListeners();
  }

  /// ✅ Version simplifiée - accepte null
  void setUserGender(String? gender) {
    if (_userGender == gender) return; // Évite rebuilds inutiles

    _userGender = gender;
    debugPrint('🎨 Theme gender updated: ${gender ?? "reset to default"}');
    notifyListeners();
  }

  ThemeData getLightTheme() {
    switch (_userGender) {
      case 'male':
        return _getMaleTheme(false);
      case 'female':
        return _getFemaleTheme(false);
      case 'mtf':
        return _getMtfTheme(false);
      case 'ftm':
        return _getFtmTheme(false);
      default:
        return _getDefaultTheme(false);
    }
  }

  ThemeData getDarkTheme() {
    switch (_userGender) {
      case 'male':
        return _getMaleTheme(true);
      case 'female':
        return _getFemaleTheme(true);
      case 'mtf':
        return _getMtfTheme(true);
      case 'ftm':
        return _getFtmTheme(true);
      default:
        return _getDefaultTheme(true);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🎨 THÈMES SPÉCIFIQUES
  // ═══════════════════════════════════════════════════════════════════

  ThemeData _getMaleTheme(bool isDark) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E3A8A),
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: const Color(0xFF1E3A8A),
      secondary: const Color(0xFF3B82F6),
      tertiary: const Color(0xFF60A5FA),
    );
    return _buildTheme(colorScheme, isDark);
  }

  ThemeData _getFemaleTheme(bool isDark) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFEC4899),
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: const Color(0xFFEC4899),
      secondary: const Color(0xFFF472B6),
      tertiary: const Color(0xFFFBBF24),
    );
    return _buildTheme(colorScheme, isDark);
  }

  ThemeData _getMtfTheme(bool isDark) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF9333EA),
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: const Color(0xFF9333EA),
      secondary: const Color(0xFFC084FC),
      tertiary: const Color(0xFFFBBF24),
    );
    return _buildTheme(colorScheme, isDark);
  }

  ThemeData _getFtmTheme(bool isDark) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0D9488),
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: const Color(0xFF0D9488),
      secondary: const Color(0xFF14B8A6),
      tertiary: const Color(0xFF2DD4BF),
    );
    return _buildTheme(colorScheme, isDark);
  }

  ThemeData _getDefaultTheme(bool isDark) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6366F1),
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: const Color(0xFF6366F1),
      secondary: const Color(0xFF8B5CF6),
      tertiary: const Color(0xFFEC4899),
    );
    return _buildTheme(colorScheme, isDark);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🏗️ THEME BUILDER
  // ═══════════════════════════════════════════════════════════════════

  ThemeData _buildTheme(ColorScheme colorScheme, bool isDark) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: isDark ? Brightness.dark : Brightness.light,
      fontFamily: 'PlayfairDisplay',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 57,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.25,
        ),
        displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
        displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400),
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w400),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 2 : 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? colorScheme.surfaceVariant.withOpacity(0.5)
            : colorScheme.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? colorScheme.surface : colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceVariant,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}