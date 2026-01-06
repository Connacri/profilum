// lib/moderator_panel_complete.dart - UI COMPLÈTE
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';
import '../responsive_helper.dart';

class ModeratorPanelScreen extends StatefulWidget {
  const ModeratorPanelScreen({super.key});

  @override
  State<ModeratorPanelScreen> createState() => _ModeratorPanelScreenState();
}

class _ModeratorPanelScreenState extends State<ModeratorPanelScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late AnimationController _animController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _selectedIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _pendingPhotos = [];
  int _photosPage = 0;
  final int _pageSize = 50;
  bool _hasMorePhotos = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animController.forward();
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Stats
      final pendingCount = await _supabase
          .from('photos')
          .select('id')
          .eq('status', 'pending')
          .count();

      final moderatorId = _supabase.auth.currentUser!.id;

      final approvedToday = await _supabase
          .from('photos')
          .select('id')
          .eq('moderator_id', moderatorId)
          .eq('status', 'approved')
          .gte('moderated_at', DateTime.now().subtract(const Duration(days: 1)).toIso8601String())
          .count();

      final rejectedToday = await _supabase
          .from('photos')
          .select('id')
          .eq('moderator_id', moderatorId)
          .eq('status', 'rejected')
          .gte('moderated_at', DateTime.now().subtract(const Duration(days: 1)).toIso8601String())
          .count();

      // Photos en attente
      final photos = await _supabase
          .from('photos')
          .select(
            'id, user_id, remote_path, uploaded_at, status, type, has_watermark, profiles!photos_user_id_fkey(full_name, email)',
          )
          .eq('status', 'pending')
          .not('remote_path', 'is', null)
          .order('uploaded_at', ascending: true)
          .range(_photosPage * _pageSize, (_photosPage + 1) * _pageSize - 1);

      _hasMorePhotos = photos.length == _pageSize;

      if (!mounted) return;

      setState(() {
        _stats = {
          'pending_photos': pendingCount.count,
          'approved_today': approvedToday.count,
          'rejected_today': rejectedToday.count,
          'total_today': approvedToday.count + rejectedToday.count,
        };
        _pendingPhotos = List<Map<String, dynamic>>.from(photos);
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('❌ Load error: $e');
      debugPrint('Stack: $stack');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMorePhotos() async {
    if (!_hasMorePhotos || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    _photosPage++;

    try {
      final photos = await _supabase
          .from('photos')
          .select(
            'id, user_id, remote_path, uploaded_at, status, type, has_watermark, profiles!photos_user_id_fkey(full_name, email)',
          )
          .eq('status', 'pending')
          .not('remote_path', 'is', null)
          .order('uploaded_at', ascending: true)
          .range(_photosPage * _pageSize, (_photosPage + 1) * _pageSize - 1);

      _hasMorePhotos = photos.length == _pageSize;

      if (mounted) {
        setState(() {
          _pendingPhotos.addAll(List<Map<String, dynamic>>.from(photos));
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Load more error: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < ResponsiveHelper.mobileBreakpoint;

        return Scaffold(
          key: _scaffoldKey,
          drawer: isMobile ? _buildDrawer(theme) : null,
          body: Row(
            children: [
              if (!isMobile) _buildSidebar(theme),
              Expanded(
                child: Column(
                  children: [
                    if (isMobile) _buildMobileAppBar(theme),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildContent(theme),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 📱 AppBar pour mobile
  Widget _buildMobileAppBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.verified_user, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              const Text(
                'MODÉRATEUR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (_stats['pending_photos'] != null && _stats['pending_photos'] > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_stats['pending_photos']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 📱 Drawer pour mobile
  Widget _buildDrawer(ThemeData theme) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildDrawerHeader(theme),
              const Divider(color: Colors.white24),
              Expanded(child: _buildMenuItems(theme)),
              const Divider(color: Colors.white24),
              _buildLogoutButton(theme),
            ],
          ),
        ),
      ),
    );
  }

  /// 🖥️ Sidebar fixe pour desktop
  Widget _buildSidebar(ThemeData theme) {
    return Container(
      width: ResponsiveHelper.getSidebarWidth(context),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDrawerHeader(theme),
          const Divider(color: Colors.white24),
          Expanded(child: _buildMenuItems(theme)),
          const Divider(color: Colors.white24),
          _buildLogoutButton(theme),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(ThemeData theme) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return Container(
      padding: EdgeInsets.all(context.isMobile ? 24 : 32),
      child: Column(
        children: [
          Hero(
            tag: 'moderator_avatar',
            child: Container(
              width: context.isMobile ? 60 : 80,
              height: context.isMobile ? 60 : 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.verified_user,
                size: context.isMobile ? 30 : 40,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: context.isMobile ? 12 : 16),
          Text(
            user?.fullName ?? 'Modérateur',
            style: TextStyle(
              color: Colors.white,
              fontSize: context.isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'MODÉRATEUR',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: context.isMobile ? 10 : 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems(ThemeData theme) {
    return ListView(
      padding: EdgeInsets.symmetric(vertical: context.isMobile ? 4 : 8),
      children: [
        _buildMenuItem(
          icon: Icons.dashboard_rounded,
          label: 'Vue d\'ensemble',
          index: 0,
          theme: theme,
        ),
        _buildMenuItem(
          icon: Icons.photo_library_rounded,
          label: 'Modération',
          index: 1,
          badge: _stats['pending_photos']?.toString(),
          theme: theme,
        ),
        _buildMenuItem(
          icon: Icons.history_rounded,
          label: 'Historique',
          index: 2,
          theme: theme,
        ),
        _buildMenuItem(
          icon: Icons.bar_chart_rounded,
          label: 'Mes statistiques',
          index: 3,
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required int index,
    String? badge,
    required ThemeData theme,
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.isMobile ? 8 : 12,
        vertical: 4,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _selectedIndex = index);
            if (context.isMobile) {
              Navigator.of(context).pop();
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: context.isMobile ? 16 : 20,
              vertical: context.isMobile ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withOpacity(0.25)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withOpacity(0.4)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: context.isMobile ? 22 : 24,
                ),
                SizedBox(width: context.isMobile ? 12 : 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: context.isMobile ? 14 : 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.all(context.isMobile ? 12 : 16),
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Déconnexion'),
              content: const Text('Voulez-vous vraiment vous déconnecter ?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Déconnexion'),
                ),
              ],
            ),
          );

          if (confirmed == true && mounted) {
            await context.read<AuthProvider>().signOut();
          }
        },
        icon: const Icon(Icons.logout, color: Colors.white),
        label: Text(
          'Déconnexion',
          style: TextStyle(
            color: Colors.white,
            fontSize: context.isMobile ? 14 : 16,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white, width: 2),
          padding: EdgeInsets.symmetric(vertical: context.isMobile ? 12 : 16),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    switch (_selectedIndex) {
      case 0:
        return _buildOverview(theme);
      case 1:
        return _buildModeration(theme);
      case 2:
        return _buildHistory(theme);
      case 3:
        return _buildMyStats(theme);
      default:
        return const SizedBox.shrink();
    }
  }

  /// 📊 VUE D'ENSEMBLE
  Widget _buildOverview(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: context.adaptivePadding,
        children: [
          _buildOverviewHeader(theme),
          SizedBox(height: context.adaptiveSpacing * 2),
          _buildStatsGrid(theme),
          SizedBox(height: context.adaptiveSpacing * 2),
          _buildQuickActions(theme),
        ],
      ),
    );
  }

  Widget _buildOverviewHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vue d\'ensemble',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveHelper.getAdaptiveFontSize(context, 28),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(DateTime.now()),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (!context.isMobile)
          IconButton.filled(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
      ],
    );
  }

  Widget _buildStatsGrid(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ResponsiveHelper.getGridColumns(
          context,
          customMobile: 2,
          customTablet: 2,
          customDesktop: 4,
        );

        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: context.adaptiveSpacing,
          crossAxisSpacing: context.adaptiveSpacing,
          childAspectRatio: context.isMobile ? 1.2 : 2.5,
          children: [
            _buildStatCard(
              theme: theme,
              icon: Icons.pending_rounded,
              label: 'En attente',
              value: _stats['pending_photos']?.toString() ?? '0',
              color: Colors.orange,
            ),
            _buildStatCard(
              theme: theme,
              icon: Icons.check_circle_rounded,
              label: 'Validées (24h)',
              value: _stats['approved_today']?.toString() ?? '0',
              color: Colors.green,
            ),
            _buildStatCard(
              theme: theme,
              icon: Icons.cancel_rounded,
              label: 'Rejetées (24h)',
              value: _stats['rejected_today']?.toString() ?? '0',
              color: Colors.red,
            ),
            _buildStatCard(
              theme: theme,
              icon: Icons.assessment_rounded,
              label: 'Total (24h)',
              value: _stats['total_today']?.toString() ?? '0',
              color: Colors.blue,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: context.isMobile ? 1 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Container(
        padding: EdgeInsets.all(context.isMobile ? 16 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.all(context.isMobile ? 8 : 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: context.isMobile ? 24 : 18),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: ResponsiveHelper.getAdaptiveFontSize(context, 22),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: context.isMobile ? 12 : 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: context.adaptivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions rapides',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => setState(() => _selectedIndex = 1),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Modérer les photos'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _selectedIndex = 3),
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('Mes statistiques'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 🖼️ MODÉRATION
  Widget _buildModeration(ThemeData theme) {
    return Column(
      children: [
        _buildModerationHeader(theme),
        Expanded(
          child: _pendingPhotos.isEmpty
              ? _buildEmptyModeration(theme)
              : _buildModerationGrid(theme),
        ),
      ],
    );
  }

  Widget _buildModerationHeader(ThemeData theme) {
    return Container(
      padding: context.adaptivePadding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modération des photos',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveHelper.getAdaptiveFontSize(context, 28),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_pendingPhotos.length} photo${_pendingPhotos.length > 1 ? 's' : ''} en attente',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualiser'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyModeration(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: context.isMobile ? 64 : 80,
            color: Colors.green[300],
          ),
          SizedBox(height: context.adaptiveSpacing),
          Text('Aucune photo en attente', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Toutes les photos ont été modérées',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModerationGrid(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ResponsiveHelper.getColumnsFromItemWidth(
          constraints.maxWidth - (context.adaptivePadding.horizontal),
          targetItemWidth: 280,
        ).clamp(1, 6);

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: context.adaptivePadding,
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: context.adaptiveSpacing,
                  mainAxisSpacing: context.adaptiveSpacing,
                  childAspectRatio: ResponsiveHelper.getCardAspectRatio(context),
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final photo = _pendingPhotos[index];
                    return _buildPhotoCard(theme, photo);
                  },
                  childCount: _pendingPhotos.length,
                ),
              ),
            ),
            if (_hasMorePhotos)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(context.adaptiveSpacing * 2),
                  child: Center(
                    child: _isLoadingMore
                        ? const CircularProgressIndicator()
                        : OutlinedButton.icon(
                            onPressed: _loadMorePhotos,
                            icon: const Icon(Icons.expand_more),
                            label: const Text('Charger plus'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPhotoCard(ThemeData theme, Map<String, dynamic> photo) {
    final remotePath = photo['remote_path'];
    if (remotePath == null || remotePath.isEmpty) {
      return Card(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 8),
              Text('URL manquante', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    final profiles = photo['profiles'];
    final userName = profiles != null
        ? (profiles['full_name'] ?? profiles['email'] ?? 'Utilisateur inconnu')
        : 'Utilisateur inconnu';

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: context.isMobile ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Hero(
              tag: 'photo_${photo['id']}',
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: remotePath,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (_, __) => Container(
                      color: theme.colorScheme.surfaceVariant,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: theme.colorScheme.errorContainer,
                      child: Icon(
                        Icons.broken_image,
                        size: 48,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                  if (photo['has_watermark'] == true)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.verified, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Watermark',
                              style: TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(context.isMobile ? 12 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        userName[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd/MM HH:mm').format(
                        DateTime.parse(photo['uploaded_at']),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(context.isMobile ? 12 : 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectPhoto(photo),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Refuser'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: EdgeInsets.symmetric(
                        vertical: context.isMobile ? 12 : 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _approvePhoto(photo),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Valider'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(
                        vertical: context.isMobile ? 12 : 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approvePhoto(Map<String, dynamic> photo) async {
    try {
      final moderatorId = _supabase.auth.currentUser!.id;
      await _supabase.from('photos').update({
        'status': 'approved',
        'moderated_at': DateTime.now().toIso8601String(),
        'moderator_id': moderatorId,
      }).eq('id', photo['id']);

      await _supabase.from('notifications').insert({
        'user_id': photo['user_id'],
        'type': 'photo_approved',
        'title': 'Photo approuvée ✓',
        'body': 'Votre photo a été validée',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        setState(() {
          _pendingPhotos.removeWhere((p) => p['id'] == photo['id']);
          _stats['pending_photos'] = (_stats['pending_photos'] ?? 1) - 1;
          _stats['approved_today'] = (_stats['approved_today'] ?? 0) + 1;
          _stats['total_today'] = (_stats['total_today'] ?? 0) + 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Photo approuvée'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Approve error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectPhoto(Map<String, dynamic> photo) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Raison du rejet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            'Contenu inapproprié',
            'Mauvaise qualité',
            'Pas de visage visible',
            'Violation des règles',
          ]
              .map(
                (r) => ListTile(
                  title: Text(r),
                  onTap: () => Navigator.pop(ctx, r),
                  leading: const Icon(Icons.report_problem),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (reason == null) return;

    try {
      final moderatorId = _supabase.auth.currentUser!.id;
      await _supabase.from('photos').update({
        'status': 'rejected',
        'moderated_at': DateTime.now().toIso8601String(),
        'moderator_id': moderatorId,
        'rejection_reason': reason,
      }).eq('id', photo['id']);

      await _supabase.from('notifications').insert({
        'user_id': photo['user_id'],
        'type': 'photo_rejected',
        'title': 'Photo rejetée',
        'body': 'Raison: $reason',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        setState(() {
          _pendingPhotos.removeWhere((p) => p['id'] == photo['id']);
          _stats['pending_photos'] = (_stats['pending_photos'] ?? 1) - 1;
          _stats['rejected_today'] = (_stats['rejected_today'] ?? 0) + 1;
          _stats['total_today'] = (_stats['total_today'] ?? 0) + 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.block, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Photo rejetée: $reason')),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Reject error: $e');
    }
  }

  /// 📜 HISTORIQUE
  Widget _buildHistory(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('Historique', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('À venir...', style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  /// 📊 MES STATISTIQUES
  Widget _buildMyStats(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 80, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('Mes statistiques', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('À venir...', style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}