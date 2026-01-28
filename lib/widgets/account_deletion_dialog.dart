// lib/widgets/account_deletion_dialog.dart - NOUVEAU FICHIER

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../claude/auth_provider_optimized.dart';
import '../providers/auth_provider.dart';

class AccountDeletionDialog extends StatefulWidget {
  const AccountDeletionDialog({super.key});

  @override
  State<AccountDeletionDialog> createState() => _AccountDeletionDialogState();
}

class _AccountDeletionDialogState extends State<AccountDeletionDialog> {
  int _step = 0;
  String? _selectedReason;
  final _confirmController = TextEditingController();
  bool _isDeleting = false;

  final _reasons = [
    'Je n\'utilise plus l\'application',
    'Je ne trouve pas de matchs',
    'Problèmes de confidentialité',
    'Interface trop compliquée',
    'Trop de notifications',
    'J\'ai trouvé quelqu\'un',
    'Autre raison',
  ];

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
        ), // ✅ LIMITE HAUTEUR
        child: SingleChildScrollView(
          // ✅ SCROLLABLE
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_step == 0) _buildStep1Warning(theme),
              if (_step == 1) _buildStep2Alternatives(theme),
              if (_step == 2) _buildStep3Reason(theme),
              if (_step == 3) _buildStep4Confirmation(theme),
            ],
          ),
        ),
      ),
    );
  }

  /// 📍 ÉTAPE 1 : AVERTISSEMENT
  Widget _buildStep1Warning(ThemeData theme) {
    return Column(
      children: [
        Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
        const SizedBox(height: 16),
        Text(
          'Supprimer votre compte ?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '⚠️ Cette action est IRRÉVERSIBLE',
                style: TextStyle(
                  color: Colors.red[900],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Vous perdrez définitivement :',
                style: TextStyle(color: Colors.red[900]),
              ),
              const SizedBox(height: 8),
              ...[
                '• Tous vos matchs et conversations',
                '• Toutes vos photos',
                '• Votre profil et informations',
                '• Votre historique complet',
              ].map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(e, style: TextStyle(color: Colors.red[800])),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => setState(() => _step = 1),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Continuer'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 📍 ÉTAPE 2 : ALTERNATIVES (RÉTENTION)
  Widget _buildStep2Alternatives(ThemeData theme) {
    return Column(
      children: [
        Icon(Icons.lightbulb_outline, size: 64, color: Colors.blue),
        const SizedBox(height: 16),
        Text(
          'Avant de partir...',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text('Saviez-vous que vous pouvez :', style: theme.textTheme.bodyLarge),
        const SizedBox(height: 16),
        _buildAlternativeCard(
          icon: Icons.pause_circle_outline,
          title: 'Désactiver temporairement',
          subtitle: 'Votre profil sera masqué 30 jours',
          color: Colors.orange,
        ),
        const SizedBox(height: 12),
        _buildAlternativeCard(
          icon: Icons.notifications_off_outlined,
          title: 'Réduire les notifications',
          subtitle: 'Gardez votre compte, sans spam',
          color: Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildAlternativeCard(
          icon: Icons.visibility_off_outlined,
          title: 'Mode invisible',
          subtitle: 'Naviguez sans être vu',
          color: Colors.purple,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Utiliser une alternative'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => setState(() => _step = 2),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Supprimer quand même'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlternativeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 📍 ÉTAPE 3 : RAISON (ANALYTICS)
  Widget _buildStep3Reason(ThemeData theme) {
    return Column(
      children: [
        Icon(Icons.feedback_outlined, size: 64, color: Colors.grey[600]),
        const SizedBox(height: 16),
        Text(
          'Pourquoi partez-vous ?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Aidez-nous à nous améliorer',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        ..._reasons.map(
          (reason) => RadioListTile<String>(
            value: reason,
            groupValue: _selectedReason,
            onChanged: (val) => setState(() => _selectedReason = val),
            title: Text(reason),
            dense: true,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 1),
                child: const Text('Retour'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _selectedReason != null
                    ? () => setState(() => _step = 3)
                    : null,
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Continuer'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 📍 ÉTAPE 4 : CONFIRMATION FINALE
  Widget _buildStep4Confirmation(ThemeData theme) {
    final isValid = _confirmController.text.toUpperCase() == 'SUPPRIMER';

    return Column(
      children: [
        Icon(Icons.delete_forever, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text(
          'Confirmation finale',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Tapez "SUPPRIMER" pour confirmer la suppression définitive de votre compte',
            style: TextStyle(color: Colors.red[900]),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmController,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'SUPPRIMER',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        if (_isDeleting)
          const Center(child: CircularProgressIndicator())
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 2),
                  child: const Text('Retour'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: isValid ? _deleteAccount : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: const Text('SUPPRIMER DÉFINITIVEMENT'),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _deleteAccount() async {
    setState(() => _isDeleting = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.deleteAccount(reason: _selectedReason);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true); // Retourne true si succès
    } else {
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage ?? 'Erreur lors de la suppression',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
