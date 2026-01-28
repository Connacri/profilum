// ==================== ÉCRAN DE TRAITEMENT OCR ====================
// screens/processing_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'document_provider_fixed.dart';
import 'models_unified.dart';

class ProcessingScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final DocumentType documentType;

  const ProcessingScreen({
    Key? key,
    required this.imageBytes,
    required this.documentType,
  }) : super(key: key);

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  @override
  void initState() {
    super.initState();
    _processDocument();
  }

  Future<void> _processDocument() async {
    final provider = context.read<DocumentProvider>();

    await provider.scanDocument(
      imageBytes: widget.imageBytes,
      documentType: widget.documentType,
    );

    if (!mounted) return;

    if (provider.state == ScanState.success &&
        provider.currentDocument != null) {
      // Naviguer vers formulaire
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentFormScreen(
            document: provider.currentDocument!,
            imageBytes: widget.imageBytes,
          ),
        ),
      );
    } else {
      // Erreur
      _showErrorDialog(provider.errorMessage ?? 'Erreur inconnue');
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red),
            const SizedBox(width: 12),
            Text('Échec du scan'),
          ],
        ),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Fermer dialog
              Navigator.pop(context); // Retour au scan
            },
            child: Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation(Color(0xFF0D47A1)),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Extraction des données...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Veuillez patienter',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== FORMULAIRE D'ÉDITION ====================

class DocumentFormScreen extends StatefulWidget {
  final ScannedDocument document;
  final Uint8List imageBytes;

  const DocumentFormScreen({
    Key? key,
    required this.document,
    required this.imageBytes,
  }) : super(key: key);

  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late ScannedDocument _editedDocument;
  bool _isSaving = false;
  bool _documentExists = false;

  @override
  void initState() {
    super.initState();
    _editedDocument = widget.document;
    _checkIfExists();
  }

