// lib/screens/profile_completion_screen_improved.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../providers/auth_provider.dart';
import '../providers/profile_completion_provider.dart';
import '../services/image_service.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 6; // ✅ +1 page pour la photo de profil

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

  // ✨ NOUVEAU: Photo de profil séparée
  File? _profilePhoto;
  bool _isLoadingLocation = false;

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

  // ✨ NOUVEAU: Récupérer la location automatiquement
  Future<void> _getLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // ⚠️ OPTION 1: Avec geolocator (nécessite l'ajout du package)
      // Voir commentaire ci-dessous pour l'implémentation

      // ⚠️ OPTION 2: Saisie manuelle (par défaut)
      await _showLocationDialog();
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  // Dialog pour saisie manuelle de location
  Future<void> _showLocationDialog() async {
    final cityController = TextEditingController(text: _cityController.text);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Votre localisation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cityController,
              decoration: InputDecoration(
                labelText: 'Ville',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx, {
                'city': cityController.text,
                'country': 'Algérie', // Par défaut
              });
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _cityController.text = result['city'] ?? '';
      });
    }
  }

  Future<void> _skip() async {
    if (_isSkipping) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Passer pour l\'instant ?'),
        content: const Text(
          'Vous pourrez compléter votre profil plus tard.\n\n'
          'Note : Un profil complet augmente vos chances de match !',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Passer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSkipping = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.skipProfileCompletion();

      if (!success && mounted) {
        setState(() => _isSkipping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du skip'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSkipping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _complete() async {
    if (_isSkipping) return;

    setState(() => _isSkipping = true);

    final provider = context.read<ProfileCompletionProvider>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser!.userId;

    // Mettre à jour tous les champs de base
    provider.updateField('full_name', _nameController.text);
    provider.updateField('bio', _bioController.text);
    provider.updateField('city', _cityController.text);
    provider.updateField('country', 'Algérie');
    provider.updateField('occupation', _occupationController.text);
    provider.updateField('instagram_handle', _instagramController.text);
    provider.updateField('gender', _selectedGender);
    provider.updateField('looking_for', _selectedLookingFor);
    provider.updateField('date_of_birth', _selectedDate);
    provider.updateField('height_cm', _selectedHeight);
    provider.updateField('education', _selectedEducation);
    provider.updateField('relationship_status', _selectedRelationship);
    provider.updateField('interests', _selectedInterests);

    // ✅ NOUVEAU: Upload photos avec nouvelle architecture
    try {
      // 1️⃣ Upload photo de profil (type = 'profile')
      if (_profilePhoto != null) {
        debugPrint('📤 Uploading profile photo...');

        final profileUrl = await provider.imageService.uploadToStorage(
          imageFile: _profilePhoto!,
          userId: userId,
          photoType: PhotoType.profile, // ✅ Nouvelle signature
        );

        if (profileUrl != null) {
          // ✅ Créer l'entrée dans la table photos
          await _supabase.from('photos').insert({
            'id': const Uuid().v4(),
            'user_id': userId,
            'remote_path': profileUrl,
            'type': 'profile',
            'status': 'pending', // ✅ Modération requise
            'has_watermark': true,
            'display_order': 0,
            'uploaded_at': DateTime.now().toIso8601String(),
          });
          debugPrint('✅ Profile photo uploaded and saved to DB');
        }
      }

      // 2️⃣ ✅ NOUVEAU: Upload covers (NON IMPLÉMENTÉ DANS L'ANCIEN CODE)
      // À ajouter si besoin

      // 3️⃣ ✅ NOUVEAU: Upload gallery photos (NON IMPLÉMENTÉ DANS L'ANCIEN CODE)
      // À ajouter si besoin
    } catch (e) {
      debugPrint('❌ Photo upload error: $e');
      setState(() => _isSkipping = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur upload photo: $e')));
      return;
    }

    // Sauvegarder le profil
    final success = await provider.saveProfile(isSkipped: false);

    if (!mounted) return;

    if (success) {
      try {
        await authProvider.reloadCurrentUser();
        debugPrint('✅ Profile completed successfully');
      } catch (e) {
        setState(() => _isSkipping = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } else {
      setState(() => _isSkipping = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Erreur de sauvegarde')));
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
          ),
          const SizedBox(width: 8),
        ],
      ),
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
                    ? const NeverScrollableScrollPhysics()
                    : null,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildBasicInfoPage(),
                  _buildProfilePhotoPage(), // ✨ NOUVEAU
                  _buildGalleryPhotosPage(), // ✨ MODIFIÉ
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
                      child: _isSkipping
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
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

          // ✨ NOUVEAU: Location avec bouton auto
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: 'Ville *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isLoadingLocation ? null : _getLocation,
                icon: _isLoadingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location),
                tooltip: 'Position actuelle',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✨ NOUVEAU: Page photo de profil
  Widget _buildProfilePhotoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Photo de profil',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Choisissez une belle photo pour votre profil',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),

          Center(
            child: GestureDetector(
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
                          onTap: () async {
                            Navigator.pop(ctx);
                            final provider = context
                                .read<ProfileCompletionProvider>();
                            final photo = await provider.imageService
                                .captureFromCamera();
                            if (photo != null) {
                              setState(() => _profilePhoto = photo);
                            }
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text('Galerie'),
                          onTap: () async {
                            Navigator.pop(ctx);
                            final provider = context
                                .read<ProfileCompletionProvider>();
                            final photo = await provider.imageService
                                .pickFromGallery();
                            if (photo != null) {
                              setState(() => _profilePhoto = photo);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                ),
                child: _profilePhoto != null
                    ? ClipOval(
                        child: Image.file(_profilePhoto!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            size: 48,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ajouter une photo',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✨ MODIFIÉ: Photos de galerie (sans la photo de profil)
  Widget _buildGalleryPhotosPage() {
    return Consumer<ProfileCompletionProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Photos de galerie',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ajoutez 3 à 6 photos pour votre galerie',
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
          border: Border.all(color: Colors.grey[400]!, width: 2),
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
