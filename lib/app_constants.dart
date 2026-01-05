import 'package:flutter/material.dart';

/// 🎨 Constantes de design pour l'application Admin/Moderator
class AppConstants {
  // 🎯 Breakpoints (alignés sur Material Design 3)
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 840;
  static const double desktopBreakpoint = 1200;
  static const double largeDesktopBreakpoint = 1600;

  // 📏 Spacing
  static const double spacingXs = 4;
  static const double spacingS = 8;
  static const double spacingM = 12;
  static const double spacingL = 16;
  static const double spacingXl = 24;
  static const double spacingXxl = 32;
  static const double spacingXxxl = 48;

  // 🎨 Border Radius
  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 16;
  static const double radiusXl = 20;
  static const double radiusFull = 999;

  // 🖼️ Image & Card
  static const double cardElevation = 0;
  static const double cardElevationHover = 4;
  static const double imageAspectRatio = 4 / 3;
  static const double minCardWidth = 240;
  static const double maxCardWidth = 400;
  static const double targetCardWidth = 280;

  // 📱 Grid Configuration
  static const int mobileColumns = 1;
  static const int tabletSmallColumns = 2;
  static const int tabletLargeColumns = 3;
  static const int desktopColumns = 4;
  static const int largeDesktopColumns = 6;

  // 🎯 Animation Durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // 📐 Sidebar
  static const double sidebarWidthMobile = 280;
  static const double sidebarWidthTablet = 280;
  static const double sidebarWidthDesktop = 320;

  // 🎨 Gradient Colors (pour la sidebar)
  static List<Color> getSidebarGradient(BuildContext context) {
    final theme = Theme.of(context);
    return [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
    ];
  }

  // 🔢 Pagination
  static const int defaultPageSize = 50;
  static const int maxPageSize = 100;

  // 🎨 Status Colors
  static const Color approvedColor = Colors.green;
  static const Color rejectedColor = Colors.red;
  static const Color pendingColor = Colors.orange;
  static const Color infoColor = Colors.blue;
  static const Color warningColor = Colors.orange;

  // 📝 Text Sizes (responsive)
  static double getHeadlineSize(BuildContext context, double baseSize) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < mobileBreakpoint) {
      return baseSize * 0.85;
    } else if (width < desktopBreakpoint) {
      return baseSize;
    } else {
      return baseSize * 1.15;
    }
  }

  static double getBodySize(BuildContext context, double baseSize) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < mobileBreakpoint) {
      return baseSize * 0.9;
    } else {
      return baseSize;
    }
  }

  // 🎨 Shadows
  static List<BoxShadow> cardShadow(BuildContext context) => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> elevatedShadow(BuildContext context) => [
        BoxShadow(
          color: Colors.black.withOpacity(0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  // 📱 Safe Areas
  static EdgeInsets getSafePadding(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return EdgeInsets.only(
      top: padding.top,
      bottom: padding.bottom,
    );
  }
}

/// 🎨 Extension pour faciliter l'accès aux constantes
extension AppConstantsExtension on BuildContext {
  // Spacing helpers
  double get spacingXs => AppConstants.spacingXs;
  double get spacingS => AppConstants.spacingS;
  double get spacingM => AppConstants.spacingM;
  double get spacingL => AppConstants.spacingL;
  double get spacingXl => AppConstants.spacingXl;
  double get spacingXxl => AppConstants.spacingXxl;
  double get spacingXxxl => AppConstants.spacingXxxl;

  // Radius helpers
  double get radiusS => AppConstants.radiusS;
  double get radiusM => AppConstants.radiusM;
  double get radiusL => AppConstants.radiusL;
  double get radiusXl => AppConstants.radiusXl;

  // Animation helpers
  Duration get animFast => AppConstants.animationFast;
  Duration get animNormal => AppConstants.animationNormal;
  Duration get animSlow => AppConstants.animationSlow;

  // Shadow helpers
  List<BoxShadow> get cardShadow => AppConstants.cardShadow(this);
  List<BoxShadow> get elevatedShadow => AppConstants.elevatedShadow(this);
}

/// 🎯 Theme Extensions personnalisées
extension CustomThemeExtension on ThemeData {
  // Couleurs personnalisées basées sur le theme
  Color get successColor => Colors.green.shade600;
  Color get warningColor => Colors.orange.shade600;
  Color get errorColor => colorScheme.error;
  Color get infoColor => Colors.blue.shade600;

  // Gradient personnalisé
  LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colorScheme.primary, colorScheme.secondary],
      );

  LinearGradient get surfaceGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colorScheme.surface,
          colorScheme.surfaceVariant.withOpacity(0.3),
        ],
      );
}

/// 🔧 Helpers pour les widgets réutilisables
class WidgetHelpers {
  /// Crée un bouton d'action avec icône
  static Widget buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
    bool isOutlined = false,
  }) {
    final theme = Theme.of(context);
    final btnColor = color ?? theme.colorScheme.primary;

    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: btnColor,
          side: BorderSide(color: btnColor),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: btnColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// Crée un badge de statut
  static Widget buildStatusBadge({
    required BuildContext context,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Crée une carte d'erreur
  static Widget buildErrorCard({
    required BuildContext context,
    required String message,
    IconData icon = Icons.error_outline,
    VoidCallback? onRetry,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Crée un état de chargement
  static Widget buildLoadingIndicator({
    required BuildContext context,
    String? message,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Crée un état vide
  static Widget buildEmptyState({
    required BuildContext context,
    required String title,
    String? subtitle,
    IconData icon = Icons.inbox,
    Widget? action,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
