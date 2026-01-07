import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/auth_rate_limiter.dart';

class AuthScreenAdvanced extends StatefulWidget {
  const AuthScreenAdvanced({super.key});

  @override
  State<AuthScreenAdvanced> createState() => _AuthScreenAdvancedState();
}

class _AuthScreenAdvancedState extends State<AuthScreenAdvanced>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _hasAttemptedSubmit =
      false; // Pour activer la validation après 1ère tentative

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // Erreur spécifique au champ password
  String? _passwordFieldError;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();

    // Listener pour validation temps réel du password confirmation
    _confirmPasswordController.addListener(_validatePasswordMatch);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _animController.dispose();
    _confirmPasswordController.removeListener(_validatePasswordMatch);
    super.dispose();
  }

  void _validatePasswordMatch() {
    if (_hasAttemptedSubmit && _isSignUp) {
      setState(() {}); // Force rebuild pour afficher l'erreur
    }
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _passwordFieldError = null;
      _hasAttemptedSubmit = false;
      _confirmPasswordController.clear();
      _animController.reset();
      _animController.forward();
    });
  }

  Future<void> _submit() async {
    setState(() {
      _hasAttemptedSubmit = true;
      _passwordFieldError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final rateLimiter = context.read<AuthRateLimiter>();

    // Vérifier si bloqué
    if (!rateLimiter.canAttemptLogin()) {
      _showSnackbar(rateLimiter.blockMessage, isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    bool success;

    if (_isSignUp) {
      success = await authProvider.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
      );

      if (mounted && !success) {
        // Vérifier si l'email existe déjà (code déjà géré dans auth_provider)
        final error = authProvider.errorMessage;
        if (error != null && error.contains('déjà utilisé')) {
          _showAutoSwitchDialog(
            title: 'Email déjà enregistré',
            message: 'Cet email est déjà utilisé. Voulez-vous vous connecter ?',
            onConfirm: () {
              setState(() {
                _isSignUp = false;
                _confirmPasswordController.clear();
              });
            },
          );
        } else {
          _showSnackbar(
            error ?? 'Erreur lors de l\'inscription',
            isError: true,
          );
        }
      }
    } else {
      success = await authProvider.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted && !success) {
        final error = authProvider.errorMessage;

        // 🔍 Détection email inexistant
        if (error == 'email_not_found') {
          _showAutoSwitchDialog(
            title: 'Email non trouvé',
            message:
                'Cet email n\'est pas enregistré. Voulez-vous créer un compte ?',
            onConfirm: () {
              setState(() {
                _isSignUp = true;
              });
            },
          );
        }
        // ❌ Password incorrect → rate limiter
        else if (error != null && _isPasswordError(error)) {
          await rateLimiter.recordFailedAttempt(_emailController.text.trim());

          setState(() {
            _passwordFieldError = 'Mot de passe incorrect';
          });

          final remaining = rateLimiter.remainingAttempts;
          if (remaining > 0) {
            _showSnackbar(
              'Mot de passe incorrect. $remaining tentative${remaining > 1 ? 's' : ''} restante${remaining > 1 ? 's' : ''}.',
              isError: true,
            );
          }
        } else {
          _showSnackbar(error ?? 'Erreur de connexion', isError: true);
        }
      } else if (success) {
        // ✅ Succès → reset rate limiter
        await rateLimiter.recordSuccess();
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool _isPasswordError(String error) {
    final lowerError = error.toLowerCase();
    return lowerError.contains('password') ||
        lowerError.contains('mot de passe') ||
        lowerError.contains('incorrect') ||
        lowerError.contains('invalid');
  }

  void _showAutoSwitchDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Oui'),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showForgotPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ForgotPasswordSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.8),
              theme.colorScheme.secondary.withOpacity(0.6),
              theme.colorScheme.tertiary.withOpacity(0.4),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'P',
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Profilum',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Text(
                      'Connectez-vous avec authenticité',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // ⚠️ Banner de blocage
                    Consumer<AuthRateLimiter>(
                      builder: (context, rateLimiter, _) {
                        if (!rateLimiter.isBlocked)
                          return const SizedBox.shrink();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red, width: 2),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_clock,
                                color: Colors.red,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Compte temporairement bloqué',
                                      style: TextStyle(
                                        color: Colors.red.shade900,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      rateLimiter.blockMessage,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Form Card
                    Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isSignUp ? 'Créer un compte' : 'Connexion',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 32),

                            // Nom complet (signup uniquement, optionnel)
                            if (_isSignUp) ...[
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Nom complet (optionnel)',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Email
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (!_hasAttemptedSubmit) return null;
                                if (value == null || value.trim().isEmpty) {
                                  return 'Email requis';
                                }
                                if (!value.contains('@') ||
                                    !value.contains('.')) {
                                  return 'Email invalide';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // Password
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Mot de passe',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    );
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                errorText: _passwordFieldError,
                              ),
                              obscureText: _obscurePassword,
                              textInputAction: _isSignUp
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!_isSignUp) _submit();
                              },
                              validator: (value) {
                                if (!_hasAttemptedSubmit) return null;
                                if (value == null || value.isEmpty) {
                                  return 'Mot de passe requis';
                                }
                                if (_isSignUp && value.length < 8) {
                                  return 'Minimum 8 caractères';
                                }
                                return null;
                              },
                              onChanged: (_) {
                                // Clear password error on change
                                if (_passwordFieldError != null) {
                                  setState(() => _passwordFieldError = null);
                                }
                              },
                            ),

                            // Confirmation password (signup uniquement)
                            if (_isSignUp) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _confirmPasswordController,
                                decoration: InputDecoration(
                                  labelText: 'Confirmer le mot de passe',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _obscureConfirmPassword =
                                            !_obscureConfirmPassword,
                                      );
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                validator: (value) {
                                  if (!_hasAttemptedSubmit) return null;
                                  if (value == null || value.isEmpty) {
                                    return 'Confirmation requise';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Les mots de passe ne correspondent pas';
                                  }
                                  return null;
                                },
                              ),
                            ],

                            // Forgot password (login uniquement)
                            if (!_isSignUp) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _showForgotPassword,
                                  child: Text(
                                    'Mot de passe oublié ?',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Submit button
                            Consumer<AuthRateLimiter>(
                              builder: (context, rateLimiter, _) {
                                final isBlocked = rateLimiter.isBlocked;

                                return FilledButton(
                                  onPressed: (isBlocked || _isLoading)
                                      ? null
                                      : _submit,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: isBlocked
                                        ? Colors.grey
                                        : theme.colorScheme.primary,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          isBlocked
                                              ? 'Bloqué (${rateLimiter.remainingSeconds}s)'
                                              : (_isSignUp
                                                    ? 'S\'inscrire'
                                                    : 'Se connecter'),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                );
                              },
                            ),

                            const SizedBox(height: 16),

                            // Toggle login/signup
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isSignUp
                                      ? 'Déjà un compte ? '
                                      : 'Pas encore de compte ? ',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                TextButton(
                                  onPressed: _toggleMode,
                                  child: Text(
                                    _isSignUp ? 'Se connecter' : 'S\'inscrire',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// FORGOT PASSWORD SHEET
// ════════════════════════════════════════════════════════════════

class _ForgotPasswordSheet extends StatefulWidget {
  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (_emailController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    final success = await context.read<AuthProvider>().resetPassword(
      _emailController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _emailSent = success;
      });

      if (success) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Réinitialiser le mot de passe',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          if (!_emailSent) ...[
            Text(
              'Entrez votre email pour recevoir un lien de réinitialisation',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 24),

            FilledButton(
              onPressed: _isLoading ? null : _sendResetEmail,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Envoyer le lien'),
            ),
          ] else ...[
            const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green,
            ),

            const SizedBox(height: 16),

            Text(
              'Email envoyé !',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              'Vérifiez votre boîte mail',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
