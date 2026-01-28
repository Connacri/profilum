// ═══════════════════════════════════════════════════════════════════
// 🏠 HOME SCREEN - ÉCRAN PRINCIPAL UTILISATEUR
// ═══════════════════════════════════════════════════════════════════
// Écran d'accueil pour les utilisateurs authentifiés
// Affiche les documents scannés et options de navigation
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../claude/auth_provider_optimized.dart';
import 'app_router.dart';
import 'document_provider_fixed.dart';
import 'guest_mode_provider.dart';
import 'models_unified.dart';



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserDocuments();
  }

  Future<void> _loadUserDocuments() async {
    final authProvider = context.read<AuthProvider>();
    final documentProvider = context.read<DocumentProvider>();
    
    if (authProvider.isAuthenticated) {
      await documentProvider.loadUserDocuments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton: _buildFAB(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 📄 BODY
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDocumentsTab();
      case 1:
        return _buildProfileTab();
      default:
        return _buildDocumentsTab();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 📋 DOCUMENTS TAB
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildDocumentsTab() {
    final authProvider = context.watch<AuthProvider>();
    final documentProvider = context.watch<DocumentProvider>();
    final guestProvider = context.watch<GuestModeProvider>();

    // Déterminer quelle source de documents utiliser
    final isGuest = !authProvider.isAuthenticated;
    final documents = isGuest 
        ? guestProvider.guestDocuments 
        : documentProvider.userDocuments;

    return CustomScrollView(
      slivers: [
        // AppBar
        SliverAppBar(
          expandedHeight: 200,
          floating: false,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text('Mes Documents'),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.folder_open_rounded,
                  size: 80,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ),

        // Statistiques
        SliverToBoxAdapter(
          child: _buildStatsCards(
            isGuest ? guestProvider : documentProvider,
            isGuest,
          ),
        ),

        // Liste des documents
        if (documents.isEmpty)
          SliverFillRemaining(
            child: _buildEmptyState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final document = documents[index];
                  return _buildDocumentCard(document, isGuest);
                },
                childCount: documents.length,
              ),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 📊 STATISTICS CARDS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildStatsCards(dynamic provider, bool isGuest) {
    final chifaCount = isGuest 
        ? (provider as GuestModeProvider).chifaCount
        : (provider as DocumentProvider).userDocuments
            .where((d) => d.type == DocumentType.chifa).length;
    
    final cniCount = isGuest
        ? (provider as GuestModeProvider).cniCount
        : (provider as DocumentProvider).userDocuments
            .where((d) => d.type == DocumentType.cni).length;
    
    final passportCount = isGuest
        ? (provider as GuestModeProvider).passportCount
        : (provider as DocumentProvider).userDocuments
            .where((d) => d.type == DocumentType.passport).length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isGuest)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mode Invité',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Créez un compte pour synchroniser vos documents',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.userAuth);
                    },
                    child: const Text('Créer'),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          const Text(
            'Statistiques',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Chifa',
                  chifaCount,
                  Icons.health_and_safety_rounded,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'CNI',
                  cniCount,
                  Icons.credit_card_rounded,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Passeport',
                  passportCount,
                  Icons.flight_takeoff_rounded,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 📄 DOCUMENT CARD
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildDocumentCard(ScannedDocument document, bool isGuest) {
    IconData icon;
    Color color;
    String number = '';

    switch (document.type) {
      case DocumentType.chifa:
        icon = Icons.health_and_safety_rounded;
        color = Colors.blue;
        number = (document as ChifaCard).chifaNumber;
        break;
      case DocumentType.cni:
        icon = Icons.credit_card_rounded;
        color = Colors.green;
        number = (document as CNICard).cniNumber;
        break;
      case DocumentType.passport:
        icon = Icons.flight_takeoff_rounded;
        color = Colors.purple;
        number = (document as PassportCard).passportNumber;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Navigation vers détail
          if (document.id != null) {
            NavigationHelpers.navigateToDocumentDetail(
              context,
              documentId: document.id!,
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.type.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          document.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (document.isManuallyVerified)
                    const Icon(
                      Icons.verified_rounded,
                      color: Colors.green,
                      size: 20,
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Icon(
                    Icons.badge_rounded,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    number,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const Spacer(),
                  if (document.birthDate != null) ...[
                    Icon(
                      Icons.cake_rounded,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(document.birthDate!),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 8),
              
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Ajouté le ${_formatDate(document.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const Spacer(),
                  _buildConfidenceBadge(document.confidenceScore),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge(double confidence) {
    Color color;
    String label;

    if (confidence >= 0.8) {
      color = Colors.green;
      label = 'Élevé';
    } else if (confidence >= 0.6) {
      color = Colors.orange;
      label = 'Moyen';
    } else {
      color = Colors.red;
      label = 'Faible';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🚫 EMPTY STATE
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 100,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun document',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Scannez votre premier document\npour commencer',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _showDocumentTypeDialog(),
              icon: const Icon(Icons.document_scanner_rounded),
              label: const Text('Scanner un document'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 👤 PROFILE TAB
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildProfileTab() {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          floating: false,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text('Profil'),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.secondary,
                    Theme.of(context).colorScheme.primary,
                  ],
                ),
              ),
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (user != null) ...[
                _buildProfileCard(user),
                const SizedBox(height: 16),
              ],
              
              _buildSettingsTile(
                'Paramètres',
                Icons.settings_rounded,
                () {
                  // TODO: Navigation vers paramètres
                },
              ),
              
              _buildSettingsTile(
                'Aide et Support',
                Icons.help_outline_rounded,
                () {
                  // TODO: Navigation vers aide
                },
              ),
              
              const SizedBox(height: 16),
              
              OutlinedButton.icon(
                onPressed: () async {
                  await authProvider.signOut();
                  if (context.mounted) {
                    NavigationHelpers.navigateToWelcome(context);
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Se déconnecter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(dynamic user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                user.fullName?.substring(0, 1).toUpperCase() ?? '?',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.fullName ?? 'Utilisateur',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user.email ?? '',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🧭 BOTTOM NAVIGATION BAR
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildBottomNavBar() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() => _selectedIndex = index);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder_rounded),
          label: 'Documents',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profil',
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ➕ FLOATING ACTION BUTTON
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => _showDocumentTypeDialog(),
      icon: const Icon(Icons.document_scanner_rounded),
      label: const Text('Scanner'),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 📋 DOCUMENT TYPE DIALOG
  // ═══════════════════════════════════════════════════════════════════

  void _showDocumentTypeDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Type de document',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildDocumentTypeButton(
              'Carte Chifa',
              Icons.health_and_safety_rounded,
              Colors.blue,
              DocumentType.chifa,
            ),
            const SizedBox(height: 12),
            _buildDocumentTypeButton(
              'CNI Biométrique',
              Icons.credit_card_rounded,
              Colors.green,
              DocumentType.cni,
            ),
            const SizedBox(height: 12),
            _buildDocumentTypeButton(
              'Passeport',
              Icons.flight_takeoff_rounded,
              Colors.purple,
              DocumentType.passport,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentTypeButton(
    String label,
    IconData icon,
    Color color,
    DocumentType type,
  ) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          Navigator.pop(context);
          NavigationHelpers.navigateToScan(context, documentType: type);
        },
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔧 UTILITIES
  // ═══════════════════════════════════════════════════════════════════

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
