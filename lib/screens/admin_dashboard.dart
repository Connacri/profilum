import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late AnimationController _animController;

  int _selectedIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _pendingPhotos = [];
  List<Map<String, dynamic>> _users = [];
  String _searchQuery = '';

  // ✅ NOUVEAU: Pagination
  int _photosPage = 0;
  int _usersPage = 0;
  final int _pageSize = 50;
  bool _hasMorePhotos = true;
  bool _hasMoreUsers = true;
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

  // Remplace uniquement la méthode _loadData (ligne ~40-95)

  // 4️⃣ MODIFIER _loadData avec pagination (ligne ~40)
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      debugPrint('🔵 Loading admin data...');

      // Stats (inchangé)
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

      debugPrint(
        '📊 Stats: ${activeUsers.count} active, ${totalUsers.count} total, ${pendingCount.count} pending',
      );

      // ✅ Photos avec pagination
      final photos = await _supabase
          .from('photos')
          .select(
            'id, user_id, remote_path, uploaded_at, status, type, profiles!photos_user_id_fkey(full_name, email)',
          )
          .eq('status', 'pending')
          .not('remote_path', 'is', null)
          .order('uploaded_at', ascending: false)
          .range(
            _photosPage * _pageSize,
            (_photosPage + 1) * _pageSize - 1,
          ); // ✅ PAGINATION

      _hasMorePhotos = photos.length == _pageSize;

      // ✅ Users avec pagination
      final users = await _supabase
          .from('profiles')
          .select('id, email, full_name, role, created_at, profile_completed')
          .order('created_at', ascending: false)
          .range(
            _usersPage * _pageSize,
            (_usersPage + 1) * _pageSize - 1,
          ); // ✅ PAGINATION

      _hasMoreUsers = users.length == _pageSize;

      debugPrint(
        '📸 Photos: ${photos.length} (page $_photosPage, hasMore: $_hasMorePhotos)',
      );
      debugPrint(
        '👥 Users: ${users.length} (page $_usersPage, hasMore: $_hasMoreUsers)',
      );

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

  // ✅ NOUVEAU: Charger page suivante
  Future<void> _loadMorePhotos() async {
    if (!_hasMorePhotos || _isLoading) return;
    _photosPage++;
    await _loadData();
  }

  Future<void> _loadMoreUsers() async {
    if (!_hasMoreUsers || _isLoading) return;
    _usersPage++;
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(theme),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(ThemeData theme) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.shield,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ADMIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dashboard',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white24),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
            ),
          ),

          const Divider(color: Colors.white24),

          Padding(
            padding: const EdgeInsets.all(16),
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

                if (confirmed == true && context.mounted) {
                  await context.read<AuthProvider>().signOut();
                }
              },
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text(
                'Déconnexion',
                style: TextStyle(color: Colors.white),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withOpacity(0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
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
        padding: const EdgeInsets.all(32),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vue d\'ensemble',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // ✅ FIX: Retirer locale français
                  Text(
                    DateFormat('EEEE d MMMM yyyy').format(DateTime.now()),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              IconButton.filled(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualiser',
              ),
            ],
          ),

          const SizedBox(height: 32),

          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.5, // ✅ FIX: 1.8 → 2.2 (plus d'espace vertical)
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
          ),
          // Dans _buildModeration, après le GridView (ligne ~560)
          if (_hasMorePhotos && _pendingPhotos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: _loadMorePhotos,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Charger plus de photos'),
                ),
              ),
            ),

          // Dans _buildUsers, après le Card (ligne ~640)
          if (_hasMoreUsers && _users.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: _loadMoreUsers,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Charger plus d\'utilisateurs'),
                ),
              ),
            ),
          const SizedBox(height: 32),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
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
                      .map(
                        (user) => _buildActivityItem(theme: theme, user: user),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Remplace uniquement la méthode _buildStatCard (ligne ~390-440)

  Widget _buildStatCard({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? trend,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Container(
        padding: const EdgeInsets.all(8), // ✅ FIX: 12 → 8
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6), // ✅ FIX: 8 → 6
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16), // ✅ FIX: 18 → 16
                ),
                if (trend != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
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
                        fontSize: 9, // ✅ FIX: 10 → 9
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                // ✅ FIX: titleLarge → titleMedium
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
              ), // ✅ FIX: Forcer 11px
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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

  Widget _buildModeration(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modération des photos',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_pendingPhotos.length} photos en attente',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser'),
            ),
          ],
        ),

        const SizedBox(height: 32),

        if (_pendingPhotos.isEmpty)
          Center(
            child: Column(
              children: [
                const SizedBox(height: 100),
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: Colors.green[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucune photo en attente',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: _pendingPhotos.length,
            itemBuilder: (context, index) {
              final photo = _pendingPhotos[index];
              return _buildPhotoCard(theme, photo);
            },
          ),
      ],
    );
  }

  // Remplace aussi _buildPhotoCard pour mieux gérer les erreurs (ligne ~520-580)

  Widget _buildPhotoCard(ThemeData theme, Map<String, dynamic> photo) {
    // ✅ FIX: Vérifier remote_path
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

    // ✅ FIX: Vérifier profiles
    final profiles = photo['profiles'];
    final userName = profiles != null
        ? (profiles['full_name'] ?? profiles['email'] ?? 'Utilisateur inconnu')
        : 'Utilisateur inconnu';

    debugPrint('🖼️ Rendering photo: $remotePath for $userName'); // ✅ DEBUG

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CachedNetworkImage(
              imageUrl: remotePath,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: theme.colorScheme.surfaceVariant,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, url, error) {
                debugPrint('❌ Image load error: $url - $error'); // ✅ DEBUG
                return Container(
                  color: theme.colorScheme.errorContainer,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image, size: 48),
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
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
          ),
          Padding(
            padding: const EdgeInsets.all(8),
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
          const SnackBar(
            content: Text('Photo approuvée'),
            backgroundColor: Colors.green,
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
                    'Pas de visage visible',
                    'Violation des règles',
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
          const SnackBar(
            content: Text('Photo rejetée'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Reject error: $e');
    }
  }

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
          padding: const EdgeInsets.all(32),
          child: Row(
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
                      '${_users.length} utilisateurs',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 300,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Card(
            margin: const EdgeInsets.fromLTRB(32, 0, 32, 32),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: ListView.separated(
              itemCount: filteredUsers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _buildUserItem(theme, filteredUsers[index]),
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
    dynamic action,
    Map<String, dynamic> user,
  ) async {
    if (action == 'delete') {
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

      if (confirmed == true) {
        try {
          await _supabase.from('profiles').delete().eq('id', user['id']);
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
          debugPrint('❌ Delete error: $e');
        }
      }
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

// Panel modérateur simplifié (référence vers fichier séparé)
class ModeratorPanelScreen extends StatelessWidget {
  const ModeratorPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel Modération')),
      body: const Center(child: Text('Panel de modération des photos')),
    );
  }
}
