import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';
import '../providers/profile_completion_provider.dart';
import '../responsive_helper.dart';
import '../services/fix_photo_url_builder.dart';
import '../services/profile_image_service.dart';

import 'matches_screen.dart';
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
    final showBanner = user != null && !user.profileCompleted && !_bannerDismissed;

    return Scaffold(
      appBar: _currentIndex == 0 ? null : _buildAppBar(context),
      body: Column(
        children: [
          if (showBanner) _buildDynamicCompletionBanner(context),
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
            icon: Icon(Icons.handshake),
            selectedIcon: Icon(Icons.handshake_outlined),
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

  /// 🎨 AppBar avec avatar utilisateur
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final profileImageService = context.read<ProfileImageService>();

    return AppBar(
      automaticallyImplyLeading: false,
      leading: user != null
          ? Padding(
        padding: const EdgeInsets.all(8.0),
        child: FutureBuilder<String?>(
          future: profileImageService.getCurrentUserProfileImage(),
          builder: (context, snapshot) {
            final imageUrl = snapshot.data;

            return GestureDetector(
              onTap: () {
                setState(() => _currentIndex = 3); // Navigate to profile
              },
              child: Stack(
                children: [
                  ProfileImageService.buildProfileImageWidget(
                    imageUrl,
                    radius: 20,
                    userName: user.fullName ?? '',
                  ),
                  // Badge online
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      )
          : null,
      title: Text(_getTitle()),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            // TODO: Navigation vers notifications
          },
        ),
      ],
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

  Widget _buildDynamicCompletionBanner(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<ProfileCompletionProvider>(
      builder: (context, completionProvider, _) {
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
                        'Profil incomplet ($completion%)',
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
        return const MatchesScreen();
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
// DISCOVER PAGE - OPTIMISÉE
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
  int _currentIndex = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  List<Map<String, dynamic>> _profiles = [];
  Set<String> _matchedUserIds = {};

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  int _page = 0;
  final int _pageSize = 20;
  late final PhotoUrlHelper _photoUrlHelper;
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
    _photoUrlHelper = PhotoUrlHelper(_supabase);
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

  Future<void> _loadProfiles() async {
    setState(() {
      _isLoading = true;
      _page = 0;
      _profiles.clear();
    });

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
          .neq('completion_percentage', 0)
          .not('role', 'in', '("admin","moderator")')
          .order('last_active_at', ascending: false)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1);

      if (!mounted) return;

      setState(() {
        _profiles = List<Map<String, dynamic>>.from(data);
        _hasMore = data.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Load profiles error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildSliverAppBar(theme, constraints),

              if (_isLoading)
                _buildShimmerGrid(theme, constraints)
              else if (_profiles.isEmpty)
                SliverFillRemaining(child: _buildEmptyState(theme))
              else
                _buildProfilesGrid(theme, constraints),

              if (_isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme, BoxConstraints constraints) {
    final isMobile = constraints.maxWidth < ResponsiveHelper.mobileBreakpoint;
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final profileImageService = context.read<ProfileImageService>();

    return SliverAppBar(
      expandedHeight: isMobile ? 160 : 200,
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
              padding: EdgeInsets.all(isMobile ? 8 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      user != null
                          ? Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: FutureBuilder<String?>(
                          future: profileImageService.getCurrentUserProfileImage(),
                          builder: (context, snapshot) {
                            final imageUrl = snapshot.data;

                            return GestureDetector(
                              onTap: () {
                                setState(() => _currentIndex = 3); // Navigate to profile
                              },
                              child: Stack(
                                children: [
                                  ProfileImageService.buildProfileImageWidget(
                                    imageUrl,
                                    radius: 20,
                                    userName: user.fullName ?? '',
                                  ),
                                  // Badge online
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: theme.scaffoldBackgroundColor,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                          : SizedBox.shrink(),
                      Icon(
                        Icons.explore,
                        color: Colors.white,
                        size: isMobile ? 28 : 36,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Découvrir',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 28 : 36,
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

                  // Padding(
                  //   padding: const EdgeInsets.all(8.0),
                  //   child: Text(
                  //     '${_profiles.length} profils près de toi',
                  //     style: TextStyle(
                  //       color: Colors.white.withOpacity(0.9),
                  //       fontSize: isMobile ? 14 : 16,
                  //     ),
                  //   ),
                  // ),
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
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 32,
            vertical: 12,
          ),
          child: Column(
            children: [
              _buildFilterChips(theme),
            ],
          ),
        ),
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

  Widget _buildShimmerGrid(ThemeData theme, BoxConstraints constraints) {
    final columns = ResponsiveHelper.getGridColumns(
      context,
      customMobile: 2,
      customTablet: 3,
      customDesktop: 6,
    );
    final spacing = ResponsiveHelper.getAdaptiveSpacing(context);
    final aspectRatio = ResponsiveHelper.getCardAspectRatio(context);

    return SliverPadding(
      padding: ResponsiveHelper.getAdaptivePadding(context),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: aspectRatio,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) => _buildShimmerCard(theme),
          childCount: 12,
        ),
      ),
    );
  }

  Widget _buildProfilesGrid(ThemeData theme, BoxConstraints constraints) {
    final columns = ResponsiveHelper.getGridColumns(
      context,
      customMobile: 2,
      customTablet: 3,
      customDesktop: 6,
    );
    final spacing = ResponsiveHelper.getAdaptiveSpacing(context);
    final aspectRatio = ResponsiveHelper.getCardAspectRatio(context);

    return SliverPadding(
      padding: ResponsiveHelper.getAdaptivePadding(context),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: aspectRatio,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final profile = _profiles[index];
            final isMatch = _matchedUserIds.contains(profile['id']);

            return FadeTransition(
              opacity: _fadeAnimation,
              child: _buildEnhancedProfileCard(context, profile, isMatch, theme),
            );
          },
          childCount: _profiles.length,
        ),
      ),
    );
  }

  /// 🎨 CARTE PROFIL AMÉLIORÉE
  Widget _buildEnhancedProfileCard(
      BuildContext context,
      Map<String, dynamic> profile,
      bool isMatch,
      ThemeData theme,
      ) {
    final imageUrl = _photoUrlHelper.buildProfilePhotoUrl(profile);
    final name = profile['full_name'] ?? 'Utilisateur';
    final city = profile['city'] ?? '';
    final age = _calculateAge(profile['date_of_birth']);
    final interests = (profile['interests'] as List?)?.take(3).toList() ?? [];

    final isOnline = profile['last_active_at'] != null &&
        DateTime.now()
            .difference(DateTime.parse(profile['last_active_at']))
            .inMinutes <
            15;

    return GestureDetector(
      onTap: () => _openProfile(context, profile),
      child: Hero(
        tag: 'profile_${profile['id']}',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image avec effet glassmorphism
                if (imageUrl != null)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: theme.colorScheme.surfaceVariant,
                    ),
                    errorWidget: (_, __, ___) => _buildPlaceholderAvatar(theme),
                  )
                else
                  _buildPlaceholderAvatar(theme),

                // Gradient overlay moderne
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.85),
                        ],
                        stops: const [0.4, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),

                // Badges en haut
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isOnline) _buildOnlineBadge(),
                      const Spacer(),
                      if (isMatch) _buildMatchBadge(),
                    ],
                  ),
                ),

                // Informations du profil
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Nom et âge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${name}, $age',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black38,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        if (city.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Colors.red.shade400,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  city.toString(),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.95),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Intérêts
                        if (interests.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: interests.map((interest) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  interest.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.circle, color: Colors.white, size: 8),
          SizedBox(width: 6),
          Text(
            'En ligne',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchBadge() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.pink.shade400, Colors.pink.shade600],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.favorite,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  Widget _buildPlaceholderAvatar(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceVariant,
      child: Icon(
        Icons.person,
        size: 64,
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
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
          borderRadius: BorderRadius.circular(20),
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