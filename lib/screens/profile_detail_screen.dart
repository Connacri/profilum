// lib/screens/profile_detail_screen.dart - ✅ ADAPTÉ À VOTRE SCHÉMA
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/fix_photo_url_builder.dart';

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
  late final PhotoUrlHelper _photoUrlHelper;
  late AnimationController _animController;

  int _currentPhotoIndex = 0;
  List<String> _photoUrls = [];
  bool _isProcessing = false;

  // ✅ ÉTAT DYNAMIQUE DU LIKE - ADAPTÉ À VOTRE SCHÉMA
  String? _likeStatus; // 'i_liked' | 'they_liked' | 'matched' | null
  String? _matchId;
  bool _amIUser1 = false; // Pour savoir si je suis user_id_1 ou user_id_2
  bool _isLoadingStatus = true;

  @override
  void initState() {
    super.initState();
    _photoUrlHelper = PhotoUrlHelper(_supabase);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadPhotos();
    _loadLikeStatus();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _loadPhotos() {
    final urls = _photoUrlHelper.buildGalleryPhotoUrls(widget.profile);
    if (urls.isEmpty) {
      final profileUrl = _photoUrlHelper.buildProfilePhotoUrl(widget.profile);
      setState(() => _photoUrls = profileUrl != null ? [profileUrl] : []);
    } else {
      setState(() => _photoUrls = urls);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ✅ CHARGER L'ÉTAT DU LIKE - ADAPTÉ user_1_liked/user_2_liked
  // ═══════════════════════════════════════════════════════════════════════
  Future<void> _loadLikeStatus() async {
    setState(() => _isLoadingStatus = true);

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final targetUserId = widget.profile['id'];

      // ✅ Chercher match/like type='like' (pas flash)
      // Il peut y avoir 2 cas:
      // 1. Je suis user_id_1, target est user_id_2
      // 2. Target est user_id_1, je suis user_id_2

      final match = await _supabase
          .from('matches')
          .select(
            'id, user_id_1, user_id_2, user_1_liked, user_2_liked, status',
          )
          .eq('type', 'like')
          .or(
            'and(user_id_1.eq.$currentUserId,user_id_2.eq.$targetUserId),and(user_id_1.eq.$targetUserId,user_id_2.eq.$currentUserId)',
          )
          .maybeSingle();

      if (match != null) {
        _matchId = match['id'];
        _amIUser1 = match['user_id_1'] == currentUserId;

        final user1Liked = match['user_1_liked'] == true;
        final user2Liked = match['user_2_liked'] == true;

        if (user1Liked && user2Liked) {
          _likeStatus = 'matched';
        } else if (_amIUser1 && user1Liked) {
          _likeStatus = 'i_liked';
        } else if (!_amIUser1 && user2Liked) {
          _likeStatus = 'i_liked';
        } else if (!_amIUser1 && user1Liked) {
          _likeStatus = 'they_liked';
        } else if (_amIUser1 && user2Liked) {
          _likeStatus = 'they_liked';
        }
      } else {
        _likeStatus = null;
      }

      debugPrint(
        '💡 Status: $_likeStatus | MatchId: $_matchId | AmIUser1: $_amIUser1',
      );
    } catch (e) {
      debugPrint('❌ Load status: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ✅ ENVOYER/ANNULER LIKE - ADAPTÉ
  // ═══════════════════════════════════════════════════════════════════════
  Future<void> _toggleLike() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final targetUserId = widget.profile['id'];

      if (_likeStatus == null) {
        // ✅ ENVOYER LIKE
        await _sendLike(currentUserId, targetUserId);
      } else if (_likeStatus == 'i_liked') {
        // ✅ ANNULER MON LIKE
        await _cancelLike();
      } else if (_likeStatus == 'they_liked') {
        // ✅ ACCEPTER LEUR LIKE = MATCH
        await _acceptLike();
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _sendLike(String currentUserId, String targetUserId) async {
    // ✅ Vérifier si l'autre m'a déjà liké
    final reciprocal = await _supabase
        .from('matches')
        .select('id, user_id_1, user_2_liked')
        .eq('user_id_1', targetUserId)
        .eq('user_id_2', currentUserId)
        .eq('type', 'like')
        .eq('user_1_liked', true)
        .maybeSingle();

    if (reciprocal != null) {
      // ✅ MATCH IMMÉDIAT
      await _supabase
          .from('matches')
          .update({
            'user_2_liked': true,
            'status': 'matched',
            'matched_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reciprocal['id']);

      setState(() {
        _likeStatus = 'matched';
        _matchId = reciprocal['id'];
        _amIUser1 = false;
      });

      if (mounted) _showMatchDialog();
    } else {
      // ✅ LIKE SIMPLE (je deviens user_id_1)
      final newMatch = await _supabase
          .from('matches')
          .insert({
            'user_id_1': currentUserId,
            'user_id_2': targetUserId,
            'user_1_liked': true,
            'user_2_liked': false,
            'type': 'like',
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      setState(() {
        _likeStatus = 'i_liked';
        _matchId = newMatch['id'];
        _amIUser1 = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('👍 Like envoyé !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _cancelLike() async {
    if (_matchId == null) return;

    try {
      // ✅ CORRECTION : Supprimer directement au lieu de mettre à false
      await _supabase.from('matches').delete().eq('id', _matchId!);

      setState(() {
        _likeStatus = null;
        _matchId = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Like annulé'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Cancel like error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _acceptLike() async {
    if (_matchId == null) return;

    // ✅ Mettre mon like à true
    if (_amIUser1) {
      await _supabase
          .from('matches')
          .update({
            'user_1_liked': true,
            'status': 'matched',
            'matched_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _matchId!);
    } else {
      await _supabase
          .from('matches')
          .update({
            'user_2_liked': true,
            'status': 'matched',
            'matched_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _matchId!);
    }

    setState(() => _likeStatus = 'matched');

    if (mounted) _showMatchDialog();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ✅ ENVOYER FLASH (24h)
  // ═══════════════════════════════════════════════════════════════════════
  Future<void> _sendFlash() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final targetUserId = widget.profile['id'];

      // ✅ Vérifier si flash déjà envoyé (dernières 24h)
      final existing = await _supabase
          .from('matches')
          .select('id')
          .eq('user_id_1', currentUserId)
          .eq('user_id_2', targetUserId)
          .eq('type', 'flash')
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚡ Flash déjà envoyé !'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // ✅ Créer nouveau flash
      await _supabase.from('matches').insert({
        'user_id_1': currentUserId,
        'user_id_2': targetUserId,
        'user_1_liked': true,
        'user_2_liked': false,
        'type': 'flash',
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now()
            .add(const Duration(hours: 24))
            .toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚡ Flash envoyé (24h) !'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Send flash: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🎨 UI
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 500,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildPhotoCarousel(theme),
                ),
              ),
              SliverToBoxAdapter(child: _buildProfileInfo(theme)),
            ],
          ),
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
        child: const Icon(Icons.person, size: 100),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentPhotoIndex = index),
          itemCount: _photoUrls.length,
          itemBuilder: (context, index) => CachedNetworkImage(
            imageUrl: _photoUrls[index],
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: theme.colorScheme.surfaceVariant,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, __, ___) => Container(
              color: theme.colorScheme.surfaceVariant,
              child: const Icon(Icons.person, size: 100),
            ),
          ),
        ),
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
                colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
              ),
            ),
          ),
        ),
        if (_photoUrls.length > 1)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _photoUrls.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _currentPhotoIndex == i
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

  Widget _buildProfileInfo(ThemeData theme) {
    final name = widget.profile['full_name'] ?? 'Utilisateur';
    final age = _calculateAge(widget.profile['date_of_birth']);
    final city = widget.profile['city'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                  const Icon(Icons.location_on, size: 16),
                  const SizedBox(width: 4),
                  Text(city),
                ],
              ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ✅ BOUTONS DYNAMIQUES - ADAPTÉ
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildActionButtons(ThemeData theme) {
    if (_isLoadingStatus) {
      return Container(
        color: theme.scaffoldBackgroundColor,
        padding: const EdgeInsets.all(24),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // ⚡ BOUTON FLASH
            if (_likeStatus != 'matched')
              IconButton(
                onPressed: _isProcessing ? null : _sendFlash,
                icon: const Icon(Icons.flash_on, color: Colors.orange),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  padding: const EdgeInsets.all(16),
                ),
                tooltip: 'Flash 24h',
              ),

            const SizedBox(width: 12),

            // ✅ BOUTON PRINCIPAL DYNAMIQUE
            Expanded(child: _buildMainButton(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButton(ThemeData theme) {
    if (_isProcessing) {
      return FilledButton(
        onPressed: null,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    switch (_likeStatus) {
      case 'matched':
        return FilledButton.icon(
          onPressed: () {
            // TODO: Ouvrir chat
          },
          icon: const Icon(Icons.chat),
          label: const Text('Message'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
            minimumSize: const Size(double.infinity, 50),
          ),
        );

      case 'i_liked':
        return OutlinedButton.icon(
          onPressed: _toggleLike,
          icon: const Icon(Icons.close),
          label: const Text('Annuler'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange,
            minimumSize: const Size(double.infinity, 50),
          ),
        );

      case 'they_liked':
        return FilledButton.icon(
          onPressed: _toggleLike,
          icon: const Icon(Icons.favorite),
          label: const Text('Accepter'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.pink,
            minimumSize: const Size(double.infinity, 50),
          ),
        );

      default: // null
        return FilledButton.icon(
          onPressed: _toggleLike,
          icon: const Icon(Icons.favorite),
          label: const Text('J\'aime'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            minimumSize: const Size(double.infinity, 50),
          ),
        );
    }
  }

  void _showMatchDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            const Text(
              'C\'est un Match !',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.chat),
              label: const Text('Envoyer message'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.pink,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Plus tard'),
            ),
          ],
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
