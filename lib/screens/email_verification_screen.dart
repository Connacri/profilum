// lib/screens/email_verification_screen.dart - ✅ ÉCRAN VALIDATION EMAIL

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/service_locator.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _checkTimer;
  bool _isChecking = false;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _userEmail = services.supabaseService.currentUser?.email;
    
    // ✅ Vérifier automatiquement toutes les 5 secondes
    _startAutoCheck();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  void _startAutoCheck() {
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkEmailVerification();
    });
  }

  Future<void> _checkEmailVerification() async {
    if (_isChecking) return;

    setState(() => _isChecking = true);

    try {
      // ✅ Rafraîchir la session pour obtenir les dernières infos
      await services.supabaseService.client.auth.refreshSession();

      final user = services.supabaseService.currentUser;

      if (user == null) {
        // User déconnecté
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // ✅ Vérifier si l'email est confirmé
      final emailConfirmed = user.emailConfirmedAt != null;

      debugPrint('📧 Email verification check:');
      debugPrint('   - Email: ${user.email}');
      debugPrint('   - Confirmed: $emailConfirmed');
      debugPrint('   - ConfirmedAt: ${user.emailConfirmedAt}');

      if (emailConfirmed) {
        _checkTimer?.cancel();

        if (!mounted) return;

        // ✅ Email validé → Naviguer selon le rôle
        await _navigateBasedOnRole();
      }

    } catch (e) {
      debugPrint('❌ Error checking email verification: $e');
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _navigateBasedOnRole() async {
    // Import du AuthRouter
    final route = await services.authRouter.getInitialRoute();

    if (!mounted) return;

    // ✅ Afficher notification de bienvenue
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('✅ Email vérifié ! Bienvenue'),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    Navigator.pushReplacementNamed(context, route);
  }

  Future<void> _resendVerificationEmail() async {
    if (_userEmail == null) return;

    try {
      setState(() => _isChecking = true);

      // ✅ Renvoyer l'email de vérification
      await services.supabaseService.client.auth.resend(
        type: OtpType.signup,
        email: _userEmail!,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.email, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('📧 Email de vérification renvoyé'),
              ),
            ],
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

    } catch (e) {
      debugPrint('❌ Error resending email: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 12),
            Text('Se déconnecter ?'),
          ],
        ),
        content: const Text(
          'Cela annulera votre inscription. Vous devrez vous réinscrire.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // ✅ Déconnexion complète
      await services.supabaseService.client.auth.signOut();

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/login');

    } catch (e) {
      debugPrint('❌ Error logging out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ═══════════════════════════════════════════════
                  // 📧 ICÔNE EMAIL
                  // ═══════════════════════════════════════════════
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.email_rounded,
                        size: 80,
                        color: Color(0xFF667EEA),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ═══════════════════════════════════════════════
                  // 📝 TITRE
                  // ═══════════════════════════════════════════════
                  const Text(
                    'Vérifiez votre email',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // ═══════════════════════════════════════════════
                  // 📧 EMAIL
                  // ═══════════════════════════════════════════════
                  if (_userEmail != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _userEmail!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ═══════════════════════════════════════════════
                  // 📄 MESSAGE
                  // ═══════════════════════════════════════════════
                  const Text(
                    'Nous avons envoyé un email de vérification.\n'
                    'Cliquez sur le lien dans l\'email pour activer votre compte.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // ═══════════════════════════════════════════════
                  // 🔄 INDICATEUR DE VÉRIFICATION
                  // ═══════════════════════════════════════════════
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Vérification automatique...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ═══════════════════════════════════════════════
                  // 🔄 BOUTON RENVOYER EMAIL
                  // ═══════════════════════════════════════════════
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isChecking ? null : _resendVerificationEmail,
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'Renvoyer l\'email',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ═══════════════════════════════════════════════
                  // ❌ BOUTON DÉCONNEXION
                  // ═══════════════════════════════════════════════
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text(
                        'Se déconnecter',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ═══════════════════════════════════════════════
                  // 💡 INFO
                  // ═══════════════════════════════════════════════
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.white.withOpacity(0.8),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Pensez à vérifier vos spams si vous ne trouvez pas l\'email',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                            ),
                          ),
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
    );
  }
}