  Future<void> _checkIfExists() async {
    // Vérifier si c'est un document existant (id != null)
    if (_editedDocument.id != null) {
      setState(() => _documentExists = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        title: Text(_documentExists
            ? 'Modifier le document'
            : 'Vérifier les informations'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barre d'info
          _buildInfoBar(),

          // Formulaire
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Aperçu image
                    _buildImagePreview(),
                    const SizedBox(height: 24),

                    // Instructions
                    if (!_documentExists) _buildInstructions(),
                    if (!_documentExists) const SizedBox(height: 24),

                    // Champs selon type
                    if (_editedDocument is ChifaCard)
                      _buildChifaForm()
                    else if (_editedDocument is CNICard)
                      _buildCNIForm()
                    else if (_editedDocument is PassportCard)
                      _buildPassportForm(),
                  ],
                ),
              ),
            ),
          ),

          // Boutons action
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildInfoBar() {
    if (_documentExists) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border(
            bottom: BorderSide(color: Colors.orange.shade200),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ce document existe déjà. Les modifications seront enregistrées.',
                style: TextStyle(color: Colors.orange.shade900),
              ),
            ),
          ],
        ),
      );
    }

    final confidence = _editedDocument.confidenceScore;
    final percentage = (confidence * 100).toInt();

    Color barColor;
    String label;
    if (confidence >= 0.85) {
      barColor = Colors.green;
      label = 'Excellente détection ($percentage%)';
    } else if (confidence >= 0.70) {
      barColor = Colors.orange;
      label = 'Vérification recommandée ($percentage%)';
    } else {
      barColor = Colors.red;
      label = 'Correction nécessaire ($percentage%)';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: barColor.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: barColor.withOpacity(0.3))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: barColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600, color: barColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(widget.imageBytes, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Les champs en orange nécessitent votre attention. Vérifiez et corrigez si nécessaire.',
              style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== FORMULAIRE CHIFA ====================

  Widget _buildChifaForm() {
    final chifa = _editedDocument as ChifaCard;
    final lowConf = chifa.confidenceScore < 0.8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Carte Chifa', Icons.credit_card_rounded),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Numéro Chifa *',
          initialValue: chifa.chifaNumber,
          keyboardType: TextInputType.number,
          lowConfidence: lowConf,
          maxLength: 13,
          validator: (v) {
            if (v?.isEmpty ?? true) return 'Obligatoire';
            if (v!.length < 12) return 'Minimum 12 chiffres';
            return null;
          },
          onChanged: (v) {
            _editedDocument = chifa.copyWith(chifaNumber: v);
          },
        ),
        _buildTextField(
          label: 'Nom complet *',
          initialValue: chifa.fullName,
          lowConfidence: chifa.confidenceScore < 0.75,
          textCapitalization: TextCapitalization.words,
          validator: (v) => v?.isEmpty ?? true ? 'Obligatoire' : null,
          onChanged: (v) {
            _editedDocument = chifa.copyWith(fullName: v);
          },
        ),
        _buildTextField(
          label: 'Téléphone *',
          initialValue: chifa.phoneNumber,
          keyboardType: TextInputType.phone,
          prefixText: '+213 ',
          maxLength: 9,
          validator: (v) {
            if (v?.isEmpty ?? true) return 'Obligatoire';
            if (v!.length != 9) return '9 chiffres requis';
            return null;
          },
          onChanged: (v) {
            _editedDocument = chifa.copyWith(phoneNumber: v);
          },
        ),
        _buildDateField(
          label: 'Date de naissance',
          initialDate: chifa.birthDate,
          onChanged: (d) {
            _editedDocument = chifa.copyWith(birthDate: d);
          },
        ),
        _buildDropdownField(
          label: 'Organisme',
          value: chifa.organism,
          items: ['CNAS', 'CASNOS', 'AUTRE'],
          onChanged: (v) {
            _editedDocument = chifa.copyWith(organism: v);
          },
        ),
        _buildDateField(
          label: 'Date d\'expiration',
          initialDate: chifa.expiryDate,
          onChanged: (d) {
            _editedDocument = chifa.copyWith(expiryDate: d);
          },
        ),
        _buildDropdownField(
          label: 'Rang',
          value: chifa.rank.name,
          items: ChifaRank.values.map((r) => r.name).toList(),
          displayItems: ChifaRank.values.map((r) => r.label).toList(),
          onChanged: (v) {
            final rank = ChifaRank.values.firstWhere((r) => r.name == v);
            _editedDocument = chifa.copyWith(rank: rank);
          },
        ),
      ],
    );
  }

  // ==================== FORMULAIRE CNI ====================

  Widget _buildCNIForm() {
    final cni = _editedDocument as CNICard;
    final lowConf = cni.confidenceScore < 0.8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('CNI Biométrique', Icons.badge_rounded),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Numéro CNI *',
          initialValue: cni.cniNumber,
          keyboardType: TextInputType.number,
          lowConfidence: lowConf,
          maxLength: 18,
          validator: (v) {
            if (v?.isEmpty ?? true) return 'Obligatoire';
            if (v!.length != 18) return '18 chiffres requis';
            return null;
          },
          onChanged: (v) {
            _editedDocument = cni.copyWith(cniNumber: v);
          },
        ),
        _buildTextField(
          label: 'Nom complet *',
          initialValue: cni.fullName,
          lowConfidence: cni.confidenceScore < 0.75,
          textCapitalization: TextCapitalization.words,
          validator: (v) => v?.isEmpty ?? true ? 'Obligatoire' : null,
          onChanged: (v) {
            _editedDocument = cni.copyWith(fullName: v);
          },
        ),
        _buildTextField(
          label: 'Téléphone *',
          initialValue: cni.phoneNumber,
          keyboardType: TextInputType.phone,
          prefixText: '+213 ',
          maxLength: 9,
          validator: (v) {
            if (v?.isEmpty ?? true) return 'Obligatoire';
            if (v!.length != 9) return '9 chiffres requis';
            return null;
          },
          onChanged: (v) {
            _editedDocument = cni.copyWith(phoneNumber: v);
          },
        ),
        _buildDateField(
          label: 'Date de naissance',
          initialDate: cni.birthDate,
          onChanged: (d) {
            _editedDocument = cni.copyWith(birthDate: d);
          },
        ),
        _buildTextField(
          label: 'Lieu de naissance',
          initialValue: cni.birthPlace,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) {
            _editedDocument = cni.copyWith(birthPlace: v);
          },
        ),
        Row(
          children: [
            Expanded(
              child: _buildDateField(
                label: 'Date d\'émission',
                initialDate: cni.issueDate,
                onChanged: (d) {
                  _editedDocument = cni.copyWith(issueDate: d);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDateField(
                label: 'Date d\'expiration',
                initialDate: cni.expiryDate,
                onChanged: (d) {
                  _editedDocument = cni.copyWith(expiryDate: d);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== FORMULAIRE PASSEPORT ====================

  Widget _buildPassportForm() {
    final passport = _editedDocument as PassportCard;
    final lowConf = passport.confidenceScore < 0.8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Passeport', Icons.flight_rounded),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Numéro passeport *',
          initialValue: passport.passportNumber,
          lowConfidence: lowConf,
          textCapitalization: TextCapitalization.characters,
          validator: (v) => v?.isEmpty ?? true ? 'Obligatoire' : null,
          onChanged: (v) {
            _editedDocument = passport.copyWith(passportNumber: v);
          },
        ),
        _buildTextField(
          label: 'Nom complet *',
          initialValue: passport.fullName,
          lowConfidence: passport.confidenceScore < 0.75,
          textCapitalization: TextCapitalization.words,
          validator: (v) => v?.isEmpty ?? true ? 'Obligatoire' : null,
          onChanged: (v) {
            _editedDocument = passport.copyWith(fullName: v);
          },
        ),
        _buildTextField(
          label: 'Téléphone *',
          initialValue: passport.phoneNumber,
          keyboardType: TextInputType.phone,
          prefixText: '+213 ',
          maxLength: 9,
          validator: (v) {
            if (v?.isEmpty ?? true) return 'Obligatoire';
            if (v!.length != 9) return '9 chiffres requis';
            return null;
          },
          onChanged: (v) {
            _editedDocument = passport.copyWith(phoneNumber: v);
          },
        ),
        _buildDateField(
          label: 'Date de naissance',
          initialDate: passport.birthDate,
          onChanged: (d) {
            _editedDocument = passport.copyWith(birthDate: d);
          },
        ),
        _buildTextField(
          label: 'Lieu d\'émission',
          initialValue: passport.issuePlace,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) {
            _editedDocument = passport.copyWith(issuePlace: v);
          },
        ),
        Row(
          children: [
            Expanded(
              child: _buildDateField(
                label: 'Date d\'émission',
                initialDate: passport.issueDate,
                onChanged: (d) {
                  _editedDocument = passport.copyWith(issueDate: d);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDateField(
                label: 'Date d\'expiration',
                initialDate: passport.expiryDate,
                onChanged: (d) {
                  _editedDocument = passport.copyWith(expiryDate: d);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== WIDGETS HELPERS ====================

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Color(0xFF0D47A1), size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D47A1),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    String? initialValue,
    bool lowConfidence = false,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
    String? prefixText,
    String? Function(String?)? validator,
    required Function(String) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: initialValue,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        maxLength: maxLength,
        validator: validator,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefixText,
          fillColor: lowConfidence ? Colors.orange.shade50 : Colors.white,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: lowConfidence ? Colors.orange : Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: lowConfidence ? Colors.orange : Color(0xFF0D47A1),
              width: 2,
            ),
          ),
          suffixIcon: lowConfidence
              ? Icon(Icons.warning_amber_rounded, color: Colors.orange)
              : null,
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    DateTime? initialDate,
    required Function(DateTime?) onChanged,
  }) {
    final controller = TextEditingController(
      text: initialDate != null
          ? DateFormat('dd/MM/yyyy').format(initialDate)
          : '',
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: initialDate ?? DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime(2100),
            locale: Locale('fr'),
          );

          if (date != null) {
            controller.text = DateFormat('dd/MM/yyyy').format(date);
            onChanged(date);
          }
        },
        decoration: InputDecoration(
          labelText: label,
          fillColor: Colors.white,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon:
              Icon(Icons.calendar_today_rounded, color: Color(0xFF0D47A1)),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    List<String>? displayItems,
    required Function(String?) onChanged,
  }) {
    final display = displayItems ?? items;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        items: List.generate(items.length, (i) {
          return DropdownMenuItem(value: items[i], child: Text(display[i]));
        }),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          fillColor: Colors.white,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded),
              label: Text('Annuler'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveDocument,
              icon: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Icon(Icons.check_rounded),
              label: Text(_isSaving
                  ? 'Enregistrement...'
                  : (_documentExists ? 'Mettre à jour' : 'Enregistrer')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final provider = context.read<DocumentProvider>();
    provider.currentDocument = _editedDocument;

    final success = await provider.saveCurrentDocument();

    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_documentExists
              ? '✓ Document mis à jour'
              : '✓ Document enregistré'),
          backgroundColor: Colors.green,
        ),
      );

      // Retour à l'écran principal
      Navigator.popUntil(context, (route) => route.isFirst);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors de l\'enregistrement'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
