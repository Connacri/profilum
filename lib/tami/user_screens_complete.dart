// ==================== ÉCRAN PRINCIPAL USER ====================
// screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'document_provider_fixed.dart';
import 'models_unified.dart';
import 'processing_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

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
        backgroundColor: Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mes Documents', style: TextStyle(fontSize: 20)),
            Text(
              authProvider.currentUser?.userMetadata?['full_name'] ?? '',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: () => docProvider.loadUserDocuments(),
            tooltip: 'Actualiser',
          ),
          PopupMenuButton(
            icon: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Icon(Icons.person_rounded, color: Colors.white),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authProvider.currentUser?.userMetadata?['full_name'] ??
                          '',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      authProvider.currentUser?.email ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                child: ListTile(
                  leading: Icon(Icons.logout_rounded, color: Colors.red),
                  title:
                      Text('Déconnexion', style: TextStyle(color: Colors.red)),
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
        child: docProvider.userDocuments.isEmpty
            ? _buildEmptyState()
            : _buildDocumentsList(docProvider.userDocuments),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/scan');
        },
        backgroundColor: Color(0xFF0D47A1),
        icon: Icon(Icons.add_rounded),
        label: Text('Scanner un document'),
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
            icon: Icon(Icons.add_rounded),
            label: Text('Scanner maintenant'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList(List<ScannedDocument> documents) {
    // Grouper par type
    final chifaDocs =
        documents.where((d) => d.type == DocumentType.chifa).toList();
    final cniDocs = documents.where((d) => d.type == DocumentType.cni).toList();
    final passportDocs =
        documents.where((d) => d.type == DocumentType.passport).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Statistiques rapides
        _buildStatsCard(documents.length, chifaDocs.length, cniDocs.length,
            passportDocs.length),
        const SizedBox(height: 24),

        // Cartes Chifa
        if (chifaDocs.isNotEmpty) ...[
          _buildSectionHeader(
              'Cartes Chifa', Icons.credit_card_rounded, Color(0xFF4CAF50)),
          ...chifaDocs.map((doc) => _buildDocumentCard(doc)),
          const SizedBox(height: 16),
        ],

        // CNI
        if (cniDocs.isNotEmpty) ...[
          _buildSectionHeader(
              'CNI Biométrique', Icons.badge_rounded, Color(0xFF2196F3)),
          ...cniDocs.map((doc) => _buildDocumentCard(doc)),
          const SizedBox(height: 16),
        ],

        // Passeports
        if (passportDocs.isNotEmpty) ...[
          _buildSectionHeader(
              'Passeports', Icons.flight_rounded, Color(0xFFFF9800)),
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
        gradient: LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0D47A1).withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mes documents',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$total total',
                  style: TextStyle(
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
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
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
          Icon(icon, color: color, size: 24),
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
    IconData icon;
    Color color;
    String number;

    switch (doc.type) {
      case DocumentType.chifa:
        icon = Icons.credit_card_rounded;
        color = Color(0xFF4CAF50);
        number = (doc as ChifaCard).chifaNumber;
        break;
      case DocumentType.cni:
        icon = Icons.badge_rounded;
        color = Color(0xFF2196F3);
        number = (doc as CNICard).cniNumber;
        break;
      case DocumentType.passport:
        icon = Icons.flight_rounded;
        color = Color(0xFFFF9800);
        number = (doc as PassportCard).passportNumber;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          doc.fullName,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(number,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Text(
              'Ajouté le ${DateFormat('dd/MM/yyyy').format(doc.createdAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Type', doc.type.label),
                _buildDetailRow('Nom', doc.fullName),
                _buildDetailRow('Téléphone', '+213 ${doc.phoneNumber}'),
                _buildDetailRow('Numéro', number),
                if (doc.birthDate != null)
                  _buildDetailRow('Date de naissance',
                      DateFormat('dd/MM/yyyy').format(doc.birthDate!)),
                if (doc is ChifaCard) ...[
                  _buildDetailRow('Organisme', doc.organism),
                  if (doc.expiryDate != null)
                    _buildDetailRow('Expiration',
                        DateFormat('dd/MM/yyyy').format(doc.expiryDate!)),
                ],
                if (doc is CNICard) ...[
                  _buildDetailRow('Lieu de naissance', doc.birthPlace),
                  if (doc.issueDate != null)
                    _buildDetailRow('Date émission',
                        DateFormat('dd/MM/yyyy').format(doc.issueDate!)),
                ],
                if (doc is PassportCard) ...[
                  _buildDetailRow('Lieu d\'émission', doc.issuePlace),
                  if (doc.issueDate != null)
                    _buildDetailRow('Date émission',
                        DateFormat('dd/MM/yyyy').format(doc.issueDate!)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmDelete(doc),
                        icon: Icon(Icons.delete_rounded, size: 18),
                        label: Text('Supprimer'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _editDocument(doc),
                        icon: Icon(Icons.edit_rounded, size: 18),
                        label: Text('Modifier'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label :',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[800])),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(ScannedDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer ce document ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await context.read<DocumentProvider>().deleteDocument(doc.id!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('✓ Document supprimé'),
              backgroundColor: Colors.green),
        );
      }
    }
  }

  void _editDocument(ScannedDocument doc) {
    // TODO: Implémenter édition
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fonction en développement')),
    );
  }
}

// ==================== ÉCRAN DE SCAN ====================

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

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
        backgroundColor: Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        title: Text('Scanner un document'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
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
              color: Color(0xFF4CAF50),
              description: 'Carte d\'assurance maladie',
            ),
            const SizedBox(height: 16),

            // CNI
            _buildDocTypeCard(
              type: DocumentType.cni,
              icon: Icons.badge_rounded,
              color: Color(0xFF2196F3),
              description: 'Carte nationale d\'identité biométrique',
            ),
            const SizedBox(height: 16),

            // Passeport
            _buildDocTypeCard(
              type: DocumentType.passport,
              icon: Icons.flight_rounded,
              color: Color(0xFFFF9800),
              description: 'Passeport algérien',
            ),

            Spacer(),

            // Boutons
            if (_selectedType != null) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _takePicture(ImageSource.camera),
                  icon: Icon(Icons.camera_alt_rounded, size: 24),
                  label: Text(
                    'Prendre une photo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0D47A1),
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
                  icon: Icon(Icons.photo_library_rounded, size: 24),
                  label: Text(
                    'Choisir depuis la galerie',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF0D47A1),
                    side: BorderSide(color: Color(0xFF0D47A1), width: 2),
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
                    offset: Offset(0, 4),
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
