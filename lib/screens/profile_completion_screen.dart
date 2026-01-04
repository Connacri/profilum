import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/profile_completion_provider.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 5;

  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final _occupationController = TextEditingController();
  final _instagramController = TextEditingController();

  String? _selectedGender;
  String? _selectedLookingFor;
  DateTime? _selectedDate;
  int? _selectedHeight;
  String? _selectedEducation;
  String? _selectedRelationship;
  List<String> _selectedInterests = [];

  // ✨ FIX: État pour désactiver le bouton pendant le traitement
  bool _isSkipping = false;

  final List<String> _availableInterests = [
    'Sport',
    'Musique',
    'Voyages',
    'Cuisine',
    'Art',
    'Cinéma',
    'Lecture',
    'Gaming',
    'Nature',
    'Technologie',
    'Danse',
    'Photographie',
    'Mode',
    'Yoga',
    'Méditation',
  ];

  @override
  void initState() {
    super.initState();

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user != null) {
      final provider = context.read<ProfileCompletionProvider>();
      provider.initialize(user);

      _nameController.text = user.fullName ?? '';
      _bioController.text = user.bio ?? '';
      _cityController.text = user.city ?? '';
      _occupationController.text = user.occupation ?? '';
      _instagramController.text = user.instagramHandle ?? '';
      _selectedGender = user.gender;
      _selectedLookingFor = user.lookingFor;
      _selectedDate = user.dateOfBirth;
      _selectedHeight = user.heightCm;
      _selectedEducation = user.education;
      _selectedRelationship = user.relationshipStatus;
      _selectedInterests = List.from(user.interests);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _occupationController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ✨ FIX: Méthode skip améliorée avec logs et gestion d'état
  Future<void> _skip() async {
    // Empêcher les clics multiples
    if (_isSkipping) {
      debugPrint('⚠️ Skip already in progress, ignoring...');
      return;
    }

    debugPrint('🔵 Skip button clicked');

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // ✨ Empêcher de fermer en cliquant dehors
      builder: (ctx) => AlertDialog(
        title: const Text('Passer pour l\'instant ?'),
        content: const Text(
          'Vous pourrez compléter votre profil plus tard.\n\n'
          'Note : Un profil complet augmente vos chances de match !',
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('🔵 Skip cancelled by user');
              Navigator.pop(ctx, false);
            },
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              debugPrint('🔵 Skip confirmed by user');
              Navigator.pop(ctx, true);
            },
            child: const Text('Passer'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      debugPrint('🔵 Skip not confirmed, aborting');
      return;
    }

    if (!mounted) {
      debugPrint('❌ Widget not mounted, aborting skip');
      return;
    }

    // ✨ FIX: Activer l'état de chargement
    setState(() {
      _isSkipping = true;
    });

    debugPrint('🔵 Calling AuthProvider.skipProfileCompletion()...');

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.skipProfileCompletion();

      debugPrint('🔵 Skip result: $success');
      debugPrint('🔵 New auth status: ${authProvider.status}');

      if (!mounted) {
        debugPrint('❌ Widget not mounted after skip');
        return;
      }

      if (success) {
        debugPrint('✅ Skip successful!');
        debugPrint('🔵 Router should now redirect to HomeScreen');

        // ✨ FIX: Attendre un frame pour que le router se rebuild
        await Future.delayed(const Duration(milliseconds: 100));

        // Si on est toujours sur cet écran après 500ms, c'est qu'il y a un problème
        await Future.delayed(const Duration(milliseconds: 400));

        if (mounted) {
          debugPrint('⚠️ Still on ProfileCompletionScreen after skip!');
          debugPrint('   This might indicate a router issue');
        }
      } else {
        debugPrint('❌ Skip failed');

        setState(() {
          _isSkipping = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors du skip. Veuillez réessayer.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('❌ Exception during skip: $e');
      debugPrint('Stack: $stack');

      setState(() {
        _isSkipping = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _complete() async {
    final provider = context.read<ProfileCompletionProvider>();

    provider.updateField('full_name', _nameController.text);
    provider.updateField('bio', _bioController.text);
    provider.updateField('city', _cityController.text);
    provider.updateField('occupation', _occupationController.text);
    provider.updateField('instagram_handle', _instagramController.text);
    provider.updateField('gender', _selectedGender);
    provider.updateField('looking_for', _selectedLookingFor);
    provider.updateField('date_of_birth', _selectedDate);
    provider.updateField('height_cm', _selectedHeight);
    provider.updateField('education', _selectedEducation);
    provider.updateField('relationship_status', _selectedRelationship);
    provider.updateField('interests', _selectedInterests);

    final success = await provider.saveProfile(isSkipped: false);

    if (success && mounted) {
      debugPrint('✅ Profile completed - router will redirect to home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // ✨ FIX: Désactiver le bouton pendant le traitement
          TextButton.icon(
            onPressed: _isSkipping ? null : _skip,
            icon: _isSkipping
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.skip_next),
            label: Text(_isSkipping ? 'Chargement...' : 'Passer'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      // ✨ FIX: Empêcher le pop pendant le skip
      body: WillPopScope(
        onWillPop: () async => !_isSkipping,
        child: Column(
          children: [
            // Progress Bar
            Consumer<ProfileCompletionProvider>(
              builder: (context, provider, _) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Complétion du profil',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${provider.completionPercentage}%',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: provider.completionPercentage / 100,
                          minHeight: 8,
                          backgroundColor: theme.colorScheme.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: _isSkipping
                    ? const NeverScrollableScrollPhysics() // Bloquer le swipe pendant le skip
                    : null,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildBasicInfoPage(),
                  _buildPhotosPage(),
                  _buildPersonalityPage(),
                  _buildDetailsPage(),
                  _buildInterestsPage(),
                ],
              ),
            ),

            // Navigation Buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSkipping ? null : _previousPage,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Précédent'),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _isSkipping
                          ? null
                          : (_currentPage == _totalPages - 1
                                ? _complete
                                : _nextPage),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentPage == _totalPages - 1
                            ? 'Terminer'
                            : 'Suivant',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Informations de base',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 24),

          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nom complet *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime(2000),
                firstDate: DateTime(1950),
                lastDate: DateTime.now().subtract(
                  const Duration(days: 365 * 18),
                ),
              );
              if (date != null) {
                setState(() => _selectedDate = date);
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date de naissance *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _selectedDate != null
                    ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                    : 'Sélectionner',
              ),
            ),
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: InputDecoration(
              labelText: 'Genre *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Homme')),
              DropdownMenuItem(value: 'female', child: Text('Femme')),
              DropdownMenuItem(value: 'mtf', child: Text('MTF')),
              DropdownMenuItem(value: 'ftm', child: Text('FTM')),
            ],
            onChanged: (value) => setState(() => _selectedGender = value),
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _selectedLookingFor,
            decoration: InputDecoration(
              labelText: 'Recherche *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Hommes')),
              DropdownMenuItem(value: 'female', child: Text('Femmes')),
              DropdownMenuItem(value: 'everyone', child: Text('Tout le monde')),
            ],
            onChanged: (value) => setState(() => _selectedLookingFor = value),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _cityController,
            decoration: InputDecoration(
              labelText: 'Ville *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosPage() {
    return Consumer<ProfileCompletionProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ajoutez vos photos',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Minimum 3 photos requises pour voir les albums des autres',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),

              const SizedBox(height: 24),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount:
                    provider.selectedPhotos.length +
                    (provider.selectedPhotos.length < 6 ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == provider.selectedPhotos.length) {
                    return _buildAddPhotoCard(provider);
                  }

                  return _buildPhotoCard(
                    provider.selectedPhotos[index],
                    index,
                    provider,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddPhotoCard(ProfileCompletionProvider provider) {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Prendre une photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    provider.addPhotosFromCamera();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Galerie'),
                  onTap: () {
                    Navigator.pop(ctx);
                    provider.addPhotosFromGallery();
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[400]!,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: const Center(
          child: Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildPhotoCard(
    File photo,
    int index,
    ProfileCompletionProvider provider,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(photo, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
            onPressed: () => provider.removePhoto(index),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalityPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Parlez de vous',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 24),

          TextField(
            controller: _bioController,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Bio (minimum 50 caractères) *',
              hintText: 'Décrivez-vous en quelques mots...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Détails supplémentaires',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 24),

          TextField(
            controller: _occupationController,
            decoration: InputDecoration(
              labelText: 'Profession *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _selectedEducation,
            decoration: InputDecoration(
              labelText: 'Éducation *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'high_school', child: Text('Lycée')),
              DropdownMenuItem(value: 'bachelor', child: Text('Licence')),
              DropdownMenuItem(value: 'master', child: Text('Master')),
              DropdownMenuItem(value: 'phd', child: Text('Doctorat')),
            ],
            onChanged: (value) => setState(() => _selectedEducation = value),
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<int>(
            value: _selectedHeight,
            decoration: InputDecoration(
              labelText: 'Taille (cm) *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: List.generate(
              100,
              (i) => DropdownMenuItem(
                value: 140 + i,
                child: Text('${140 + i} cm'),
              ),
            ),
            onChanged: (value) => setState(() => _selectedHeight = value),
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _selectedRelationship,
            decoration: InputDecoration(
              labelText: 'Situation *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'single', child: Text('Célibataire')),
              DropdownMenuItem(value: 'divorced', child: Text('Divorcé(e)')),
              DropdownMenuItem(value: 'widowed', child: Text('Veuf/Veuve')),
            ],
            onChanged: (value) => setState(() => _selectedRelationship = value),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _instagramController,
            decoration: InputDecoration(
              labelText: 'Instagram (optionnel)',
              prefixText: '@',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Vos centres d\'intérêt',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            'Sélectionnez au moins 3 centres d\'intérêt',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),

          const SizedBox(height: 24),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableInterests.map((interest) {
              final isSelected = _selectedInterests.contains(interest);

              return FilterChip(
                label: Text(interest),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedInterests.add(interest);
                    } else {
                      _selectedInterests.remove(interest);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
