// ==================== ÉCRANS USER OPTIMISÉS - CORRIGÉ ====================
// screens/user/home_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:profilum/tami/processing_form_screen.dart';
import 'package:provider/provider.dart';

import '../claude/auth_provider_optimized.dart';
import 'document_provider_fixed.dart';
import 'models_unified.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentProvider>().loadUserDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final docProvider = context.watch<DocumentProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mes Documents', style: TextStyle(fontSize: 20)),
            Text(
              // ✅ CORRECTION : Utilisation de fullName au lieu de userMetadata
              authProvider.currentUser?.fullName ?? '',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => docProvider.loadUserDocuments(),
            tooltip: 'Actualiser',
          ),
          PopupMenuButton(
            icon: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.2),
              child: const Icon(Icons.person_rounded, color: Colors.white),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // ✅ CORRECTION : Utilisation de fullName au lieu de userMetadata
                      authProvider.currentUser?.fullName ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      authProvider.currentUser?.email ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.logout_rounded, color: Colors.red),
                  title: Text('Déconnexion', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
                onTap: () async {
                  await authProvider.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/auth');
                  }
                },
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => docProvider.loadUserDocuments(),
        // ✅ CORRECTION : Utilisation de state au lieu de isLoading
        child: docProvider.state == ScanState.processing
            ? const Center(child: CircularProgressIndicator())
            : docProvider.userDocuments.isEmpty
            ? _buildEmptyState()
            : _buildDocumentsList(docProvider.userDocuments),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/scan');
        },
        backgroundColor: const Color(0xFF0D47A1),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Scanner un document'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.document_scanner_rounded,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun document',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scannez votre premier document',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/scan');
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Scanner maintenant'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList(List<ScannedDocument> documents) {
    // Grouper par type
    final chifaDocs = documents.where((d) => d.type == DocumentType.chifa).toList();
    final cniDocs = documents.where((d) => d.type == DocumentType.cni).toList();
    final passportDocs = documents.where((d) => d.type == DocumentType.passport).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Statistiques rapides
        _buildStatsCard(
          documents.length,
          chifaDocs.length,
          cniDocs.length,
          passportDocs.length,
        ),
        const SizedBox(height: 24),

        // Cartes Chifa
        if (chifaDocs.isNotEmpty) ...[
          _buildSectionHeader('Cartes Chifa', Icons.credit_card_rounded, const Color(0xFF4CAF50)),
          ...chifaDocs.map((doc) => _buildDocumentCard(doc)),
          const SizedBox(height: 16),
        ],

        // CNI
        if (cniDocs.isNotEmpty) ...[
          _buildSectionHeader('CNI Biométrique', Icons.badge_rounded, const Color(0xFF2196F3)),
          ...cniDocs.map((doc) => _buildDocumentCard(doc)),
          const SizedBox(height: 16),
        ],

        // Passeports
        if (passportDocs.isNotEmpty) ...[
          _buildSectionHeader('Passeports', Icons.flight_rounded, const Color(0xFFFF9800)),
          ...passportDocs.map((doc) => _buildDocumentCard(doc)),
        ],

        const SizedBox(height: 80), // Espace pour FAB
      ],
    );
  }

  Widget _buildStatsCard(int total, int chifa, int cni, int passport) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mes documents',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$total total',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Chifa', chifa, Icons.credit_card_rounded),
              _buildStatItem('CNI', cni, Icons.badge_rounded),
              _buildStatItem('Passeport', passport, Icons.flight_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 28),
        const SizedBox(height: 8),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(ScannedDocument doc) {
    Color cardColor;
    IconData cardIcon;
    String subtitle;

    switch (doc.type) {
      case DocumentType.chifa:
        cardColor = const Color(0xFF4CAF50);
        cardIcon = Icons.credit_card_rounded;
        subtitle = (doc as ChifaCard).chifaNumber;
        break;
      case DocumentType.cni:
        cardColor = const Color(0xFF2196F3);
        cardIcon = Icons.badge_rounded;
        subtitle = (doc as CNICard).cniNumber;
        break;
      case DocumentType.passport:
        cardColor = const Color(0xFFFF9800);
        cardIcon = Icons.flight_rounded;
        subtitle = (doc as PassportCard).passportNumber;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showDocumentDetails(doc),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(cardIcon, color: cardColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (doc.confidenceScore < 0.7) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Vérification recommandée',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton(
                icon: Icon(Icons.more_vert_rounded, color: Colors.grey[600]),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const ListTile(
                      leading: Icon(Icons.visibility_rounded),
                      title: Text('Voir détails'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showDocumentDetails(doc);
                    },
                  ),
                  PopupMenuItem(
                    child: const ListTile(
                      leading: Icon(Icons.edit_rounded),
                      title: Text('Modifier'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _editDocument(doc);
                    },
                  ),
                  PopupMenuItem(
                    child: const ListTile(
                      leading: Icon(Icons.delete_rounded, color: Colors.red),
                      title: Text('Supprimer', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _confirmDelete(doc);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDocumentDetails(ScannedDocument doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getDocColor(doc.type).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getDocIcon(doc.type),
                        color: _getDocColor(doc.type),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.type.label,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            doc.fullName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Divider(height: 32),

                // Détails selon le type
                if (doc is ChifaCard) _buildChifaDetails(doc),
                if (doc is CNICard) _buildCNIDetails(doc),
                if (doc is PassportCard) _buildPassportDetails(doc),

                const SizedBox(height: 24),

                // Score de confiance
                _buildConfidenceScore(doc.confidenceScore),

                const SizedBox(height: 24),

                // Métadonnées
                _buildMetadata(doc),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChifaDetails(ChifaCard doc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Numéro Chifa', doc.chifaNumber),
        _buildDetailRow('Organisme', doc.organism),
        _buildDetailRow('Rang', doc.rank.label),
        if (doc.birthDate != null)
          _buildDetailRow('Date de naissance', _formatDate(doc.birthDate!)),
        if (doc.expiryDate != null)
          _buildDetailRow('Date d\'expiration', _formatDate(doc.expiryDate!)),
        if (doc.phoneNumber.isNotEmpty)
          _buildDetailRow('Téléphone', doc.phoneNumber),
      ],
    );
  }

  Widget _buildCNIDetails(CNICard doc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Numéro CNI', doc.cniNumber),
        if (doc.birthPlace.isNotEmpty)
          _buildDetailRow('Lieu de naissance', doc.birthPlace),
        if (doc.birthDate != null)
          _buildDetailRow('Date de naissance', _formatDate(doc.birthDate!)),
        if (doc.issueDate != null)
          _buildDetailRow('Date d\'émission', _formatDate(doc.issueDate!)),
        if (doc.expiryDate != null)
          _buildDetailRow('Date d\'expiration', _formatDate(doc.expiryDate!)),
        if (doc.phoneNumber.isNotEmpty)
          _buildDetailRow('Téléphone', doc.phoneNumber),
      ],
    );
  }

  Widget _buildPassportDetails(PassportCard doc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Numéro Passeport', doc.passportNumber),
        _buildDetailRow('Lieu d\'émission', doc.issuePlace),
        if (doc.birthDate != null)
          _buildDetailRow('Date de naissance', _formatDate(doc.birthDate!)),
        if (doc.issueDate != null)
          _buildDetailRow('Date d\'émission', _formatDate(doc.issueDate!)),
        if (doc.expiryDate != null)
          _buildDetailRow('Date d\'expiration', _formatDate(doc.expiryDate!)),
        if (doc.phoneNumber.isNotEmpty)
          _buildDetailRow('Téléphone', doc.phoneNumber),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceScore(double score) {
    final percentage = (score * 100).toInt();
    Color color;
    String label;

    if (score >= 0.8) {
      color = Colors.green;
      label = 'Excellente';
    } else if (score >= 0.6) {
      color = Colors.orange;
      label = 'Moyenne';
    } else {
      color = Colors.red;
      label = 'Faible';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confiance OCR : $label',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: score,
                  backgroundColor: color.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata(ScannedDocument doc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations système',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Créé le',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              Text(
                _formatDateTime(doc.createdAt),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Modifié le',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              Text(
                _formatDateTime(doc.updatedAt),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (doc.isManuallyVerified) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Vérifié manuellement',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(date);
  }

  Color _getDocColor(DocumentType type) {
    switch (type) {
      case DocumentType.chifa:
        return const Color(0xFF4CAF50);
      case DocumentType.cni:
        return const Color(0xFF2196F3);
      case DocumentType.passport:
        return const Color(0xFFFF9800);
    }
  }

  IconData _getDocIcon(DocumentType type) {
    switch (type) {
      case DocumentType.chifa:
        return Icons.credit_card_rounded;
      case DocumentType.cni:
        return Icons.badge_rounded;
      case DocumentType.passport:
        return Icons.flight_rounded;
    }
  }

  void _confirmDelete(ScannedDocument doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer le document de ${doc.fullName} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteDocument(doc);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDocument(ScannedDocument doc) async {
    if (doc.id == null) return;

    // Afficher loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final docProvider = context.read<DocumentProvider>();
    final success = await docProvider.deleteDocument(doc.id!);

    if (mounted) {
      Navigator.pop(context); // Fermer loading

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Document supprimé'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erreur lors de la suppression'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editDocument(ScannedDocument doc) {
    // TODO: Implémenter édition
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonction en développement')),
    );
  }
}

// ==================== ÉCRAN DE SCAN ====================

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  DocumentType? _selectedType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        title: const Text('Scanner un document'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choisissez le type de document',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Carte Chifa
            _buildDocTypeCard(
              type: DocumentType.chifa,
              icon: Icons.credit_card_rounded,
              color: const Color(0xFF4CAF50),
              description: 'Carte d\'assurance maladie',
            ),
            const SizedBox(height: 16),

            // CNI
            _buildDocTypeCard(
              type: DocumentType.cni,
              icon: Icons.badge_rounded,
              color: const Color(0xFF2196F3),
              description: 'Carte nationale d\'identité biométrique',
            ),
            const SizedBox(height: 16),

            // Passeport
            _buildDocTypeCard(
              type: DocumentType.passport,
              icon: Icons.flight_rounded,
              color: const Color(0xFFFF9800),
              description: 'Passeport algérien',
            ),

            const Spacer(),

            // Boutons
            if (_selectedType != null) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _takePicture(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 24),
                  label: const Text(
                    'Prendre une photo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () => _takePicture(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 24),
                  label: const Text(
                    'Choisir depuis la galerie',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D47A1),
                    side: const BorderSide(color: Color(0xFF0D47A1), width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocTypeCard({
    required DocumentType type,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedType = type);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
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
                    type.label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.grey[800],
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
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 28),
          ],
        ),
      ),
    );
  }

  Future<void> _takePicture(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      // Naviguer vers écran de traitement
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProcessingScreen(
            imageBytes: bytes,
            documentType: _selectedType!,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}