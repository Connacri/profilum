import 'package:flutter/material.dart';

/// 🎯 Helper responsive basé sur Material Design Guidelines 2025
/// Breakpoints officiels: https://m3.material.io/foundations/layout/applying-layout/window-size-classes
class ResponsiveHelper {
  // 📱 Breakpoints Material Design 3
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 840;
  static const double desktopBreakpoint = 1200;

  /// Vérifie si l'écran est mobile (< 600px)
  static bool isMobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width < mobileBreakpoint;
  }

  /// Vérifie si l'écran est tablette (600px - 840px)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  /// Vérifie si l'écran est desktop (> 1200px)
  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= desktopBreakpoint;
  }

  /// Retourne le type d'écran
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < mobileBreakpoint) return ScreenType.mobile;
    if (width < desktopBreakpoint) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  /// 🎨 Calcule le nombre de colonnes pour GridView
  static int getGridColumns(BuildContext context, {int? customMobile, int? customTablet, int? customDesktop}) {
    final width = MediaQuery.sizeOf(context).width;
    
    if (width < mobileBreakpoint) {
      return customMobile ?? 1; // Mobile: 1 colonne
    } else if (width < tabletBreakpoint) {
      return customTablet ?? 2; // Tablet small: 2 colonnes
    } else if (width < desktopBreakpoint) {
      return customTablet ?? 3; // Tablet large: 3 colonnes
    } else if (width < 1600) {
      return customDesktop ?? 4; // Desktop: 4 colonnes
    } else {
      return customDesktop ?? 6; // Large desktop: 6 colonnes
    }
  }

  /// 📏 Calcule dynamiquement le nombre de colonnes basé sur une largeur d'item cible
  static int getColumnsFromItemWidth(double availableWidth, {double targetItemWidth = 280}) {
    return (availableWidth / targetItemWidth).floor().clamp(1, 8);
  }

  /// 🎛️ Retourne le padding adaptatif
  static EdgeInsets getAdaptivePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(24);
    } else {
      return const EdgeInsets.all(32);
    }
  }

  /// 📐 Retourne le spacing adaptatif pour GridView
  static double getAdaptiveSpacing(BuildContext context) {
    if (isMobile(context)) {
      return 12;
    } else if (isTablet(context)) {
      return 16;
    } else {
      return 20;
    }
  }

  /// 🎯 Retourne l'aspect ratio adaptatif pour les cartes
  static double getCardAspectRatio(BuildContext context) {
    if (isMobile(context)) {
      return 0.75; // Plus vertical sur mobile
    } else {
      return 0.85; // Plus carré sur desktop
    }
  }

  /// 📱 Largeur de la sidebar
  static double getSidebarWidth(BuildContext context) {
    if (isMobile(context)) {
      return MediaQuery.sizeOf(context).width * 0.75; // 75% sur mobile
    } else if (isTablet(context)) {
      return 280;
    } else {
      return 320;
    }
  }

  /// 🎨 Retourne la taille de police adaptative
  static double getAdaptiveFontSize(BuildContext context, double baseSize) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return baseSize * 0.9;
      case ScreenType.tablet:
        return baseSize;
      case ScreenType.desktop:
        return baseSize * 1.1;
    }
  }

  /// 🖼️ Retourne la hauteur adaptative pour les images
  static double getAdaptiveImageHeight(BuildContext context) {
    if (isMobile(context)) {
      return 180;
    } else if (isTablet(context)) {
      return 220;
    } else {
      return 260;
    }
  }
}

enum ScreenType {
  mobile,
  tablet,
  desktop,
}

/// 🎯 Extension pour simplifier l'utilisation
extension ResponsiveContext on BuildContext {
  bool get isMobile => ResponsiveHelper.isMobile(this);
  bool get isTablet => ResponsiveHelper.isTablet(this);
  bool get isDesktop => ResponsiveHelper.isDesktop(this);
  ScreenType get screenType => ResponsiveHelper.getScreenType(this);
  
  EdgeInsets get adaptivePadding => ResponsiveHelper.getAdaptivePadding(this);
  double get adaptiveSpacing => ResponsiveHelper.getAdaptiveSpacing(this);
}
