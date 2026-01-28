// ==================== BOUTON D'ACCÈS AU PROJET ====================
// lib/widgets/project_access_button.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../claude/auth_provider_optimized.dart';
import '../screens/home_screen.dart';


/// Bouton moderne d'accès au projet avec animation et validation
class ProjectAccessButton extends StatefulWidget {
  /// Texte du bouton (optionnel)
  final String? label;

  /// Icône du bouton (optionnel)
  final IconData? icon;

  /// Couleur principale (optionnel)
  final Color? color;

  /// Style du bouton : elevated, outlined, text
  final ButtonStyle? buttonStyle;

  /// Largeur complète ou non
  final bool fullWidth;

  /// Taille : small, medium, large
  final ButtonSize size;

  const ProjectAccessButton({
    super.key,
    this.label,
    this.icon,
    this.color,
    this.buttonStyle,
    this.fullWidth = false,
    this.size = ButtonSize.medium,
  });

  @override
  State<ProjectAccessButton> createState() => _ProjectAccessButtonState();
}

enum ButtonSize { small, medium, large }

class _ProjectAccessButtonState extends State<ProjectAccessButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();

    final color = widget.color ?? const Color(0xFF0D47A1);
    final label = widget.label ?? 'Accéder au Projet';
    final icon = widget.icon ?? Icons.document_scanner_rounded;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: widget.fullWidth ? double.infinity : null,
          height: _getHeight(),
          child: ElevatedButton.icon(
            onPressed: () => _handleAccess(context, authProvider),
            icon: Icon(icon, size: _getIconSize()),
            label: Text(
              label,
              style: TextStyle(
                fontSize: _getFontSize(),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: widget.buttonStyle ?? ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: _isHovered ? 8 : 4,
              shadowColor: color.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: _getHorizontalPadding(),
                vertical: _getVerticalPadding(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _getHeight() {
    switch (widget.size) {
      case ButtonSize.small:
        return 40;
      case ButtonSize.medium:
        return 56;
      case ButtonSize.large:
        return 64;
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case ButtonSize.small:
        return 20;
      case ButtonSize.medium:
        return 24;
      case ButtonSize.large:
        return 28;
    }
  }

  double _getFontSize() {
    switch (widget.size) {
      case ButtonSize.small:
        return 14;
      case ButtonSize.medium:
        return 16;
      case ButtonSize.large:
        return 18;
    }
  }

  double _getHorizontalPadding() {
    switch (widget.size) {
      case ButtonSize.small:
        return 16;
      case ButtonSize.medium:
        return 24;
      case ButtonSize.large:
        return 32;
    }
  }

  double _getVerticalPadding() {
    switch (widget.size) {
      case ButtonSize.small:
        return 8;
      case ButtonSize.medium:
        return 12;
      case ButtonSize.large:
        return 16;
    }
  }

  void _handleAccess(BuildContext context, AuthProvider authProvider) {
    // Vérifier si l'utilisateur est authentifié
    if (!authProvider.isAuthenticated) {
      _showLoginRequired(context);
      return;
    }

    // Naviguer vers HomeScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
    );
  }

  void _showLoginRequired(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_rounded, size: 48, color: Colors.orange),
        title: const Text('Connexion requise'),
        content: const Text(
          'Vous devez être connecté pour accéder au projet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Naviguer vers la page de connexion
              Navigator.pushNamed(context, '/auth');
            },
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }
}

// ==================== VARIANTES DE BOUTONS ====================

/// Bouton Floating Action Button pour accès rapide
class ProjectAccessFAB extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? backgroundColor;

  const ProjectAccessFAB({
    super.key,
    this.onPressed,
    this.tooltip,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return FloatingActionButton.extended(
      onPressed: onPressed ?? () => _handleAccess(context, authProvider),
      backgroundColor: backgroundColor ?? const Color(0xFF0D47A1),
      icon: const Icon(Icons.folder_open_rounded),
      label: const Text('Mes Documents'),
      tooltip: tooltip ?? 'Accéder au projet',
    );
  }

  void _handleAccess(BuildContext context, AuthProvider authProvider) {
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez vous connecter pour accéder au projet'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }
}

/// Bouton Card pour dashboard
class ProjectAccessCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Color? color;

  const ProjectAccessCard({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final color = this.color ?? const Color(0xFF0D47A1);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _handleAccess(context, authProvider),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon ?? Icons.folder_open_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withOpacity(0.7),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                title ?? 'Mes Documents',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle ?? 'Gérer mes documents scannés',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAccess(BuildContext context, AuthProvider authProvider) {
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connexion requise'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }
}

/// Bouton avec badge de notification
class ProjectAccessButtonWithBadge extends StatelessWidget {
  final int? badgeCount;
  final String? label;
  final Color? color;

  const ProjectAccessButtonWithBadge({
    super.key,
    this.badgeCount,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ProjectAccessButton(
          label: label,
          color: color,
        ),
        if (badgeCount != null && badgeCount! > 0)
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
              child: Center(
                child: Text(
                  badgeCount! > 99 ? '99+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ==================== EXEMPLE D'UTILISATION ====================

class ExampleUsageScreen extends StatelessWidget {
  const ExampleUsageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exemples de Boutons')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== BOUTONS STANDARDS ==========
            const Text(
              'Boutons Standards',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Bouton par défaut
            const ProjectAccessButton(),
            const SizedBox(height: 16),

            // Bouton pleine largeur
            const ProjectAccessButton(
              fullWidth: true,
              label: 'Accéder aux Documents',
            ),
            const SizedBox(height: 16),

            // Bouton small
            const ProjectAccessButton(
              size: ButtonSize.small,
              label: 'Petit Bouton',
            ),
            const SizedBox(height: 16),

            // Bouton large
            const ProjectAccessButton(
              size: ButtonSize.large,
              label: 'Grand Bouton',
            ),
            const SizedBox(height: 32),

            // ========== BOUTON CARD ==========
            const Text(
              'Bouton Card',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            const ProjectAccessCard(
              title: 'Mes Documents',
              subtitle: 'Scanner et gérer vos documents',
              icon: Icons.folder_special_rounded,
            ),
            const SizedBox(height: 32),

            // ========== BOUTON AVEC BADGE ==========
            const Text(
              'Bouton avec Badge',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            const Center(
              child: ProjectAccessButtonWithBadge(
                badgeCount: 5,
                label: 'Documents',
              ),
            ),
            const SizedBox(height: 32),

            // ========== BOUTONS PERSONNALISÉS ==========
            const Text(
              'Boutons Personnalisés',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Bouton vert
            const ProjectAccessButton(
              label: 'Accès Rapide',
              icon: Icons.flash_on_rounded,
              color: Colors.green,
              fullWidth: true,
            ),
            const SizedBox(height: 16),

            // Bouton outlined
            ProjectAccessButton(
              label: 'Voir Projet',
              icon: Icons.visibility_rounded,
              buttonStyle: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D47A1),
                side: const BorderSide(color: Color(0xFF0D47A1), width: 2),
              ),
              fullWidth: true,
            ),
          ],
        ),
      ),
      floatingActionButton: const ProjectAccessFAB(),
    );
  }
}