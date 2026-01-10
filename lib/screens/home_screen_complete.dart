// lib/screens/home_screen_complete.dart - BANNER DYNAMIQUE

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';
import '../providers/profile_completion_provider.dart'; // ✅ AJOUTÉ
import '../services/fix_photo_url_builder.dart';
import 'profile_completion_screen.dart';
import 'profile_detail_screen.dart';
import 'profile_page_carousel.dart';

class HomeScreen extends StatefulWidget {
  final String? gender;

  const HomeScreen({super.key, this.gender});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _bannerDismissed = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    final showBanner =
        user != null && !user.profileCompleted && !_bannerDismissed;

    return Scaffold(
      appBar: _currentIndex == 0
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              title: Text(_getTitle()),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {
                    // TODO: Navigation vers notifications
                  },
                ),
              ],
            ),
      body: Column(
        children: [
          // ✅ FIX : Banner dynamique qui écoute ProfileCompletionProvider
          if (showBanner) _buildDynamicCompletionBanner(context),

          // Contenu principal
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Découvrir',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Matches',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 1:
        return 'Mes Matches';
      case 2:
        return 'Messages';
      case 3:
        return 'Mon Profil';
      default:
        return 'Profilum';
    }
  }

  /// ✅ FIX : Banner DYNAMIQUE qui écoute le ProfileCompletionProvider
  Widget _buildDynamicCompletionBanner(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<ProfileCompletionProvider>(
      builder: (context, completionProvider, _) {
        // ✅ Utiliser le pourcentage du provider (temps réel)
        final completion = completionProvider.completionPercentage;

        return Material(
          elevation: 2,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.secondaryContainer,
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_circle,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profil incomplet ($completion%)', // ✅ Temps réel
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Complétez votre profil pour maximiser vos matchs !',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileCompletionScreen(),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Compléter'),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() => _bannerDismissed = true);
                  },
                  tooltip: 'Fermer',
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return DiscoverScreen(userGender: widget.gender);
      case 1:
        return const _MatchesPage();
      case 2:
        return const _MessagesPage();
      case 3:
        return const ProfilePage();
      default:
        return const SizedBox.shrink();
    }
  }
}

// ============================================
// DISCOVER PAGE (inchangé)
// ============================================

class DiscoverScreen extends StatefulWidget {
  final String? userGender;

  const DiscoverScreen({super.key, this.userGender});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _scrollController = ScrollController();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  List<Map<String, dynamic>> _profiles = [];
  Set<String> _matchedUserIds = {};

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  int _page = 0;
  final int _pageSize = 20;
  late final PhotoUrlHelper _photoUrlHelper; // ✅ AJOUTER
  String _filter = 'nearby';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _photoUrlHelper = PhotoUrlHelper(_supabase); // ✅ AJOUTE
    _scrollController.addListener(_onScroll);
    _loadProfiles();
    _loadMatches();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  // lib/screens/home_screen_complete.dart - ✅ FIX REQUÊTE SUPABASE

  // ════════════════════════════════════════════════════════════════
  // 📸 REMPLACER LA MÉTHODE _loadProfiles() COMPLÈTE
  // ════════════════════════════════════════════════════════════════

  Future<void> _loadProfiles() async {
    setState(() {
      _isLoading = true;
      _page = 0;
      _profiles.clear();
    });

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      debugPrint('════════════════════════════════════════');
      debugPrint('🔍 LOADING PROFILES');
      debugPrint('   Current User: $currentUserId');
      debugPrint('════════════════════════════════════════');

      // ✅ FIX : Requête simplifiée qui retourne les photos comme ARRAY
      final data = await _supabase
          .from('profiles')
          .select('''
          id,
          full_name,
          date_of_birth,
          city,
          bio,
          gender,
          interests,
          role,
          profile_completed,
          last_active_at,
          photos:photos!photos_user_id_fkey(
            remote_path,
            type,
            status,
            display_order
          )
        ''')
          .neq('id', currentUserId)
          .not('role', 'in', '("admin","moderator")')
          .order('last_active_at', ascending: false)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1);

      if (!mounted) return;

      // ✅ Debug : Vérifier la structure retournée
      debugPrint('📦 Received ${data.length} profiles');
      if (data.isNotEmpty) {
        final first = data.first;
        debugPrint('   Sample profile:');
        debugPrint('   - Name: ${first['full_name']}');
        debugPrint('   - Photos type: ${first['photos'].runtimeType}');
        debugPrint(
          '   - Photos count: ${(first['photos'] as List?)?.length ?? 0}',
        );

        if (first['photos'] is List && (first['photos'] as List).isNotEmpty) {
          final firstPhoto = (first['photos'] as List).first;
          debugPrint('   - First photo keys: ${firstPhoto.keys}');
          debugPrint('   - First photo path: ${firstPhoto['remote_path']}');
          debugPrint('   - First photo type: ${firstPhoto['type']}');
          debugPrint('   - First photo status: ${firstPhoto['status']}');
        }
      }

      setState(() {
        _profiles = List<Map<String, dynamic>>.from(data);
        _hasMore = data.length == _pageSize;
        _isLoading = false;
      });

