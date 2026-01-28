// ==================== ÉCRAN D'ACCUEIL COMPLET ====================
// lib/screens/welcome_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../claude/auth_provider_optimized.dart';

import 'document_provider_fixed.dart';
import 'models_unified.dart';
import 'project_access_button.dart';

/// Écran d'accueil moderne avec différents points d'accès au projet
class WelcomeHomeScreen extends StatefulWidget {
  const WelcomeHomeScreen({super.key});

  @override
  State<WelcomeHomeScreen> createState() => _WelcomeHomeScreenState();
}

class _WelcomeHomeScreenState extends State<WelcomeHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Profilum'),
        actions: [
          if (!authProvider.isAuthenticated)
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/auth'),
              icon: const Icon(Icons.login_rounded, color: Colors.white),
              label: const Text(
                'Connexion',
                style: TextStyle(color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.2),
                child: const Icon(Icons.person_rounded, color: Colors.white),
              ),
              onPressed: () {
                // Naviguer vers profil
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Accueil', icon: Icon(Icons.home_rounded)),
            Tab(text: 'Fonctionnalités', icon: Icon(Icons.apps_rounded)),
            Tab(text: 'Explorer', icon: Icon(Icons.explore_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHomeTab(),
          _buildFeaturesTab(),
          _buildExploreTab(),
        ],
      ),
      floatingActionButton: authProvider.isAuthenticated
          ? const ProjectAccessFAB()
          : null,
    );
  }

  // ========== TAB 1 : ACCUEIL ==========
  Widget _buildHomeTab() {
    final authProvider = context.watch<AuthProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de bienvenue
          _buildWelcomeHeader(authProvider),
          const SizedBox(height: 32),

          // Card d'accès principal
          const ProjectAccessCard(
            title: 'Mes Documents',
            subtitle: 'Scanner, gérer et organiser vos documents',
            icon: Icons.folder_special_rounded,
          ),
          const SizedBox(height: 24),

          // Statistiques rapides
          if (authProvider.isAuthenticated) _buildQuickStats(),
          const SizedBox(height: 24),

          // Actions rapides
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.waving_hand_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authProvider.isAuthenticated
                          ? 'Bonjour ${authProvider.currentUser?.fullName?.split(' ').first ?? ""}!'
                          : 'Bienvenue !',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      authProvider.isAuthenticated
                          ? 'Gérez vos documents facilement'
                          : 'Connectez-vous pour commencer',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bouton d'action principal
          SizedBox(
            width: double.infinity,
            child: authProvider.isAuthenticated
                ? const ProjectAccessButton(
              label: 'Accéder à mes documents',
              icon: Icons.arrow_forward_rounded,
              fullWidth: true,
              color: Colors.white,
            )
                : ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/auth'),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Se connecter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0D47A1),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final docProvider = context.watch<DocumentProvider>();
    final total = docProvider.userDocuments.length;
    final chifa = docProvider.userDocuments
        .where((d) => d.type == DocumentType.chifa)
        .length;
    final cni = docProvider.userDocuments
        .where((d) => d.type == DocumentType.cni)
        .length;
    final passport = docProvider.userDocuments
        .where((d) => d.type == DocumentType.passport)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistiques',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard('Total', total, Icons.folder_rounded, Colors.blue)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Chifa', chifa, Icons.credit_card_rounded, Colors.green)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard('CNI', cni, Icons.badge_rounded, Colors.orange)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Passeport', passport, Icons.flight_rounded, Colors.purple)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions rapides',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Scanner',
                Icons.document_scanner_rounded,
                Colors.blue,
                    () => Navigator.pushNamed(context, '/scan'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Galerie',
                Icons.photo_library_rounded,
                Colors.purple,
                    () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Aide',
                Icons.help_rounded,
                Colors.orange,
                    () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Paramètres',
                Icons.settings_rounded,
                Colors.grey,
                    () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
      String label,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== TAB 2 : FONCTIONNALITÉS ==========
  Widget _buildFeaturesTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Fonctionnalités',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),

        _buildFeatureCard(
          'Scanner vos documents',
          'Utilisez la caméra pour scanner et numériser vos documents en quelques secondes',
          Icons.document_scanner_rounded,
          Colors.blue,
        ),
        const SizedBox(height: 16),

        _buildFeatureCard(
          'OCR Intelligent',
          'Extraction automatique des données avec intelligence artificielle',
          Icons.auto_awesome_rounded,
          Colors.purple,
        ),
        const SizedBox(height: 16),

        _buildFeatureCard(
          'Stockage Sécurisé',
          'Vos documents sont stockés de manière sécurisée dans le cloud',
          Icons.cloud_done_rounded,
          Colors.green,
        ),
        const SizedBox(height: 16),

        _buildFeatureCard(
          'Gestion Simple',
          'Organisez, modifiez et gérez vos documents facilement',
          Icons.folder_special_rounded,
          Colors.orange,
        ),
        const SizedBox(height: 32),

        // Bouton d'accès
        const ProjectAccessButton(
          label: 'Essayer maintenant',
          icon: Icons.rocket_launch_rounded,
          fullWidth: true,
          size: ButtonSize.large,
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
      String title,
      String description,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== TAB 3 : EXPLORER ==========
  Widget _buildExploreTab() {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildExploreCard(
          'Tous les Documents',
          Icons.folder_rounded,
          Colors.blue,
        ),
        _buildExploreCard(
          'Cartes Chifa',
          Icons.credit_card_rounded,
          Colors.green,
        ),
        _buildExploreCard(
          'CNI',
          Icons.badge_rounded,
          Colors.orange,
        ),
        _buildExploreCard(
          'Passeports',
          Icons.flight_rounded,
          Colors.purple,
        ),
        _buildExploreCard(
          'Favoris',
          Icons.star_rounded,
          Colors.amber,
        ),
        _buildExploreCard(
          'Récents',
          Icons.history_rounded,
          Colors.grey,
        ),
      ],
    );
  }

  Widget _buildExploreCard(String title, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        // Navigation vers la catégorie
        final authProvider = context.read<AuthProvider>();
        if (authProvider.isAuthenticated) {
          Navigator.pushNamed(context, '/home');
        } else {
          _showLoginDialog();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_rounded, size: 48, color: Colors.orange),
        title: const Text('Connexion requise'),
        content: const Text(
          'Vous devez être connecté pour accéder à cette fonctionnalité.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/auth');
            },
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }
}