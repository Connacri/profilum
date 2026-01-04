// lib/app_router.dart - MODIFICATION simple
import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';
import 'auth/auth_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/home_screen_complete.dart';
import 'screens/profile_completion_screen.dart';

class AppRouter extends RouterDelegate<Object>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
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
        // ✨ NOUVEAU: Proposer la completion (avec possibilité de skip)
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

    final status = _authProvider.status;

    if (status == AuthStatus.authenticated) {
      return false;
    }

    notifyListeners();
    return true;
  }

  @override
  Future<void> setNewRoutePath(Object configuration) async {
    return;
  }

  @override
  void dispose() {
    _authProvider.removeListener(notifyListeners);
    super.dispose();
  }
}

class AppRouteInformationParser extends RouteInformationParser<Object> {
  @override
  Future<Object> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    return Object();
  }

  @override
  RouteInformation? restoreRouteInformation(Object configuration) {
    return RouteInformation(uri: Uri());
  }
}

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
                'Nous avons envoyé un lien de vérification à votre adresse email.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
