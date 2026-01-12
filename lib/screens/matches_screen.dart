// lib/screens/matches_screen.dart - ✅ ADAPTÉ À VOTRE SCHÉMA (user_1_liked/user_2_liked)
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../services/fix_photo_url_builder.dart';
import 'profile_detail_screen.dart';

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

  RealtimeChannel? _matchesChannel;
  Timer? _expirationTimer;

  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _myLikes = [];
  List<Map<String, dynamic>> _theirLikes = [];
  List<Map<String, dynamic>> _flashes = [];

  bool _isLoadingMatches = true;
  bool _isLoadingMyLikes = true;
  bool _isLoadingTheirLikes = true;
  bool _isLoadingFlashes = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _photoUrlHelper = PhotoUrlHelper(_supabase);

    timeago.setLocaleMessages('fr', timeago.FrMessages());

    _loadAllData();
    _setupRealtimeListeners();
    _startExpirationTimer();
  }

  @override
  void dispose() {
    _matchesChannel?.unsubscribe();
    _expirationTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🔥 REALTIME - Syntaxe v2 (sans OR filter car non supporté)
  // ═══════════════════════════════════════════════════════════════════════
  void _setupRealtimeListeners() {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    // ⚠️ LIMITATION: Realtime ne supporte qu'UN seul filtre
    // Solution: Écouter toute la table et filtrer côté client
    _matchesChannel = _supabase
        .channel('matches_realtime_$currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'matches',
          callback: (payload) {
            // ✅ Filtrer côté client
            final record = payload.newRecord;
            final user1 = record['user_id_1'];
            final user2 = record['user_id_2'];

            if (user1 == currentUserId || user2 == currentUserId) {
              debugPrint('🔔 Match change: ${payload.eventType}');
              _loadAllData();
            }
          },
        )
        .subscribe();
  }

  void _startExpirationTimer() {
    _expirationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _loadFlashes();
    });
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadMatches(),
      _loadMyLikes(),
      _loadTheirLikes(),
      _loadFlashes(),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 📊 DATA LOADING - ADAPTÉ À VOTRE SCHÉMA
  // ═══════════════════════════════════════════════════════════════════════

  /// 💘 ONGLET 1: Matches (user_1_liked=true AND user_2_liked=true)
  Future<void> _loadMatches() async {
    setState(() => _isLoadingMatches = true);
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // ✅ Chercher où les 2 users ont liké
      final matches = await _supabase
          .from('matches')
          .select('''
            id, user_id_1, user_id_2, matched_at, type, created_at,
            user_1_liked, user_2_liked,
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
          .eq('user_1_liked', true)
          .eq('user_2_liked', true)
          .order('matched_at', ascending: false);

      if (mounted) {
        final processed = matches.map((m) {
          final isUser1 = m['user_id_1'] == currentUserId;
          return {
            'id': m['id'],
            'matched_at': m['matched_at'],
            'type': m['type'],
            'profile': isUser1 ? m['profiles_2'] : m['profiles_1'],
          };
        }).toList();

        setState(() {
          _matches = processed;
          _isLoadingMatches = false;
        });
        debugPrint('💘 Matches: ${_matches.length}');
      }
    } catch (e) {
      debugPrint('❌ Load matches: $e');
      if (mounted) setState(() => _isLoadingMatches = false);
    }
  }

  /// 👍 ONGLET 2: J'ai liké (je suis user_id_1, user_1_liked=true, user_2_liked=false)
  Future<void> _loadMyLikes() async {
    setState(() => _isLoadingMyLikes = true);
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final likes = await _supabase
          .from('matches')
          .select('''
            id, created_at, type,
            profiles:user_id_2 (
              id, full_name, date_of_birth, city, bio, interests, last_active_at,
              photos:photos!photos_user_id_fkey(remote_path, type, status, display_order)
            )
          ''')
          .eq('user_id_1', currentUserId)
          .eq('type', 'like')
          .eq('user_1_liked', true)
          .eq('user_2_liked', false)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _myLikes = List<Map<String, dynamic>>.from(likes);
          _isLoadingMyLikes = false;
        });
        debugPrint('👍 My likes: ${_myLikes.length}');
      }
    } catch (e) {
      debugPrint('❌ Load my likes: $e');
      if (mounted) setState(() => _isLoadingMyLikes = false);
    }
  }

  /// 💖 ONGLET 3: Ils m'ont liké (je suis user_id_2, user_2_liked=false, user_1_liked=true)
  Future<void> _loadTheirLikes() async {
    setState(() => _isLoadingTheirLikes = true);
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final likes = await _supabase
          .from('matches')
          .select('''
            id, created_at, type,
            profiles:user_id_1 (
              id, full_name, date_of_birth, city, bio, interests, last_active_at,
              photos:photos!photos_user_id_fkey(remote_path, type, status, display_order)
            )
          ''')
          .eq('user_id_2', currentUserId)
          .eq('type', 'like')
          .eq('user_1_liked', true)
          .eq('user_2_liked', false)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _theirLikes = List<Map<String, dynamic>>.from(likes);
          _isLoadingTheirLikes = false;
        });
        debugPrint('💖 Their likes: ${_theirLikes.length}');
      }
    } catch (e) {
      debugPrint('❌ Load their likes: $e');
      if (mounted) setState(() => _isLoadingTheirLikes = false);
    }
  }

  /// ⚡ ONGLET 4: Flash reçus (type='flash', non expirés)
  Future<void> _loadFlashes() async {
    setState(() => _isLoadingFlashes = true);
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final now = DateTime.now().toIso8601String();

      final flashes = await _supabase
          .from('matches')
          .select('''
            id, created_at, expires_at, user_id_1, user_id_2,
            user_1_liked, user_2_liked,
            profiles:user_id_1 (
              id, full_name, date_of_birth, city, bio, interests, last_active_at,
              photos:photos!photos_user_id_fkey(remote_path, type, status, display_order)
            )
          ''')
          .eq('user_id_2', currentUserId)
          .eq('type', 'flash')
          .gt('expires_at', now)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _flashes = List<Map<String, dynamic>>.from(flashes);
          _isLoadingFlashes = false;
        });
        debugPrint('⚡ Flashes: ${_flashes.length}');
      }
    } catch (e) {
      debugPrint('❌ Load flashes: $e');
      if (mounted) setState(() => _isLoadingFlashes = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🎨 UI
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
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
                                '${_flashes.length}',
                                'Flash',
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
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(icon: Icon(Icons.favorite), text: 'Matches'),
                Tab(icon: Icon(Icons.thumb_up), text: 'J\'ai aimé'),
                Tab(icon: Icon(Icons.favorite_border), text: 'M\'ont aimé'),
                Tab(icon: Icon(Icons.flash_on), text: 'Flash'),
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
            _buildFlashesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(
    IconData icon,
    String count,
    String label,
    Color color,
  ) {
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

  // ═══════════════════════════════════════════════════════════════════════
  // 📑 ONGLETS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildMatchesTab() {
    if (_isLoadingMatches) return _buildLoadingGrid();
    if (_matches.isEmpty) {
      return _buildEmptyState(
        Icons.favorite_border,
        'Aucun match',
        'Les matches mutuels apparaîtront ici',
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
            type: match['type'],
          );
        },
      ),
    );
  }

  Widget _buildMyLikesTab() {
    if (_isLoadingMyLikes) return _buildLoadingGrid();
    if (_myLikes.isEmpty) {
      return _buildEmptyState(
        Icons.thumb_up_outlined,
        'Aucun like envoyé',
        'Aimez des profils pour commencer',
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

  Widget _buildTheirLikesTab() {
    if (_isLoadingTheirLikes) return _buildLoadingGrid();
    if (_theirLikes.isEmpty) {
      return _buildEmptyState(
        Icons.favorite_border,
        'Aucun like reçu',
        'Patience, ça arrive !',
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

  Widget _buildFlashesTab() {
    if (_isLoadingFlashes) return _buildLoadingGrid();
    if (_flashes.isEmpty) {
      return _buildEmptyState(
        Icons.flash_on,
        'Aucun flash reçu',
        'Les flash apparaîtront ici (24h)',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFlashes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _flashes.length,
        itemBuilder: (context, index) => _buildFlashCard(_flashes[index]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🎴 CARDS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildMatchCard({
    required Map<String, dynamic> profile,
    bool isMatched = false,
    bool isPending = false,
    String? matchedAt,
    String? type,
    bool showCancelButton = false,
    bool showAcceptButton = false,
    VoidCallback? onCancel,
    VoidCallback? onAccept,
  }) {
    final theme = Theme.of(context);
    final photoUrl = _photoUrlHelper.buildProfilePhotoUrl(profile);
    final name = profile['full_name'] ?? 'Utilisateur';
    final age = _calculateAge(profile['date_of_birth']);
    final city = profile['city'] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProfileDetailScreen(profile: profile, isMatch: isMatched),
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
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photoUrl != null)
                CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: theme.colorScheme.surfaceVariant,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: theme.colorScheme.surfaceVariant,
                    child: const Icon(Icons.person, size: 50),
                  ),
                )
              else
                Container(
                  color: theme.colorScheme.surfaceVariant,
                  child: const Icon(Icons.person, size: 50),
                ),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$name, $age',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (city.isNotEmpty)
                      Text(
                        city,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    if (isMatched && matchedAt != null)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: type == 'flash'
                              ? Colors.orange.withOpacity(0.9)
                              : Colors.pink.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              type == 'flash' ? Icons.flash_on : Icons.favorite,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeago.format(
                                DateTime.parse(matchedAt),
                                locale: 'fr',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              if (showCancelButton || showAcceptButton)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      if (showCancelButton)
                        IconButton(
                          onPressed: onCancel,
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.9),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      if (showAcceptButton)
                        IconButton(
                          onPressed: onAccept,
                          icon: const Icon(Icons.favorite),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.pink.withOpacity(0.9),
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlashCard(Map<String, dynamic> flash) {
    final theme = Theme.of(context);
    final profile = flash['profiles'];
    final photoUrl = _photoUrlHelper.buildProfilePhotoUrl(profile);
    final name = profile['full_name'] ?? 'Utilisateur';
    final age = _calculateAge(profile['date_of_birth']);
    final city = profile['city'] ?? '';

    final expiresAt = DateTime.parse(flash['expires_at']);
    final remaining = expiresAt.difference(DateTime.now());
    final hoursLeft = remaining.inHours;
    final minutesLeft = remaining.inMinutes % 60;

    // ✅ Vérifier si déjà liké
    final alreadyLiked = flash['user_2_liked'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileDetailScreen(profile: profile),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: theme.colorScheme.surfaceVariant,
                        child: const Icon(Icons.person),
                      ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.flash_on,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Flash',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$name, $age',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (city.isNotEmpty)
                      Text(
                        city,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: remaining.inHours < 3
                            ? Colors.red.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer,
                            size: 14,
                            color: remaining.inHours < 3
                                ? Colors.red
                                : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${hoursLeft}h ${minutesLeft}m',
                            style: TextStyle(
                              fontSize: 12,
                              color: remaining.inHours < 3
                                  ? Colors.red
                                  : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (alreadyLiked)
                const Chip(
                  label: Text('✓ Liké', style: TextStyle(fontSize: 12)),
                  backgroundColor: Colors.green,
                  labelStyle: TextStyle(color: Colors.white),
                )
              else
                FilledButton.icon(
                  onPressed: () => _respondToFlash(flash['id'], profile),
                  icon: const Icon(Icons.favorite, size: 18),
                  label: const Text('Liker'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.pink,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🎯 ACTIONS - ADAPTÉ À user_1_liked/user_2_liked
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _cancelLike(String matchId) async {
    try {
      await _supabase.from('matches').delete().eq('id', matchId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Like annulé'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Cancel: $e');
    }
  }

  Future<void> _acceptLike(String matchId, Map<String, dynamic> profile) async {
    try {
      // ✅ Mettre user_2_liked=true + status=matched
      await _supabase
          .from('matches')
          .update({
            'user_2_liked': true,
            'status': 'matched',
            'matched_at': DateTime.now().toIso8601String(),
          })
          .eq('id', matchId);

      if (mounted) _showMatchDialog(profile);
    } catch (e) {
      debugPrint('❌ Accept: $e');
    }
  }

  Future<void> _respondToFlash(
    String flashId,
    Map<String, dynamic> profile,
  ) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // ✅ Option 1: Liker le flash existant (user_2_liked=true)
      await _supabase
          .from('matches')
          .update({
            'user_2_liked': true,
            'status': 'matched',
            'matched_at': DateTime.now().toIso8601String(),
          })
          .eq('id', flashId);

      if (mounted) _showMatchDialog(profile);
    } catch (e) {
      debugPrint('❌ Respond flash: $e');
    }
  }

  void _showMatchDialog(Map<String, dynamic> profile) {
    final name = profile['full_name'] ?? 'Utilisateur';

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
            const SizedBox(height: 8),
            Text(
              'Vous et $name vous aimez mutuellement',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.chat),
              label: const Text('Envoyer un message'),
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

  // ═══════════════════════════════════════════════════════════════════════
  // 🛠️ HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildLoadingGrid() => GridView.builder(
    padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: 0.7,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    ),
    itemCount: 6,
    itemBuilder: (_, __) => Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );

  Widget _buildEmptyState(IconData icon, String title, String subtitle) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );

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
