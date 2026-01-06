// lib/screens/profile_detail_screen.dart
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🎯 Écran détail profil avec animations et actions
/// Design: Carousel photos + info scrollable + actions flottantes
class ProfileDetailScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final bool isMatch;

  const ProfileDetailScreen({
    super.key,
    required this.profile,
    this.isMatch = false,
  });

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _pageController = PageController();
  
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  
  int _currentPhotoIndex = 0;
  List<String> _photoUrls = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    
    _loadPhotos();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _loadPhotos() {
    final photos = widget.profile['photos'] as List?;
    if (photos == null) return;

    final urls = photos
        .where((p) => p['remote_path'] != null)
        .map<String>((p) => p['remote_path'] as String)
        .toList();

    setState(() => _photoUrls = urls);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = widget.profile['full_name'] ?? 'Utilisateur';
    final age = _calculateAge(widget.profile['date_of_birth']);
    final city = widget.profile['city'] ?? '';
    final bio = widget.profile['bio'] ?? '';
    final interests = widget.profile['interests'] as List? ?? [];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          if (widget.isMatch)
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.pink.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.favorite, color: Colors.white),
                onPressed: () {},
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Contenu scrollable
          CustomScrollView(
            slivers: [
              // 📸 Carousel photos
              SliverAppBar(
                expandedHeight: 500,
                pinned: false,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildPhotoCarousel(theme),
                ),
              ),

              // 📝 Informations
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      
                      // Header avec nom/âge
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$name, $age',
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (city.isNotEmpty)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 16,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          city,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            // Badge vérifié
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Bio
                      if (bio.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
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
                                bio,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),

                      // Centres d'intérêt
                      if (interests.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
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
                                children: interests.map((interest) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      interest.toString(),
                                      style: TextStyle(
                                        color: theme.colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 100), // Espace pour les boutons
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 🎯 Boutons d'action flottants
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildActionButtons(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCarousel(ThemeData theme) {
    if (_photoUrls.isEmpty) {
      return Container(
        color: theme.colorScheme.surfaceVariant,
        child: Center(
          child: Icon(
            Icons.person,
            size: 100,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Photos
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _currentPhotoIndex = index);
          },
          itemCount: _photoUrls.length,
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: _photoUrls[index],
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: theme.colorScheme.surfaceVariant,
              ),
              errorWidget: (_, __, ___) => Container(
                color: theme.colorScheme.errorContainer,
                child: Icon(
                  Icons.broken_image,
                  size: 60,
                  color: theme.colorScheme.error,
                ),
              ),
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
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),
        ),

        // Dots indicator
        if (_photoUrls.length > 1)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _photoUrls.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _currentPhotoIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Bouton passer
            Expanded(
              child: OutlinedButton(
                onPressed: _isProcessing ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: theme.colorScheme.outline),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close),
                    SizedBox(width: 8),
                    Text('Passer'),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Bouton like
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _isProcessing ? null : _sendLike,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.colorScheme.primary,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite),
                          SizedBox(width: 8),
                          Text('J\'aime'),
                        ],
                      ),
              ),
            ),

            const SizedBox(width: 16),

            // Bouton message (si match)
            if (widget.isMatch)
              Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () {
                    // TODO: Ouvrir conversation
                  },
                  icon: const Icon(Icons.chat, color: Colors.white),
                  tooltip: 'Message',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendLike() async {
    setState(() => _isProcessing = true);

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Check si like existe déjà
      final existing = await _supabase
          .from('matches')
          .select()
          .or(
            'and(user_id_1.eq.$currentUserId,user_id_2.eq.${widget.profile['id']}),and(user_id_2.eq.$currentUserId,user_id_1.eq.${widget.profile['id']})',
          )
          .maybeSingle();

      if (existing != null) {
        // Like existe déjà, vérifier si match
        if (existing['status'] == 'pending') {
          // C'est un match !
          await _supabase
              .from('matches')
              .update({
                'status': 'matched',
                'matched_at': DateTime.now().toIso8601String(),
              })
              .eq('id', existing['id']);

          if (mounted) {
            _showMatchDialog();
          }
        }
      } else {
        // Créer nouveau like
        await _supabase.from('matches').insert({
          'user_id_1': currentUserId,
          'user_id_2': widget.profile['id'],
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('👍 Like envoyé !'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Send like error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showMatchDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ScaleTransition(
        scale: _scaleAnimation,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🎉',
                style: TextStyle(fontSize: 80),
              ),
              const SizedBox(height: 16),
              Text(
                'C\'est un Match !',
                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vous vous êtes plu mutuellement',
                style: Theme.of(ctx).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  // TODO: Ouvrir conversation
                },
                icon: const Icon(Icons.chat),
                label: const Text('Envoyer un message'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('Plus tard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _calculateAge(String? birthDateStr) {
    if (birthDateStr == null) return 0;
    
    final birthDate = DateTime.tryParse(birthDateStr);
    if (birthDate == null) return 0;
    
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    
    return age;
  }
}