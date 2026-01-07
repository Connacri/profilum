import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';
import '../responsive_helper.dart';
import '../widgets/account_deletion_dialog.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late AnimationController _animController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _selectedIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _pendingPhotos = [];
  List<Map<String, dynamic>> _users = [];
  String _searchQuery = '';

  // Pagination
  int _photosPage = 0;
  int _usersPage = 0;
  final int _pageSize = 50;
  bool _hasMorePhotos = true;
  bool _hasMoreUsers = true;
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
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      // Stats
      final activeUsers = await _supabase
          .from('profiles')
          .select('id')
          .gte('last_active_at', thirtyDaysAgo.toIso8601String())
          .count();

      final totalUsers = await _supabase.from('profiles').select('id').count();
      final pendingCount = await _supabase
          .from('photos')
          .select('id')
          .eq('status', 'pending')
          .count();

      // Photos avec pagination
      final photos = await _supabase
          .from('photos')
          .select(
            'id, user_id, remote_path, uploaded_at, status, type, profiles!photos_user_id_fkey(full_name, email)',
          )
          .eq('status', 'pending')
          .not('remote_path', 'is', null)
          .order('uploaded_at', ascending: false)
          .range(_photosPage * _pageSize, (_photosPage + 1) * _pageSize - 1);

      _hasMorePhotos = photos.length == _pageSize;

      // Users avec pagination
      final users = await _supabase
          .from('profiles')
          .select('id, email, full_name, role, created_at, profile_completed')
          .order('created_at', ascending: false)
          .range(_usersPage * _pageSize, (_usersPage + 1) * _pageSize - 1);

      _hasMoreUsers = users.length == _pageSize;

      if (!mounted) return;

      setState(() {
        _stats = {
          'active_users': activeUsers.count,
          'total_users': totalUsers.count,
          'pending_photos': pendingCount.count,
          'revenue': 0,
        };
        _pendingPhotos = List<Map<String, dynamic>>.from(photos);
        _users = List<Map<String, dynamic>>.from(users);
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
            'id, user_id, remote_path, uploaded_at, status, type, profiles!photos_user_id_fkey(full_name, email)',
          )
          .eq('status', 'pending')
          .not('remote_path', 'is', null)
          .order('uploaded_at', ascending: false)
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

  Future<void> _loadMoreUsers() async {
    if (!_hasMoreUsers || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    _usersPage++;

    try {
      final users = await _supabase
          .from('profiles')
          .select('id, email, full_name, role, created_at, profile_completed')
          .order('created_at', ascending: false)
          .range(_usersPage * _pageSize, (_usersPage + 1) * _pageSize - 1);

      _hasMoreUsers = users.length == _pageSize;

      if (mounted) {
        setState(() {
          _users.addAll(List<Map<String, dynamic>>.from(users));
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

    // 🎯 LayoutBuilder pour adapter l'UI selon la taille
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile =
            constraints.maxWidth < ResponsiveHelper.mobileBreakpoint;

        return Scaffold(
          key: _scaffoldKey,
          // 📱 Drawer sur mobile uniquement
          drawer: isMobile ? _buildDrawer(theme) : null,
          body: Row(
            children: [
              // 🖥️ Sidebar fixe sur desktop/tablet
              if (!isMobile) _buildSidebar(theme),

              // 📄 Contenu principal
              Expanded(
                child: Column(
                  children: [
                    // 📱 AppBar sur mobile pour ouvrir le drawer
                    if (isMobile) _buildMobileAppBar(theme),

                    // Contenu
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
              const Icon(Icons.shield, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              const Text(
                'ADMIN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (_stats['pending_photos'] != null &&
                  _stats['pending_photos'] > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
              const Divider(),

              // ❌ SUPPRESSION DÉFINITIVE
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'Supprimer mon compte',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Action irréversible',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.red),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const AccountDeletionDialog(),
                  );

                  if (confirmed == true && mounted) {
                    // Redirect automatique vers AuthScreen via AuthProvider
                    // (le status change à accountDeleted)
                  }
                },
              ),
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
    return Container(
      padding: EdgeInsets.all(context.isMobile ? 24 : 32),
      child: Column(
        children: [
          Hero(
            tag: 'admin_shield',
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
                Icons.shield,
                size: context.isMobile ? 30 : 40,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: context.isMobile ? 12 : 16),
          Text(
            'ADMIN',
            style: TextStyle(
              color: Colors.white,
              fontSize: context.isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Dashboard',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: context.isMobile ? 12 : 14,
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
          icon: Icons.people_rounded,
          label: 'Utilisateurs',
          index: 2,
          theme: theme,
        ),
        _buildMenuItem(
          icon: Icons.analytics_rounded,
          label: 'Statistiques',
          index: 3,
          theme: theme,
        ),
        _buildMenuItem(
          icon: Icons.settings_rounded,
          label: 'Paramètres',
          index: 4,
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
            // Fermer le drawer si mobile
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
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge != null && badge != '0')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
              content: const Text('Confirmer la déconnexion ?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
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
        return _buildUsers(theme);
      case 3:
        return _buildAnalytics(theme);
      case 4:
        return _buildSettings(theme);
      default:
        return const SizedBox.shrink();
    }
  }

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
          _buildRecentActivity(theme),
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
                DateFormat('EEEE d MMMM yyyy').format(DateTime.now()),
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
    // 🎯 LayoutBuilder pour calculer dynamiquement les colonnes
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
          childAspectRatio: context.isMobile ? 1.2 : 2,
          children: [
            _buildStatCard(
              theme: theme,
              icon: Icons.people_rounded,
              label: 'Utilisateurs actifs',
              value: _stats['active_users']?.toString() ?? '0',
              color: Colors.blue,
              trend: '+12%',
            ),
            _buildStatCard(
              theme: theme,
              icon: Icons.group_rounded,
              label: 'Total utilisateurs',
              value: _stats['total_users']?.toString() ?? '0',
              color: Colors.green,
              trend: '+8%',
            ),
            _buildStatCard(
              theme: theme,
              icon: Icons.pending_rounded,
              label: 'En attente',
              value: _stats['pending_photos']?.toString() ?? '0',
              color: Colors.orange,
              trend: '-5%',
            ),
            _buildStatCard(
              theme: theme,
              icon: Icons.attach_money_rounded,
              label: 'Revenus',
              value: '€0',
              color: Colors.purple,
              trend: '+0%',
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
    String? trend,
  }) {
    return Card(
      elevation: context.isMobile ? 1 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Container(
        padding: EdgeInsets.all(context.isMobile ? 16 : 10),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(context.isMobile ? 8 : 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: context.isMobile ? 24 : 18,
                  ),
                ),
                if (trend != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: trend.startsWith('+')
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      trend,
                      style: TextStyle(
                        color: trend.startsWith('+')
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: context.isMobile ? 10 : 9,
                      ),
                    ),
                  ),
              ],
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(ThemeData theme) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Activité récente',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedIndex = 2),
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._users
                .take(5)
                .map((user) => _buildActivityItem(theme: theme, user: user)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem({
    required ThemeData theme,
    required Map<String, dynamic> user,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          (user['full_name'] ?? user['email'])[0].toUpperCase(),
          style: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(user['full_name'] ?? user['email']),
      subtitle: Text(
        'Inscrit ${DateFormat('dd/MM/yyyy').format(DateTime.parse(user['created_at']))}',
      ),
      trailing: Chip(
        label: Text(user['role']),
        backgroundColor: theme.colorScheme.secondaryContainer,
      ),
    );
  }

  /// 🎨 MODÉRATION - UI/UX OPTIMISÉE
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
            label: Text(context.isMobile ? 'Actualiser' : 'Actualiser'),
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

  /// 🎯 GRID RESPONSIVE POUR LA MODÉRATION
  Widget _buildModerationGrid(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 🎨 Calcul dynamique des colonnes selon la largeur disponible
        final columns = ResponsiveHelper.getColumnsFromItemWidth(
          constraints.maxWidth - (context.adaptivePadding.horizontal),
          targetItemWidth: 280, // Largeur cible d'une carte photo
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
                  childAspectRatio: ResponsiveHelper.getCardAspectRatio(
                    context,
                  ),
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final photo = _pendingPhotos[index];
                  return _buildPhotoCard(theme, photo);
                }, childCount: _pendingPhotos.length),
              ),
            ),

            // Bouton charger plus
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
                            label: const Text('Charger plus de photos'),
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

  /// 🖼️ CARTE PHOTO OPTIMISÉE
  Widget _buildPhotoCard(ThemeData theme, Map<String, dynamic> photo) {
    final remotePath = photo['remote_path'];
    if (remotePath == null || remotePath.isEmpty) {
      return _buildErrorCard(theme, 'URL manquante');
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
          // 🖼️ Image
          Expanded(
            flex: 3,
            child: Hero(
              tag: 'photo_${photo['id']}',
              child: CachedNetworkImage(
                imageUrl: remotePath,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: theme.colorScheme.surfaceVariant,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text('Chargement...', style: theme.textTheme.bodySmall),
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
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // 📝 Infos
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
                      DateFormat(
                        'dd/MM HH:mm',
                      ).format(DateTime.parse(photo['uploaded_at'])),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 🎯 Boutons d'action
          Padding(
            padding: EdgeInsets.all(context.isMobile ? 12 : 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectPhoto(photo),
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(context.isMobile ? 'Refuser' : 'Refuser'),
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
                    label: Text(context.isMobile ? 'Valider' : 'Valider'),
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

  Widget _buildErrorCard(ThemeData theme, String message) {
    return Card(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 8),
            Text(message, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Future<void> _approvePhoto(Map<String, dynamic> photo) async {
    try {
      final moderatorId = _supabase.auth.currentUser!.id;
      await _supabase
          .from('photos')
          .update({
            'status': 'approved',
            'moderated_at': DateTime.now().toIso8601String(),
            'moderator_id': moderatorId,
          })
          .eq('id', photo['id']);

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
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Photo approuvée avec succès'),
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
          children:
              [
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
      await _supabase
          .from('photos')
          .update({
            'status': 'rejected',
            'moderated_at': DateTime.now().toIso8601String(),
            'moderator_id': moderatorId,
            'rejection_reason': reason,
          })
          .eq('id', photo['id']);

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

  /// 👥 GESTION DES UTILISATEURS
  Widget _buildUsers(ThemeData theme) {
    final filteredUsers = _users.where((u) {
      if (_searchQuery.isEmpty) return true;
      final name = (u['full_name'] ?? '').toLowerCase();
      final email = (u['email'] ?? '').toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Container(
          padding: context.adaptivePadding,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gestion des utilisateurs',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_users.length} utilisateur${_users.length > 1 ? 's' : ''}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ],
          ),
        ),
        Expanded(
          child: Card(
            margin: EdgeInsets.fromLTRB(
              context.adaptivePadding.left,
              0,
              context.adaptivePadding.right,
              context.adaptivePadding.bottom,
            ),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: ListView.separated(
              itemCount: filteredUsers.length + (_hasMoreUsers ? 1 : 0),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == filteredUsers.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: _isLoadingMore
                          ? const CircularProgressIndicator()
                          : OutlinedButton.icon(
                              onPressed: _loadMoreUsers,
                              icon: const Icon(Icons.expand_more),
                              label: const Text('Charger plus d\'utilisateurs'),
                            ),
                    ),
                  );
                }
                return _buildUserItem(theme, filteredUsers[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserItem(ThemeData theme, Map<String, dynamic> user) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          (user['full_name'] ?? user['email'])[0].toUpperCase(),
          style: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(user['full_name'] ?? user['email']),
      subtitle: Text(user['email']),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(user['role']),
            backgroundColor: theme.colorScheme.secondaryContainer,
          ),
          const SizedBox(width: 8),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('Modifier'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'suspend',
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Suspendre'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Supprimer'),
                  ],
                ),
              ),
            ],
            onSelected: (value) => _handleUserAction(value, user),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUserAction(
    String action,
    Map<String, dynamic> user,
  ) async {
    final supabase = Supabase.instance.client;

    switch (action) {
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmer suppression'),
            content: Text('Supprimer ${user['full_name'] ?? user['email']} ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        try {
          final response = await supabase
              .from('profiles')
              .delete()
              .eq('id', user['id']);

          if (response.error != null) {
            throw Exception(response.error!.message);
          }

          if (mounted) {
            setState(() => _users.removeWhere((u) => u['id'] == user['id']));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Utilisateur supprimé'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur suppression: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;

      case 'edit':
        final updatedUser = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(builder: (_) => EditUserPage(user: user)),
        );
        if (updatedUser != null && mounted) {
          setState(() {
            final i = _users.indexWhere((u) => u['id'] == updatedUser['id']);
            if (i != -1) _users[i] = updatedUser;
          });
        }
        break;

      default:
        debugPrint('Action inconnue: $action');
    }
  }

  Widget _buildAnalytics(ThemeData theme) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.analytics, size: 80, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text('Statistiques avancées', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('À venir...', style: theme.textTheme.bodyLarge),
      ],
    ),
  );

  Widget _buildSettings(ThemeData theme) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.settings, size: 80, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text('Paramètres', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('À venir...', style: theme.textTheme.bodyLarge),
      ],
    ),
  );
}

class EditUserPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const EditUserPage({super.key, required this.user});

  @override
  State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user['full_name']);
    _emailController = TextEditingController(text: widget.user['email']);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .update({
            'full_name': _fullNameController.text.trim(),
            'email': _emailController.text.trim(),
          })
          .eq('id', widget.user['id']);

      if (response.error != null) {
        throw Exception(response.error!.message);
      }

      Navigator.pop(context, {
        'id': widget.user['id'],
        'full_name': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur mise à jour: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Éditer utilisateur')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(labelText: 'Nom complet'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
