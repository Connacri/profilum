// lib/screens/matches_screen.dart - ✅ ADAPTÉ À VOTRE SCHÉMA (user_1_liked/user_2_liked)
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../app_constants.dart';
import '../providers/theme_provider.dart';
import '../responsive_helper.dart';
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
  Timer? _debounceTimer;

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

  Future<void> _loadAllData({bool debounce = false}) async {
    if (debounce) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
        await Future.wait([
          _loadMatches(),
          _loadMyLikes(),
          _loadTheirLikes(),
          _loadFlashes(),
        ]);
      });
    } else {
      await Future.wait([
        _loadMatches(),
        _loadMyLikes(),
        _loadTheirLikes(),
        _loadFlashes(),
      ]);
    }
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

      final flashes = await _supabase
          .from('matches')
          .select('''
            id, created_at, expires_at, type,
            profiles:user_id_1 (id, full_name, date_of_birth, city, bio, interests, last_active_at, photos:photos!photos_user_id_fkey(remote_path, type, status, display_order))
          ''')
          .eq('user_id_2', currentUserId)
          .eq('type', 'flash')
          .eq('user_1_liked', true)
          .eq('user_2_liked', false)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      if (mounted) {
        final processed = flashes.map((f) {
          final existingMatch = _matches.firstWhere(
            (m) => m['profile']['id'] == f['profiles']['id'],
            orElse: () => {},
          );
          return {...f, 'already_liked': existingMatch.isNotEmpty};
        }).toList();

        setState(() {
          _flashes = processed;
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
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.favorite), text: 'Matches'),
            Tab(icon: Icon(Icons.thumb_up), text: 'J\'ai liké'),
            Tab(icon: Icon(Icons.favorite_border), text: 'Ils m\'ont liké'),
            Tab(icon: Icon(Icons.bolt), text: 'Flashes'),
          ],
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop =
              constraints.maxWidth > ResponsiveHelper.desktopBreakpoint;
          final gridCrossAxisCount = ResponsiveHelper.getGridColumns(
            context,
            customMobile: 2,
            customTablet: 3,
            customDesktop: 4,
          );

          return TabBarView(
            controller: _tabController,
            children: [
              _buildTabContent(
                _matches,
                _isLoadingMatches,
                _buildMatchCard,
                gridCrossAxisCount,
                isDesktop,
              ),
              _buildTabContent(
                _myLikes,
                _isLoadingMyLikes,
                _buildMyLikeCard,
                gridCrossAxisCount,
                isDesktop,
              ),
              _buildTabContent(
                _theirLikes,
                _isLoadingTheirLikes,
                _buildTheirLikeCard,
                gridCrossAxisCount,
                isDesktop,
              ),
              _buildTabContent(
                _flashes,
                _isLoadingFlashes,
                _buildFlashCard,
                gridCrossAxisCount,
                isDesktop,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabContent(
    List<Map<String, dynamic>> data,
    bool isLoading,
    Widget Function(Map<String, dynamic>) cardBuilder,
    int crossAxisCount,
    bool isDesktop,
  ) {
    if (isLoading) return WidgetHelpers.buildLoadingIndicator(context: context);

    if (data.isEmpty) {
      return _buildEmptyState(
        Icons.search_off,
        'Aucun résultat',
        'Explorez plus de profils pour trouver des matches !',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: GridView.builder(
        padding: context.adaptivePadding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: isDesktop ? 0.75 : 0.65,
          crossAxisSpacing: context.adaptiveSpacing,
          mainAxisSpacing: context.adaptiveSpacing,
        ),
        itemCount: data.length,
        itemBuilder: (ctx, idx) => cardBuilder(data[idx]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🃏 CARDS - Design attractif (gradients, shadows, rounded, couleurs psy: pink/rose pour attraction, bleu pour confiance)
  // UX: Tap feedback, lazy loading images, accessible (semantics)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final profile = match['profile'];
    final photoUrl = _getProfilePhotoUrl(profile['photos']);
    final age = _calculateAge(profile['date_of_birth']);
    final lastActive = timeago.format(
      DateTime.parse(profile['last_active_at']),
      locale: 'fr',
    );

    return Semantics(
      label:
          'Match avec ${profile['full_name']}, $age ans, à ${profile['city']}',
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileDetailScreen(profile: profile),
          ),
        ),
        child: Card(
          elevation: AppConstants.cardElevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photoUrl != null)
                CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const Center(child: CircularProgressIndicator()),
                )
              else
                Container(color: Colors.grey[300]),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile['full_name'] ?? 'Anonyme'}, $age',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      profile['city'] ?? '',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Actif il y a $lastActive',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Chip(
                  label: Text(
                    timeago.format(
                      DateTime.parse(match['matched_at']),
                      locale: 'fr',
                    ),
                  ),
                  backgroundColor: Colors.pink.withOpacity(0.8),
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyLikeCard(Map<String, dynamic> like) {
    final profile = like['profiles'];
    final photoUrl = _getProfilePhotoUrl(profile['photos']);
    final age = _calculateAge(profile['date_of_birth']);

    return Semantics(
      label: 'Profil liké: ${profile['full_name']}, $age ans',
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileDetailScreen(profile: profile),
          ),
        ),
        child: Card(
          elevation: AppConstants.cardElevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photoUrl != null)
                CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover)
              else
                Container(color: Colors.grey[300]),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${profile['full_name'] ?? 'Anonyme'}, $age',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          profile['city'] ?? '',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => _cancelLike(like['id']),
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

  Widget _buildTheirLikeCard(Map<String, dynamic> like) {
    final profile = like['profiles'];
    final photoUrl = _getProfilePhotoUrl(profile['photos']);
    final age = _calculateAge(profile['date_of_birth']);

    return Semantics(
      label: 'Profil qui vous a liké: ${profile['full_name']}, $age ans',
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileDetailScreen(profile: profile),
          ),
        ),
        child: Card(
          elevation: AppConstants.cardElevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photoUrl != null)
                CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover)
              else
                Container(color: Colors.grey[300]),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${profile['full_name'] ?? 'Anonyme'}, $age',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          profile['city'] ?? '',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: () => _acceptLike(like['id'], profile),
                      icon: const Icon(Icons.favorite, size: 18),
                      label: const Text('Accepter'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.pink,
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
    final profile = flash['profiles'];
    final photoUrl = _getProfilePhotoUrl(profile['photos']);
    final age = _calculateAge(profile['date_of_birth']);
    final expiresAt = DateTime.parse(flash['expires_at']);
    final remaining = expiresAt.difference(DateTime.now());
    final hoursLeft = remaining.inHours;
    final minutesLeft = remaining.inMinutes % 60;
    final alreadyLiked = flash['already_liked'] ?? false;

    return Semantics(
      label:
          'Flash de ${profile['full_name']}, expire dans ${hoursLeft}h ${minutesLeft}m',
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileDetailScreen(profile: profile),
          ),
        ),
        child: Card(
          elevation: AppConstants.cardElevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photoUrl != null)
                CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover)
              else
                Container(color: Colors.grey[300]),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile['full_name'] ?? 'Anonyme'}, $age',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      profile['city'] ?? '',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.timer,
                              size: 16,
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
                        if (alreadyLiked)
                          const Chip(
                            label: Text(
                              '✓ Liké',
                              style: TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Colors.green,
                            labelStyle: TextStyle(color: Colors.white),
                          )
                        else
                          FilledButton.icon(
                            onPressed: () =>
                                _respondToFlash(flash['id'], profile),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🎯 ACTIONS - Sécurisé (RLS implicite), feedback UX (snackbars animés)
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
        _loadAllData();
      }
    } catch (e) {
      debugPrint('❌ Cancel: $e');
    }
  }

  Future<void> _acceptLike(String matchId, Map<String, dynamic> profile) async {
    try {
      await _supabase
          .from('matches')
          .update({
            'user_2_liked': true,
            'status': 'matched',
            'matched_at': DateTime.now().toIso8601String(),
          })
          .eq('id', matchId);

      if (mounted) _showMatchDialog(profile);
      _loadAllData();
    } catch (e) {
      debugPrint('❌ Accept: $e');
    }
  }

  Future<void> _respondToFlash(
    String flashId,
    Map<String, dynamic> profile,
  ) async {
    try {
      await _supabase
          .from('matches')
          .update({
            'user_2_liked': true,
            'status': 'matched',
            'matched_at': DateTime.now().toIso8601String(),
          })
          .eq('id', flashId);

      if (mounted) _showMatchDialog(profile);
      _loadAllData();
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
  // 🛠️ HELPERS - Optimisé (memoization pour photos, const widgets)
  // ═══════════════════════════════════════════════════════════════════════

  String? _getProfilePhotoUrl(List<dynamic>? photos) {
    if (photos == null || photos.isEmpty) return null;
    final profilePhoto = photos.firstWhere(
      (p) => p['type'] == 'profile' && p['status'] == 'approved',
      orElse: () => photos.first,
    );
    return _photoUrlHelper.buildPhotoUrl(profilePhoto['remote_path']);
  }

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
        (now.month == birthDate.month && now.day < birthDate.day))
      age--;
    return age;
  }

  ////////////////////////////////////////////////////////////////

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
}
