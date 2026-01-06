// lib/screens/moderator_panel_modern.dart - DESIGN MODERNE TYPE APP MOBILE
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';

class ModeratorPanelScreen extends StatefulWidget {
  const ModeratorPanelScreen({super.key});

  @override
  State<ModeratorPanelScreen> createState() => _ModeratorPanelScreenState();
}

class _ModeratorPanelScreenState extends State<ModeratorPanelScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _pendingPhotos = [];
  int _currentPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final pendingCount = await _supabase
          .from('photos')
          .select('id')
          .eq('status', 'pending')
          .count();

      final moderatorId = _supabase.auth.currentUser!.id;
      final today = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String();

      final approvedToday = await _supabase
          .from('photos')
          .select('id')
          .eq('moderator_id', moderatorId)
          .eq('status', 'approved')
          .gte('moderated_at', today)
          .count();

      final rejectedToday = await _supabase
          .from('photos')
          .select('id')
          .eq('moderator_id', moderatorId)
          .eq('status', 'rejected')
          .gte('moderated_at', today)
          .count();

      final photos = await _supabase
          .from('photos')
          .select(
            'id, user_id, remote_path, uploaded_at, type, has_watermark, profiles!photos_user_id_fkey(full_name, email, gender, city)',
          )
          .eq('status', 'pending')
          .not('remote_path', 'is', null)
          .order('uploaded_at', ascending: true)
          .limit(50);

      if (!mounted) return;

      setState(() {
        _stats = {
          'pending': pendingCount.count,
          'approved': approvedToday.count,
          'rejected': rejectedToday.count,
          'total': approvedToday.count + rejectedToday.count,
        };
        _pendingPhotos = List<Map<String, dynamic>>.from(photos);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildModernAppBar(theme),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDashboard(theme),
                      _buildSwipeModeration(theme),
                      _buildProfile(theme),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomNav(theme),
    );
  }

  /// 🎨 MODERN APP BAR
  Widget _buildModernAppBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Modération',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_stats['pending'] ?? 0} en attente',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 📊 DASHBOARD MODERNE
  Widget _buildDashboard(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Aujourd\'hui',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildCompactStatsGrid(theme),
          const SizedBox(height: 24),
          _buildQuickActionCard(theme),
          const SizedBox(height: 24),
          _buildRecentActivity(theme),
        ],
      ),
    );
  }

  /// 📊 COMPACT STATS
  Widget _buildCompactStatsGrid(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildCompactStat(
            theme,
            'En attente',
            _stats['pending'] ?? 0,
            Colors.orange,
            Icons.pending,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCompactStat(
            theme,
            'Validées',
            _stats['approved'] ?? 0,
            Colors.green,
            Icons.check_circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCompactStat(
            theme,
            'Rejetées',
            _stats['rejected'] ?? 0,
            Colors.red,
            Icons.cancel,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStat(
    ThemeData theme,
    String label,
    int value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12), // ✅ Réduit de 16 → 12
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ AJOUTÉ - évite expansion
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24), // ✅ Réduit 28 → 24
          const SizedBox(height: 6), // ✅ Réduit 8 → 6
          Text(
            '$value',
            style: theme.textTheme.titleLarge?.copyWith(
              // ✅ headlineSmall → titleLarge
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2), // ✅ AJOUTÉ - espacement
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
            ), // ✅ Force plus petit
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// ⚡ QUICK ACTION
  Widget _buildQuickActionCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: InkWell(
        onTap: () => _tabController.animateTo(1),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.secondaryContainer,
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.swipe,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modérer maintenant',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Swipe pour valider/rejeter',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  /// 📜 RECENT ACTIVITY
  Widget _buildRecentActivity(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activité récente',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._pendingPhotos.take(3).map((photo) {
          final profile = photo['profiles'];
          final userName =
              profile?['full_name'] ?? profile?['email'] ?? 'Utilisateur';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: photo['remote_path'] != null
                    ? CachedNetworkImageProvider(photo['remote_path'])
                    : null,
                child: photo['remote_path'] == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(
                userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'Il y a ${_timeAgo(DateTime.parse(photo['uploaded_at']))}',
                style: theme.textTheme.bodySmall,
              ),
              trailing: Chip(
                label: const Text('En attente', style: TextStyle(fontSize: 11)),
                backgroundColor: Colors.orange.withOpacity(0.2),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 1) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}j';
  }

  /// 🎴 SWIPE MODERATION
  Widget _buildSwipeModeration(ThemeData theme) {
    if (_pendingPhotos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.green.shade300),
            const SizedBox(height: 16),
            Text('Tout est modéré !', style: theme.textTheme.headlineSmall),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Photo courante
        Positioned.fill(
          child: _buildSwipeCard(theme, _pendingPhotos[_currentPhotoIndex]),
        ),

        // Counter
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentPhotoIndex + 1} / ${_pendingPhotos.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        // Actions
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildSwipeActions(theme),
        ),
      ],
    );
  }

  Widget _buildSwipeCard(ThemeData theme, Map<String, dynamic> photo) {
    final profile = photo['profiles'];
    final userName =
        profile?['full_name'] ?? profile?['email'] ?? 'Utilisateur';

    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: photo['remote_path'],
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: theme.colorScheme.surfaceVariant,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),

                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.white,
                                child: Text(
                                  userName[0].toUpperCase(),
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      profile?['city'] ?? '',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (photo['has_watermark'] == true)
                                Chip(
                                  label: const Text(
                                    'Caméra',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  avatar: const Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                  ),
                                  backgroundColor: Colors.purple.withOpacity(
                                    0.3,
                                  ),
                                  labelStyle: const TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              Chip(
                                label: Text(
                                  _timeAgo(
                                    DateTime.parse(photo['uploaded_at']),
                                  ),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor: Colors.white24,
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwipeActions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Reject
          FloatingActionButton.large(
            heroTag: 'reject',
            onPressed: () => _rejectPhoto(_pendingPhotos[_currentPhotoIndex]),
            backgroundColor: Colors.red,
            child: const Icon(Icons.close, size: 36),
          ),

          // Info
          FloatingActionButton(
            heroTag: 'info',
            onPressed: _showPhotoInfo,
            backgroundColor: theme.colorScheme.surface,
            child: Icon(Icons.info_outline, color: theme.colorScheme.primary),
          ),

          // Approve
          FloatingActionButton.large(
            heroTag: 'approve',
            onPressed: () => _approvePhoto(_pendingPhotos[_currentPhotoIndex]),
            backgroundColor: Colors.green,
            child: const Icon(Icons.check, size: 36),
          ),
        ],
      ),
    );
  }

  void _showPhotoInfo() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Détails de la photo',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // Info photo
            const Text('Informations détaillées ici...'),
          ],
        ),
      ),
    );
  }

  /// 👤 PROFILE
  Widget _buildProfile(ThemeData theme) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  (user?.fullName ?? 'M')[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user?.fullName ?? 'Modérateur',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Chip(
                label: const Text('MODÉRATEUR'),
                backgroundColor: theme.colorScheme.secondaryContainer,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('Mes statistiques'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Historique'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Paramètres'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.read<AuthProvider>().signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Déconnexion'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  /// 🔽 BOTTOM NAV
  Widget _buildBottomNav(ThemeData theme) {
    return NavigationBar(
      selectedIndex: _tabController.index,
      onDestinationSelected: (i) => _tabController.animateTo(i),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Badge(
            label: Text('${_stats['pending'] ?? 0}'),
            child: const Icon(Icons.photo_library_outlined),
          ),
          selectedIcon: const Icon(Icons.photo_library),
          label: 'Modération',
        ),
        NavigationDestination(
          icon: const Icon(Icons.person_outline),
          selectedIcon: const Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    );
  }

  Future<void> _approvePhoto(Map<String, dynamic> photo) async {
    try {
      await _supabase
          .from('photos')
          .update({
            'status': 'approved',
            'moderated_at': DateTime.now().toIso8601String(),
            'moderator_id': _supabase.auth.currentUser!.id,
          })
          .eq('id', photo['id']);

      if (mounted) {
        setState(() {
          _pendingPhotos.removeAt(_currentPhotoIndex);
          if (_currentPhotoIndex >= _pendingPhotos.length &&
              _currentPhotoIndex > 0) {
            _currentPhotoIndex--;
          }
          _stats['pending'] = (_stats['pending'] ?? 1) - 1;
          _stats['approved'] = (_stats['approved'] ?? 0) + 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Photo validée'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Approve error: $e');
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
                    'Pas de visage',
                    'Autre',
                  ]
                  .map(
                    (r) => ListTile(
                      title: Text(r),
                      onTap: () => Navigator.pop(ctx, r),
                    ),
                  )
                  .toList(),
        ),
      ),
    );

    if (reason == null) return;

    try {
      await _supabase
          .from('photos')
          .update({
            'status': 'rejected',
            'moderated_at': DateTime.now().toIso8601String(),
            'moderator_id': _supabase.auth.currentUser!.id,
            'rejection_reason': reason,
          })
          .eq('id', photo['id']);

      if (mounted) {
        setState(() {
          _pendingPhotos.removeAt(_currentPhotoIndex);
          if (_currentPhotoIndex >= _pendingPhotos.length &&
              _currentPhotoIndex > 0) {
            _currentPhotoIndex--;
          }
          _stats['pending'] = (_stats['pending'] ?? 1) - 1;
          _stats['rejected'] = (_stats['rejected'] ?? 0) + 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Photo rejetée: $reason'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Reject error: $e');
    }
  }
}
