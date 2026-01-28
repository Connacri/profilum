// lib/screens/profile_page_carousel.dart - ✅ VERSION SANS OBJECTBOX

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper_utilities.dart';
import '../providers/auth_provider.dart';

import '../widgets/account_deletion_dialog.dart';
import 'auth_provider_optimized.dart';
import 'profile_completion_screen_example.dart';
import 'service_locator.dart';


/// 📸 Modèle de photo avec métadonnées
class PhotoDisplay {
  final String url;
  final String type;
  final String status;
  final bool isPending;

  PhotoDisplay({
    required this.url,
    required this.type,
    required this.status,
  }) : isPending = status == 'pending';
}

class ProfilePage extends StatefulWidget {
  final String? viewingUserId;

  const ProfilePage({super.key, this.viewingUserId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final PageController _carouselController = PageController();
  int _currentPhotoIndex = 0;

  List<PhotoDisplay> _galleryPhotos = [];
  PhotoDisplay? _profilePhoto;
  bool _isLoadingPhotos = true;
  bool _isOwnProfile = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  /// 🔍 CHARGEMENT INTELLIGENT DES PHOTOS
  Future<void> _loadPhotos() async {
    setState(() {
      _isLoadingPhotos = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.currentUser?.userId;
      final targetUserId = widget.viewingUserId ?? currentUserId;
      final currentUserRole = authProvider.currentUser?.role;

      if (currentUserId == null || targetUserId == null) {
        throw Exception('User ID manquant');
      }

      _isOwnProfile = currentUserId == targetUserId;

      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('📸 LOADING PHOTOS');
      debugPrint('   Current User: $currentUserId');
      debugPrint('   Target User: $targetUserId');
      debugPrint('   Is Own Profile: $_isOwnProfile');
      debugPrint('   Role: $currentUserRole');
      debugPrint('═══════════════════════════════════════════════════');

      // ✅ Charger depuis PhotoCrudService (remplace ObjectBox)
      final photos = await services.photoCrudService.getPhotos(
        userId: targetUserId,
        forceRefresh: false,
      );

      debugPrint('📦 Loaded ${photos.length} photos from service');

      // 🎯 Filtrage selon contexte
      List<Map<String, dynamic>> filteredPhotos;

      if (_isOwnProfile) {
        // Propriétaire : approved + pending
        filteredPhotos = photos
            .where((p) =>
        p['remote_path'] != null &&
            (p['status'] == 'approved' || p['status'] == 'pending'))
            .toList();
      } else if (currentUserRole == 'admin' || currentUserRole == 'moderator') {
        // Admin/Mod : tout
        filteredPhotos = photos.where((p) => p['remote_path'] != null).toList();
      } else {
        // Public : approved seulement
        filteredPhotos = photos
            .where((p) => p['remote_path'] != null && p['status'] == 'approved')
            .toList();
      }

      // Trier par display_order
      filteredPhotos.sort((a, b) {
        final orderA = a['display_order'] as int? ?? 0;
        final orderB = b['display_order'] as int? ?? 0;
        return orderA.compareTo(orderB);
      });

      // 🖼️ Photo de profil
      final profilePhotoData = filteredPhotos
          .where((p) => p['type'] == 'profile')
          .cast<Map<String, dynamic>>()
          .firstOrNull;

      if (profilePhotoData != null) {
        final url = services.photoUrlHelper.buildPhotoUrl(
          profilePhotoData['remote_path'] as String,
        );

        _profilePhoto = PhotoDisplay(
          url: url,
          type: 'profile',
          status: profilePhotoData['status'] as String? ?? 'approved',
        );
      }

      // 🖼️ Photos galerie
      _galleryPhotos = filteredPhotos
          .where((p) => p['type'] == 'gallery')
          .map((p) {
        final url = services.photoUrlHelper.buildPhotoUrl(
          p['remote_path'] as String,
        );
        return PhotoDisplay(
          url: url,
          type: 'gallery',
          status: p['status'] as String? ?? 'approved',
        );
      }).toList();

      debugPrint('📷 Profile photo: ${_profilePhoto?.status}');
      debugPrint('🖼️ Gallery photos: ${_galleryPhotos.length}');

      setState(() => _isLoadingPhotos = false);

      debugPrint('✅ Photos loaded successfully');
      debugPrint('═══════════════════════════════════════════════════');
    } catch (e, stack) {
      debugPrint('❌ Load photos error: $e');
      debugPrint('Stack: $stack');

      setState(() {
        _errorMessage = 'Erreur de chargement des photos: $e';
        _isLoadingPhotos = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Aucun utilisateur connecté')),
      );
    }

    if (_isLoadingPhotos) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!.toLowerCase().capitalize(),
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _loadPhotos,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final hasPhotos = _galleryPhotos.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 🎨 Carousel Header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: hasPhotos
                  ? _buildPhotoCarousel()
                  : _buildNoPhotosPlaceholder(theme),
            ),
          ),

          // 📝 Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Profile Section
                Transform.translate(
                  offset: const Offset(0, 20),
                  child: Column(
                    children: [
                      // Avatar
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.scaffoldBackgroundColor,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Opacity(
                              opacity: (_profilePhoto?.isPending == true && _isOwnProfile)
                                  ? 0.5
                                  : 1.0,
                              child: CircleAvatar(
                                key: ValueKey(_profilePhoto?.url ?? 'no-photo'),
                                radius: 60,
                                backgroundImage: _profilePhoto != null
                                    ? CachedNetworkImageProvider(
                                  _profilePhoto!.url,
                                  cacheKey: _profilePhoto!.isPending
                                      ? '${_profilePhoto!.url}_${DateTime.now().millisecondsSinceEpoch}'
                                      : null,
                                )
                                    : null,
                                child: _profilePhoto == null
                                    ? const Icon(Icons.person, size: 60)
                                    : null,
                              ),
                            ),

                            // Badge modération
                            if (_profilePhoto?.isPending == true && _isOwnProfile)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.orange.shade600,
                                        Colors.orange.shade400,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.4),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.hourglass_empty,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'MODÉRATION',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Nom
                      Text(
                        user.fullName?.toLowerCase().capitalize() ?? 'Utilisateur',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Location
                      if (user.city != null || user.country != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              [
                                user.city?.toLowerCase().capitalize(),
                                user.country?.toLowerCase().capitalize(),
                              ].where((e) => e != null).join(', '),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 8),

                      // Badge completion
                      if (!user.profileCompleted && _isOwnProfile)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.warning_amber,
                                color: Colors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Profil incomplet (${user.completionPercentage}%)',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (user.gender != null)
                        Chip(
                          label: Text(user.gender!.capitalize()),
                          backgroundColor: theme
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.5),
                        ),

                      const SizedBox(height: 8),
                      Text(user.email),
                    ],
                  ),
                ),

                // Miniatures photos
                if (hasPhotos)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Photos (${_galleryPhotos.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _galleryPhotos.length,
                            itemBuilder: (context, index) {
                              final photo = _galleryPhotos[index];

                              return GestureDetector(
                                onTap: () {
                                  setState(() => _currentPhotoIndex = index);
                                  _carouselController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      width: 80,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _currentPhotoIndex == index
                                              ? theme.colorScheme.primary
                                              : Colors.transparent,
                                          width: 3,
                                        ),
                                      ),
                                      child: Opacity(
                                        opacity: (photo.isPending && _isOwnProfile)
                                            ? 0.5
                                            : 1.0,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: CachedNetworkImage(
                                            key: ValueKey(
                                              photo.isPending
                                                  ? '${photo.url}_thumb_${DateTime.now().millisecondsSinceEpoch}'
                                                  : '${photo.url}_thumb',
                                            ),
                                            imageUrl: photo.url,
                                            fit: BoxFit.cover,
                                            cacheKey: photo.isPending
                                                ? '${photo.url}_thumb_nocache_${DateTime.now().millisecondsSinceEpoch}'
                                                : null,
                                            placeholder: (_, __) => Container(
                                              color: Colors.grey[200],
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            errorWidget: (_, __, ___) => Container(
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                                size: 24,
                                              ),
                                            ),
                                            memCacheWidth: 200,
                                            memCacheHeight: 200,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Badge modération miniature
                                    if (photo.isPending && _isOwnProfile)
                                      Positioned(
                                        top: 4,
                                        left: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'MOD',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // Bio
                if (user.bio != null && user.bio!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'À propos',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user.bio!.toLowerCase().capitalize(),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),

                // Stats
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                            icon: Icons.photo,
                            label: 'Photos',
                            value: '${_galleryPhotos.length}',
                          ),
                          const _StatItem(
                            icon: Icons.favorite,
                            label: 'Matches',
                            value: '0',
                          ),
                          const _StatItem(
                            icon: Icons.chat,
                            label: 'Messages',
                            value: '0',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Interests
                if (user.interests.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Centres d\'intérêt',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: user.interests
                              .map((interest) => Chip(
                            label: Text(interest.toLowerCase().capitalize()),
                            backgroundColor: theme
                                .colorScheme
                                .primaryContainer
                                .withOpacity(0.5),
                          ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Action Button
                if (!user.profileCompleted && _isOwnProfile)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileCompletionScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Compléter mon profil'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                // Menu (si proprio)
                if (_isOwnProfile) ...[
                  const SizedBox(height: 16),

                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Modifier le profil'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileCompletionScreen(),
                      ),
                    ),
                  ),

                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Paramètres'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),

                  const SizedBox(height: 16),

                  // Logout
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Déconnexion'),
                            content: const Text(
                              'Voulez-vous vraiment vous déconnecter ?',
                            ),
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
                      icon: const Icon(Icons.logout),
                      label: const Text('Déconnexion'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),

                  const Divider(),

                  // Delete account
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text(
                      'Supprimer mon compte',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Action irréversible',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.red),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const AccountDeletionDialog(),
                      );

                      if (confirmed == true && mounted) {
                        // Redirect auto via AuthProvider
                      }
                    },
                  ),
                ],

                const SizedBox(height: 32),

                // Version
                Center(
                  child: Text(
                    'Profilum v1.0.0',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCarousel() {
    return Stack(
      children: [
        PageView.builder(
          controller: _carouselController,
          onPageChanged: (index) {
            setState(() => _currentPhotoIndex = index);
          },
          itemCount: _galleryPhotos.length,
          itemBuilder: (context, index) {
            final photo = _galleryPhotos[index];

            return Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: (photo.isPending && _isOwnProfile) ? 0.5 : 1.0,
                  child: CachedNetworkImage(
                    key: ValueKey(
                      photo.isPending
                          ? '${photo.url}_${DateTime.now().millisecondsSinceEpoch}'
                          : photo.url,
                    ),
                    imageUrl: photo.url,
                    fit: BoxFit.cover,
                    cacheKey: photo.isPending
                        ? '${photo.url}_nocache_${DateTime.now().millisecondsSinceEpoch}'
                        : null,
                    placeholder: (_, __) => Container(
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey[300],
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 80, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Image non disponible',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    memCacheWidth: 1920,
                    memCacheHeight: 1920,
                  ),
                ),

                // Badge modération carousel
                if (photo.isPending && _isOwnProfile)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade600,
                            Colors.orange.shade400,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_empty, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'EN MODÉRATION',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        // Gradient overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
              ),
            ),
          ),
        ),

        // Dots indicator
        if (_galleryPhotos.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _galleryPhotos.length,
                    (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPhotoIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
            ),
          ),

        // Navigation arrows
        if (_galleryPhotos.length > 1) ...[
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                onPressed: () {
                  if (_currentPhotoIndex > 0) {
                    _carouselController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
                onPressed: () {
                  if (_currentPhotoIndex < _galleryPhotos.length - 1) {
                    _carouselController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNoPhotosPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceVariant,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune photo',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value.toLowerCase().capitalize(),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label.toLowerCase().capitalize(),
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}