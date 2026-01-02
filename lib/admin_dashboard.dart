// lib/features/admin/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentUsers = [];
  List<Map<String, dynamic>> _pendingPhotos = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // Stats utilisateurs actifs 30j
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final activeUsers = await _supabase
          .from('profiles')
          .select('id')
          .gte('last_active_at', thirtyDaysAgo.toIso8601String())
          .count();

      // Total utilisateurs
      final totalUsers = await _supabase
          .from('profiles')
          .select('id')
          .count();

      // Taux de complétion moyen
      final completionStats = await _supabase
          .from('profiles')
          .select('completion_percentage');
      
      final avgCompletion = completionStats.isNotEmpty
          ? (completionStats.fold<int>(
              0, 
              (sum, item) => sum + (item['completion_percentage'] as int? ?? 0)
            ) / completionStats.length).round()
          : 0;

      // Photos en attente
      final pendingCount = await _supabase
          .from('photos')
          .select('id')
          .eq('status', 'pending')
          .count();

      // Utilisateurs récents
      final recent = await _supabase
          .from('profiles')
          .select('id, email, full_name, created_at, profile_completed, role')
          .order('created_at', ascending: false)
          .limit(10);

      // Photos en attente (détails)
      final photos = await _supabase
          .from('photos')
          .select('*, profiles(full_name, email)')
          .eq('status', 'pending')
          .order('uploaded_at', ascending: false)
          .limit(20);

      setState(() {
        _stats = {
          'active_users_30d': activeUsers.count,
          'total_users': totalUsers.count,
          'avg_completion': avgCompletion,
          'pending_photos': pendingCount.count,
        };
        _recentUsers = List<Map<String, dynamic>>.from(recent);
        _pendingPhotos = List<Map<String, dynamic>>.from(photos);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Dashboard load error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stats Cards
                    _buildStatsGrid(theme),
                    
                    const SizedBox(height: 32),
                    
                    // Charts
                    _buildChartsSection(theme),
                    
                    const SizedBox(height: 32),
                    
                    // Recent Users
                    _buildRecentUsersSection(theme),
                    
                    const SizedBox(height: 32),
                    
                    // Pending Photos
                    _buildPendingPhotosSection(theme),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsGrid(ThemeData theme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          theme,
          'Utilisateurs actifs (30j)',
          _stats['active_users_30d']?.toString() ?? '0',
          Icons.people,
          Colors.blue,
        ),
        _buildStatCard(
          theme,
          'Total utilisateurs',
          _stats['total_users']?.toString() ?? '0',
          Icons.groups,
          Colors.green,
        ),
        _buildStatCard(
          theme,
          'Complétion moyenne',
          '${_stats['avg_completion']}%',
          Icons.check_circle,
          Colors.orange,
        ),
        _buildStatCard(
          theme,
          'Photos en attente',
          _stats['pending_photos']?.toString() ?? '0',
          Icons.pending,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 32),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Statistiques',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Répartition des profils',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          value: (_stats['total_users'] ?? 0) - 
                                 (_stats['pending_photos'] ?? 0).toDouble(),
                          title: 'Complets',
                          color: Colors.green,
                          radius: 60,
                        ),
                        PieChartSectionData(
                          value: (_stats['pending_photos'] ?? 0).toDouble(),
                          title: 'En attente',
                          color: Colors.orange,
                          radius: 60,
                        ),
                      ],
                      sectionsSpace: 4,
                      centerSpaceRadius: 40,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentUsersSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Utilisateurs récents',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigation vers liste complète
              },
              child: const Text('Voir tout'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentUsers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = _recentUsers[index];
              final createdAt = DateTime.parse(user['created_at']);
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    (user['full_name'] ?? user['email'])[0].toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                title: Text(user['full_name'] ?? user['email']),
                subtitle: Text(
                  'Inscrit le ${DateFormat('dd/MM/yyyy').format(createdAt)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user['profile_completed'])
                      const Icon(Icons.check_circle, color: Colors.green)
                    else
                      const Icon(Icons.pending, color: Colors.orange),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(user['role']),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ],
                ),
                onTap: () => _showUserDetails(user),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPendingPhotosSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Photos en attente',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ModeratorPanelScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.gavel),
              label: const Text('Panel modération'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '${_pendingPhotos.length} photos à modérer',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: controller,
            children: [
              Text(
                'Détails utilisateur',
                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailRow('ID', user['id']),
              _buildDetailRow('Email', user['email']),
              _buildDetailRow('Nom', user['full_name'] ?? 'Non renseigné'),
              _buildDetailRow('Rôle', user['role']),
              _buildDetailRow(
                'Profil complet',
                user['profile_completed'] ? 'Oui' : 'Non',
              ),
              _buildDetailRow(
                'Date d\'inscription',
                DateFormat('dd/MM/yyyy HH:mm')
                    .format(DateTime.parse(user['created_at'])),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Suspendre utilisateur
                      },
                      child: const Text('Suspendre'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        // Supprimer utilisateur
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Supprimer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

// Panel modérateur simplifié (référence vers fichier séparé)
class ModeratorPanelScreen extends StatelessWidget {
  const ModeratorPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Modération'),
      ),
      body: const Center(
        child: Text('Panel de modération des photos'),
      ),
    );
  }
}