      debugPrint('✅ Profiles loaded successfully');
      debugPrint('════════════════════════════════════════');
    } catch (e, stack) {
      debugPrint('❌ Load profiles error: $e');
      debugPrint('Stack: $stack');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════════════════════════════
  // 📸 REMPLACER AUSSI _loadMore() (même logique)
  // ════════════════════════════════════════════════════════════════

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    _page++;

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final data = await _supabase
          .from('profiles')
          .select('''
          id,
          full_name,
          date_of_birth,
          city,
          bio,
          gender,
          interests,
          profile_completed,
          last_active_at,
          photos:photos!photos_user_id_fkey(
            remote_path,
            type,
            status,
            display_order
          )
        ''')
          .neq('id', currentUserId)
          .not('role', 'in', '("admin","moderator")')
          .order('last_active_at', ascending: false)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1);

      if (mounted) {
        setState(() {
          _profiles.addAll(List<Map<String, dynamic>>.from(data));
          _hasMore = data.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Load more error: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadMatches() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final matches = await _supabase
          .from('matches')
          .select('user_id_1, user_id_2')
          .or('user_id_1.eq.$currentUserId,user_id_2.eq.$currentUserId')
          .eq('status', 'matched');

      final matchedIds = <String>{};
      for (final match in matches) {
        if (match['user_id_1'] == currentUserId) {
          matchedIds.add(match['user_id_2']);
        } else {
          matchedIds.add(match['user_id_1']);
        }
      }

      if (mounted) {
        setState(() => _matchedUserIds = matchedIds);
      }
    } catch (e) {
      debugPrint('❌ Load matches error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
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
                            Icon(Icons.explore, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              'Découvrir',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (_matchedUserIds.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.pink,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.favorite,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_matchedUserIds.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${_profiles.length} profils près de toi',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                color: theme.scaffoldBackgroundColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: _buildFilterChips(theme),
              ),
            ),
          ),

          if (_isLoading)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildShimmerCard(theme),
                  childCount: 6,
                ),
              ),
            )
          else if (_profiles.isEmpty)
            SliverFillRemaining(child: _buildEmptyState(theme))
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final profile = _profiles[index];
                  final isMatch = _matchedUserIds.contains(profile['id']);

                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildProfileCard(context, profile, isMatch, theme),
                  );
                }, childCount: _profiles.length),
              ),
            ),

          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('nearby', '📍 Près de toi', theme),
          const SizedBox(width: 8),
          _buildFilterChip('recent', '🆕 Récents', theme),
          const SizedBox(width: 8),
          _buildFilterChip('popular', '🔥 Populaires', theme),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, ThemeData theme) {
    final isSelected = _filter == value;

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        setState(() => _filter = value);
        _loadProfiles();
      },
      backgroundColor: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceVariant,
      selectedColor: theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    Map<String, dynamic> profile,
    bool isMatch,
    ThemeData theme,
  ) {
    // ✅ UTILISER LE HELPER pour obtenir l'URL
    final imageUrl = _photoUrlHelper.buildProfilePhotoUrl(profile);

    final name = profile['full_name'] ?? 'Utilisateur';
    final city = profile['city'] ?? '';
    final age = _calculateAge(profile['date_of_birth']);

    final isOnline =
        profile['last_active_at'] != null &&
        DateTime.now()
                .difference(DateTime.parse(profile['last_active_at']))
                .inMinutes <
            15;

    // ✅ Debug pour vérifier
    debugPrint('🖼️ Profile card for: $name');
    debugPrint('   URL: ${imageUrl ?? "NO IMAGE"}');

    return GestureDetector(
      onTap: () => _openProfile(context, profile),
      child: Hero(
        tag: 'profile_${profile['id']}',
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
                        imageUrl: imageUrl, // ✅ URL complète
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: theme.colorScheme.surfaceVariant),
                        errorWidget: (context, url, error) {
                          // ✅ Debug détaillé en cas d'erreur
                          debugPrint('❌ Image load failed');
                          debugPrint('   URL: $url');
                          debugPrint('   Error: $error');

                          return Container(
                            color: theme.colorScheme.errorContainer,
                            child: Icon(
                              Icons.person,
                              size: 48,
                              color: theme.colorScheme.error,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: theme.colorScheme.surfaceVariant,
                        child: Icon(
                          Icons.person,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
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
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$name, $age',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMatch)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.pink,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                      ],
                    ),
                    if (city.isNotEmpty)
                      Text(
                        '📍 $city',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              if (isOnline)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 8),
                        SizedBox(width: 4),
                        Text(
                          'En ligne',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
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
      ),
    );
  }

  Widget _buildShimmerCard(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceVariant,
      highlightColor: theme.colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun profil trouvé',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez de changer vos filtres',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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

  void _openProfile(BuildContext context, Map<String, dynamic> profile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => ProfileDetailScreen(profile: profile),
      ),
    );
  }
}

class _MatchesPage extends StatelessWidget {
  const _MatchesPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite, size: 80, color: Colors.pink),
            const SizedBox(height: 16),
            Text(
              'Matches',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '💕 Tes matchs apparaîtront ici',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagesPage extends StatelessWidget {
  const _MessagesPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Messages',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('💬 Messagerie P2P', style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
