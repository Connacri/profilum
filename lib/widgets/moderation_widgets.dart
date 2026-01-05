import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_constants.dart';
import '../responsive_helper.dart';

/// 🖼️ Carte photo optimisée pour la modération
class ModerationPhotoCard extends StatefulWidget {
  final Map<String, dynamic> photo;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool isLoading;

  const ModerationPhotoCard({
    super.key,
    required this.photo,
    required this.onApprove,
    required this.onReject,
    this.isLoading = false,
  });

  @override
  State<ModerationPhotoCard> createState() => _ModerationPhotoCardState();
}

class _ModerationPhotoCardState extends State<ModerationPhotoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppConstants.animationFast,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remotePath = widget.photo['remote_path'];

    if (remotePath == null || remotePath.isEmpty) {
      return _buildErrorCard(theme, 'URL manquante');
    }

    final profiles = widget.photo['profiles'];
    final userName = profiles != null
        ? (profiles['full_name'] ?? profiles['email'] ?? 'Utilisateur inconnu')
        : 'Utilisateur inconnu';

    return MouseRegion(
      onEnter: (_) => setState(() {
        _isHovered = true;
        _controller.forward();
      }),
      onExit: (_) => setState(() {
        _isHovered = false;
        _controller.reverse();
      }),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: _isHovered
              ? AppConstants.cardElevationHover
              : AppConstants.cardElevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
            side: BorderSide(
              color: _isHovered
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : theme.dividerColor,
              width: _isHovered ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildImageSection(theme, remotePath),
                  _buildInfoSection(theme, userName),
                  _buildActionsSection(theme),
                ],
              ),

              // Loading overlay
              if (widget.isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(ThemeData theme, String remotePath) {
    return Expanded(
      flex: 3,
      child: Hero(
        tag: 'photo_${widget.photo['id']}',
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: remotePath,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (_, __) => Container(
                color: theme.colorScheme.surfaceVariant,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Chargement...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              errorWidget: (_, url, error) {
                debugPrint('❌ Image load error: $url - $error');
                return Container(
                  color: theme.colorScheme.errorContainer,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image,
                        size: context.isMobile ? 32 : 48,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Erreur chargement',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),

            // Badge de type
            Positioned(top: 8, right: 8, child: _buildTypeBadge(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(ThemeData theme) {
    final type = widget.photo['type'] ?? 'profile';
    final icon = type == 'profile' ? Icons.person : Icons.photo;
    final label = type == 'profile' ? 'Profil' : 'Photo';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(ThemeData theme, String userName) {
    return Container(
      padding: EdgeInsets.all(context.isMobile ? 12 : 10),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Utilisateur
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  userName[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  userName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Date et heure
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                DateFormat(
                  'dd/MM/yyyy HH:mm',
                ).format(DateTime.parse(widget.photo['uploaded_at'])),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              _buildQuickViewButton(theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickViewButton(ThemeData theme) {
    return IconButton(
      icon: Icon(Icons.zoom_in, size: 18, color: theme.colorScheme.primary),
      onPressed: () => _showFullScreenPreview(context),
      tooltip: 'Voir en plein écran',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildActionsSection(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(context.isMobile ? 12 : 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.isLoading ? null : widget.onReject,
              icon: const Icon(Icons.close, size: 18),
              label: Text(context.isMobile ? 'Refuser' : 'Refuser'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConstants.rejectedColor,
                side: BorderSide(color: AppConstants.rejectedColor),
                padding: EdgeInsets.symmetric(
                  vertical: context.isMobile ? 12 : 8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: widget.isLoading ? null : widget.onApprove,
              icon: const Icon(Icons.check, size: 18),
              label: Text(context.isMobile ? 'Valider' : 'Valider'),
              style: FilledButton.styleFrom(
                backgroundColor: AppConstants.approvedColor,
                padding: EdgeInsets.symmetric(
                  vertical: context.isMobile ? 12 : 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme, String message) {
    return Card(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 8),
            Text(message, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  void _showFullScreenPreview(BuildContext context) {
    final remotePath = widget.photo['remote_path'];
    if (remotePath == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: remotePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🎯 Bouton de chargement de plus d'items
class LoadMoreButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final String label;

  const LoadMoreButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Charger plus',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.adaptiveSpacing * 2),
        child: isLoading
            ? const CircularProgressIndicator()
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.expand_more),
                label: Text(label),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
      ),
    );
  }
}

/// 📊 Widget de statistiques avec animation
class AnimatedStatCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? trend;

  const AnimatedStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.trend,
  });

  @override
  State<AnimatedStatCard> createState() => _AnimatedStatCardState();
}

class _AnimatedStatCardState extends State<AnimatedStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Card(
          elevation: context.isMobile ? 1 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Container(
            padding: EdgeInsets.all(context.isMobile ? 16 : 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusL),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.color.withOpacity(0.1),
                  widget.color.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.isMobile ? 8 : 6),
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusS,
                        ),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.color,
                        size: context.isMobile ? 24 : 18,
                      ),
                    ),
                    if (widget.trend != null) _buildTrendBadge(widget.trend!),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                        fontSize: ResponsiveHelper.getAdaptiveFontSize(
                          context,
                          22,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: context.isMobile ? 12 : 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrendBadge(String trend) {
    final isPositive = trend.startsWith('+');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPositive
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            size: 12,
            color: isPositive ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 2),
          Text(
            trend,
            style: TextStyle(
              color: isPositive ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: context.isMobile ? 10 : 9,
            ),
          ),
        ],
      ),
    );
  }
}

/// 🔍 Barre de recherche améliorée
class ResponsiveSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String? hintText;
  final VoidCallback? onClear;

  const ResponsiveSearchBar({
    super.key,
    this.controller,
    this.onChanged,
    this.hintText,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText ?? 'Rechercher...',
        prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
        suffixIcon: controller?.text.isNotEmpty == true
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller?.clear();
                  onClear?.call();
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      ),
    );
  }
}
