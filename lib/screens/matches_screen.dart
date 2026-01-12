// lib/screens/matches_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide DateUtils;
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helper_utilities.dart';
import '../services/fix_photo_url_builder.dart';
import 'profile_detail_screen.dart';

/// 🎯 Écran Matches avec 4 onglets
/// 1. Matches (mutuels) | 2. J'ai aimé | 3. M'ont aimé | 4. Taps reçus
class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabController;
  late final PhotoUrlHelper _photoUrlHelper;

  // 1️⃣ Matches mutuels
  List<Map<String, dynamic>> _matches = [];
  bool _isLoadingMatches = true;

  // 2️⃣ J'ai aimé (likes envoyés en attente)
  List<Map<String, dynamic>> _myLikes = [];
  bool _isLoadingMyLikes = true;

  // 3️⃣ M'ont aimé (likes reçus en attente)
  List<Map<String, dynamic>> _theirLikes = [];
  bool _isLoadingTheirLikes = true;

  // 4️⃣ Taps reçus
  List<Map<String, dynamic>> _taps = [];
  bool _isLoadingTaps = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _photoUrlHelper = PhotoUrlHelper(_supabase);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadMatches(),
      _loadMyLikes(),
      _loadTheirLikes(),
      _loadTaps(),
    ]);
  }

  /// 1️⃣ MATCHES MUTUELS (status = 'matched')
  Future<void> _loadMatches() async {
    setState(() => _isLoadingMatches = true);

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // ✅ Récupérer les matches où JE suis impliqué ET status = matched
      final matches = await _supabase
          .from('matches')
          .select('''
          id,
          user_id_1,
          user_id_2,
          matched_at,
          profiles_1:user_id_1 (
            id, full_name, date_of_birth, city, bio, interests, last_active_at,
            photos:photos!photos_user_id_fkey(remote_path, type, status, display_order)
          ),
          profiles_2:user_id_2 (
            id, full_name, date_of_birth, city, bio, interests, last_active_at,
            photos:photos!photos_user_id_fkey(remote_path, type, status, display_order)
          )
        ''')
          .or('user_id_1.eq.$currentUserId,user_id_2.eq.$currentUserId')
          .eq('status', 'matched')
          .order('matched_at', ascending: false);

      if (mounted) {
        // ✅ Extraire le profil de l'autre personne
        final processedMatches = matches.map((m) {
          final isUser1 = m['user_id_1'] == currentUserId;
          return {
            'id': m['id'],
            'matched_at': m['matched_at'],
            'profile': isUser1 ? m['profiles_2'] : m['profiles_1'],
          };
        }).toList();

        setState(() {
          _matches = processedMatches;
          _isLoadingMatches = false;
        });
      }

      debugPrint('💕 Loaded ${_matches.length} mutual matches');
    } catch (e) {
      debugPrint('❌ Load matches error: $e');
      if (mounted) setState(() => _isLoadingMatches = false);
    }
  }

  /// 2️⃣ J'AI AIMÉ (likes envoyés, status = 'pending')
  Future<void> _loadMyLikes() async {
    setState(() => _isLoadingMyLikes = true);

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final matches = await _supabase
          .from('matches')
          .select('''
          id, created_at,
          profiles:user_id_2 (
            id, full_name, date_of_birth, city, bio, interests, last_active_at,
            photos:photos!photos_user_id_fkey(remote_path, type, status, display_order)
          )
        ''')
          .eq('user_id_1', currentUserId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _myLikes = List<Map<String, dynamic>>.from(matches);
          _isLoadingMyLikes = false;
        });
      }

      debugPrint('👍 Loaded ${_myLikes.length} pending likes I sent');
    } catch (e) {
      debugPrint('❌ Load my likes error: $e');
      if (mounted) setState(() => _isLoadingMyLikes = false);
    }
  }

  /// 3️⃣ M'ONT AIMÉ (likes reçus, status = 'pending')
  Future<void> _loadTheirLikes() async {
    setState(() => _isLoadingTheirLikes = true);

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final matches = await _supabase
          .from('matches')
          .select('''
          id, created_at,
          profiles:user_id_1 (
            id, full_name, date_of_birth, city, bio, interests, last_active_at,
            photos:photos!photos_user_id_fkey(remote_path, type, status, display_order)
          )
        ''')
          .eq('user_id_2', currentUserId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _theirLikes = List<Map<String, dynamic>>.from(matches);
          _isLoadingTheirLikes = false;
        });
      }

      debugPrint('💖 Loaded ${_theirLikes.length} pending likes I received');
    } catch (e) {
      debugPrint('❌ Load their likes error: $e');
      if (mounted) setState(() => _isLoadingTheirLikes = false);
    }
  }

  /// 4️⃣ TAPS REÇUS
  Future<void> _loadTaps() async {
    setState(() => _isLoadingTaps = true);

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final taps = await _supabase
          .from('taps')
          .select('''
          id, tap_icon, created_at,
          profiles:sender_id (
            id, full_name, date_of_birth, city, bio, interests, last_active_at,
            photos:photos!photos_user_id_fkey(remote_path, type, status, display_order)
          )
        ''')
          .eq('receiver_id', currentUserId)
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _taps = List<Map<String, dynamic>>.from(taps);
          _isLoadingTaps = false;
        });
      }

      debugPrint('⚡ Loaded ${_taps.length} taps received');
    } catch (e) {
      debugPrint('❌ Load taps error: $e');
      if (mounted) setState(() => _isLoadingTaps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Interactions',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildStatChip(
                                Icons.favorite,
                                '${_matches.length}',
                                'Matches',
                                Colors.pink,
                              ),
                              const SizedBox(width: 8),
                              _buildStatChip(
                                Icons.thumb_up,
                                '${_myLikes.length}',
                                'J\'ai aimé',
                                Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              _buildStatChip(
                                Icons.favorite_border,
                                '${_theirLikes.length}',
                                'M\'ont aimé',
                                Colors.purple,
                              ),
                              const SizedBox(width: 8),
                              _buildStatChip(
                                Icons.flash_on,
                                '${_taps.length}',
                                'Taps',
                                Colors.orange,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              tabs: const [
                Tab(icon: Icon(Icons.favorite), text: 'Matches'),
                Tab(icon: Icon(Icons.thumb_up), text: 'J\'ai aimé'),
                Tab(icon: Icon(Icons.favorite_border), text: 'M\'ont aimé'),
                Tab(icon: Icon(Icons.flash_on), text: 'Taps'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMatchesTab(),
            _buildMyLikesTab(),
            _buildTheirLikesTab(),
            _buildTapsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 1️⃣ ONGLET MATCHES
  Widget _buildMatchesTab() {
    if (_isLoadingMatches) return _buildLoadingGrid();
    if (_matches.isEmpty) {
      return _buildEmptyState(
        icon: Icons.favorite_border,
        title: 'Aucun match encore',
        subtitle: 'Les matches mutuels apparaîtront ici',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMatches,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _matches.length,
        itemBuilder: (context, index) {
          final match = _matches[index];
          return _buildMatchCard(
            profile: match['profile'],
            isMatched: true,
            matchedAt: match['matched_at'],
          );
        },
      ),
    );
  }

  /// 2️⃣ ONGLET J'AI AIMÉ
  Widget _buildMyLikesTab() {
    if (_isLoadingMyLikes) return _buildLoadingGrid();
    if (_myLikes.isEmpty) {
      return _buildEmptyState(
        icon: Icons.thumb_up_outlined,
        title: 'Aucun like envoyé',
        subtitle: 'Aimez des profils pour commencer',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyLikes,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _myLikes.length,
        itemBuilder: (context, index) {
          final like = _myLikes[index];
          return _buildMatchCard(
            profile: like['profiles'],
            isPending: true,
            showCancelButton: true,
            onCancel: () => _cancelLike(like['id']),
          );
        },
      ),
    );
  }

  /// 3️⃣ ONGLET M'ONT AIMÉ
  Widget _buildTheirLikesTab() {
    if (_isLoadingTheirLikes) return _buildLoadingGrid();
    if (_theirLikes.isEmpty) {
      return _buildEmptyState(
        icon: Icons.favorite_border,
        title: 'Aucun like reçu',
        subtitle: 'Patience, ça arrive !',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTheirLikes,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _theirLikes.length,
        itemBuilder: (context, index) {
          final like = _theirLikes[index];
          return _buildMatchCard(
            profile: like['profiles'],
            isPending: true,
            showAcceptButton: true,
            onAccept: () => _acceptLike(like['id'], like['profiles']),
          );
        },
      ),
    );
  }

  /// 4️⃣ ONGLET TAPS
  Widget _buildTapsTab() {
    if (_isLoadingTaps) return _buildLoadingGrid();
    if (_taps.isEmpty) {
      return _buildEmptyState(
        icon: Icons.flash_on,
        title: 'Aucun tap reçu',
        subtitle: 'Les taps apparaîtront ici',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTaps,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _taps.length,
        itemBuilder: (context, index) {
          final tap = _taps[index];
          return _buildTapCard(tap);
        },
      ),
    );
  }

  /// 🎴 CARD MATCH/LIKE
  Widget _buildMatchCard({
    required Map<String, dynamic> profile,
    bool isMatched = false,
    bool isPending = false,
    String? matchedAt,
    bool showCancelButton = false,
    bool showAcceptButton = false,
    VoidCallback? onCancel,
    VoidCallback? onAccept,
  }) {
    final theme = Theme.of(context);
    final imageUrl = _photoUrlHelper.buildProfilePhotoUrl(profile);
    final name = profile['full_name'] ?? 'Utilisateur';
    final age = DateUtils.calculateAge(
      DateTime.tryParse(profile['date_of_birth'] ?? '') ?? DateTime.now(),
    );
    final city = profile['city'] ?? '';

    final isOnline =
        profile['last_active_at'] != null &&
            DateTime.now()
                .difference(DateTime.parse(profile['last_active_at']))
                .inMinutes <
                15;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileDetailScreen(
              profile: profile,
              isMatch: isMatched,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: imageUrl != null
                  ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: theme.colorScheme.surfaceVariant),
                errorWidget: (_, __, ___) => Container(
                  color: theme.colorScheme.errorContainer,
                  child: Icon(Icons.person, size: 48, color: theme.colorScheme.error),
                ),
              )
                  : Container(
                color: theme.colorScheme.surfaceVariant,
                child: Icon(Icons.person, size: 48, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name, $age',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (city.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 14),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            city,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            if (isMatched)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.pink.shade600, Colors.pink.shade400]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.pink.withOpacity(0.4), blurRadius: 8)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.favorite, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('MATCH', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

            if (isPending)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.hourglass_empty, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('EN ATTENTE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

            if (isOnline)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.white, size: 8),
                      SizedBox(width: 4),
                      Text('En ligne', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

            if (showCancelButton && onCancel != null)
              Positioned(
                bottom: 8,
                right: 8,
                child: IconButton(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.8)),
                  tooltip: 'Annuler',
                ),
              ),

            if (showAcceptButton && onAccept != null)
              Positioned(
                bottom: 8,
                right: 8,
                child: IconButton(
                  onPressed: onAccept,
                  icon: const Icon(Icons.favorite, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.pink.withOpacity(0.8)),
                  tooltip: 'Accepter',
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ⚡ CARD TAP
  Widget _buildTapCard(Map<String, dynamic> tap) {
    final theme = Theme.of(context);
    final profile = tap['profiles'];
    final tapIcon = tap['tap_icon'] as String;
    final createdAt = DateTime.parse(tap['created_at']);

    final imageUrl = _photoUrlHelper.buildProfilePhotoUrl(profile);
    final name = profile['full_name'] ?? 'Utilisateur';
    final age = DateUtils.calculateAge(
      DateTime.tryParse(profile['date_of_birth'] ?? '') ?? DateTime.now(),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: imageUrl != null ? CachedNetworkImageProvider(imageUrl) : null,
              child: imageUrl == null ? const Icon(Icons.person) : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(tapIcon, style: const TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
        title: Text('$name, $age', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          'Vous a envoyé un $tapIcon • ${DateUtils.timeAgo(createdAt)}',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
        ),
        trailing: FilledButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileDetailScreen(profile: profile)),
            );
          },
          child: const Text('Voir'),
        ),
      ),
    );
  }

  Future<void> _cancelLike(String matchId) async {
    try {
      await _supabase.from('matches').delete().eq('id', matchId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Like annulé'), backgroundColor: Colors.orange),
        );
        _loadMyLikes();
      }
    } catch (e) {
      debugPrint('❌ Cancel like: $e');
    }
  }

  Future<void> _acceptLike(String matchId, Map<String, dynamic> profile) async {
    try {
      await _supabase.from('matches').update({
        'status': 'matched',
        'matched_at': DateTime.now().toIso8601String(),
      }).eq('id', matchId);

      if (mounted) {
        _showMatchDialog(profile);
        _loadAllData();
      }
    } catch (e) {
      debugPrint('❌ Accept like: $e');
    }
  }

  void _showMatchDialog(Map<String, dynamic> profile) {
    final theme = Theme.of(context);
    final name = profile['full_name'] ?? 'Utilisateur';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            Text('C\'est un Match !', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Vous et $name vous êtes plu mutuellement', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                // TODO: Ouvrir conversation
              },
              icon: const Icon(Icons.chat),
              label: const Text('Envoyer un message'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Plus tard')),
          ],
        ),
      ),
    );
  }