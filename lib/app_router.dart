// lib/core/routing/app_router.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'admin_dashboard.dart';
import 'auth/auth_screen.dart';
import 'profile_completion_screen.dart';

class AppRouter extends RouterDelegate
    with ChangeNotifier, PopNavigatorRouterDelegateMixin {
  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final AuthProvider _authProvider;

  AppRouter(this._authProvider) {
    _authProvider.addListener(notifyListeners);
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: _buildPages(),
      onPopPage: _handlePopPage,
    );
  }

  List<Page> _buildPages() {
    final status = _authProvider.status;
    final user = _authProvider.currentUser;

    switch (status) {
      case AuthStatus.initial:
      case AuthStatus.loading:
        return [_buildSplashPage()];

      case AuthStatus.unauthenticated:
      case AuthStatus.error:
      case AuthStatus.accountDeleted:
        return [_buildAuthPage()];

      case AuthStatus.emailVerificationPending:
        return [_buildAuthPage(), _buildEmailVerificationPage()];

      case AuthStatus.profileIncomplete:
        return [_buildAuthPage(), _buildProfileCompletionPage()];

      case AuthStatus.authenticated:
        if (user == null) {
          return [_buildAuthPage()];
        }
        return _buildAuthenticatedPages(user.role, user.gender);
    }
  }

  List<Page> _buildAuthenticatedPages(String role, String? gender) {
    switch (role) {
      case 'admin':
        return [_buildAuthPage(), _buildAdminDashboardPage()];

      case 'moderator':
        return [_buildAuthPage(), _buildModeratorPanelPage()];

      case 'user':
      default:
        return [_buildAuthPage(), _buildHomePage(gender)];
    }
  }

  MaterialPage _buildSplashPage() {
    return const MaterialPage(
      key: ValueKey('splash'),
      child: Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }

  MaterialPage _buildAuthPage() {
    return const MaterialPage(key: ValueKey('auth'), child: AuthScreen());
  }

  MaterialPage _buildEmailVerificationPage() {
    return const MaterialPage(
      key: ValueKey('email_verification'),
      child: EmailVerificationScreen(),
    );
  }

  MaterialPage _buildProfileCompletionPage() {
    return const MaterialPage(
      key: ValueKey('profile_completion'),
      child: ProfileCompletionScreen(),
    );
  }

  MaterialPage _buildHomePage(String? gender) {
    return MaterialPage(
      key: ValueKey('home_$gender'),
      child: HomeScreen(gender: gender),
    );
  }

  MaterialPage _buildAdminDashboardPage() {
    return const MaterialPage(
      key: ValueKey('admin_dashboard'),
      child: AdminDashboardScreen(),
    );
  }

  MaterialPage _buildModeratorPanelPage() {
    return const MaterialPage(
      key: ValueKey('moderator_panel'),
      child: ModeratorPanelScreen(),
    );
  }

  bool _handlePopPage(Route route, dynamic result) {
    if (!route.didPop(result)) {
      return false;
    }

    // Gestion de la navigation back selon le contexte
    final status = _authProvider.status;

    if (status == AuthStatus.authenticated) {
      // Ne pas permettre de revenir en arrière si authentifié
      return false;
    }

    notifyListeners();
    return true;
  }

  @override
  Future<void> setNewRoutePath(configuration) async {
    // Pas de deep linking pour l'instant
  }

  @override
  void dispose() {
    _authProvider.removeListener(notifyListeners);
    super.dispose();
  }
}

// Email Verification Screen
class EmailVerificationScreen extends StatelessWidget {
  const EmailVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.email_outlined,
                size: 120,
                color: theme.colorScheme.primary,
              ),

              const SizedBox(height: 32),

              Text(
                'Vérifiez votre email',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                'Nous avons envoyé un lien de vérification à votre adresse email. Cliquez sur le lien pour activer votre compte.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              FilledButton(
                onPressed: () {
                  // Ouvrir l'app email
                },
                child: const Text('Ouvrir l\'app email'),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  context.read<AuthProvider>().signOut();
                },
                child: const Text('Retour à la connexion'),
              ),

              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Votre compte sera supprimé automatiquement après 30 jours si l\'email n\'est pas vérifié',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange[800],
                      ),
                      textAlign: TextAlign.center,
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
}

// Home Screen with role/gender routing
class HomeScreen extends StatefulWidget {
  final String? gender;

  const HomeScreen({super.key, this.gender});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilum'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Notifications in-app
            },
          ),
        ],
      ),
      body: _buildBody(),
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

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildDiscoverPage();
      case 1:
        return _buildMatchesPage();
      case 2:
        return _buildMessagesPlaceholder();
      case 3:
        return _buildProfilePage();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDiscoverPage() {
    return Center(
      child: Text(
        'Page Découvrir - Thème ${widget.gender}',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }

  Widget _buildMatchesPage() {
    return Center(
      child: Text(
        'Page Matches',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }

  Widget _buildMessagesPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Messagerie P2P',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'À venir dans la prochaine version',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: user?.photoUrl != null
                ? NetworkImage(user!.photoUrl!)
                : null,
            child: user?.photoUrl == null
                ? const Icon(Icons.person, size: 60)
                : null,
          ),

          const SizedBox(height: 16),

          Text(
            user?.fullName ?? 'Utilisateur',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 32),

          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Paramètres'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigation paramètres
            },
          ),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Déconnexion'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await authProvider.signOut();
            },
          ),
        ],
      ),
    );
  }
}
