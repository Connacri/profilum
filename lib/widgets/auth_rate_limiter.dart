// lib/services/auth_rate_limiter.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🛡️ Service de rate limiting pour sécuriser l'authentification
/// Bloque progressivement après 3 tentatives échouées : 15s, 1min, 5min, 30min
class AuthRateLimiter extends ChangeNotifier {
  static const String _keyAttempts = 'auth_failed_attempts';
  static const String _keyBlockedUntil = 'auth_blocked_until';
  static const String _keyLastEmail = 'auth_last_email';
  static const String _keyBlockCount = 'auth_block_count';

  // 🎯 Durées de blocage progressives (en secondes)
  static const List<int> _blockDurations = [
    15, // 1ère fois : 15 secondes
    60, // 2ème fois : 1 minute
    300, // 3ème fois : 5 minutes
    1800, // 4ème+ fois : 30 minutes
  ];

  int _failedAttempts = 0;
  int _blockCount = 0;
  DateTime? _blockedUntil;
  String? _lastEmail;
  Timer? _countdownTimer;

  int get failedAttempts => _failedAttempts;
  int get blockCount => _blockCount;
  DateTime? get blockedUntil => _blockedUntil;
  
  bool get isBlocked =>
      _blockedUntil != null && DateTime.now().isBefore(_blockedUntil!);

  /// Temps restant avant déblocage (en secondes)
  int get remainingSeconds {
    if (!isBlocked) return 0;
    return _blockedUntil!.difference(DateTime.now()).inSeconds;
  }

  /// Message de blocage formaté
  String get blockMessage {
    if (!isBlocked) return '';
    final seconds = remainingSeconds;
    if (seconds >= 60) {
      final minutes = (seconds / 60).ceil();
      return 'Trop de tentatives. Réessayez dans $minutes minute${minutes > 1 ? 's' : ''}.';
    }
    return 'Trop de tentatives. Réessayez dans $seconds seconde${seconds > 1 ? 's' : ''}.';
  }

  /// Nombre de tentatives restantes avant blocage
  int get remainingAttempts {
    if (_failedAttempts >= 3) return 0;
    return 3 - _failedAttempts;
  }

  AuthRateLimiter() {
    _loadState();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// 🔍 Charger l'état depuis SharedPreferences
  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _failedAttempts = prefs.getInt(_keyAttempts) ?? 0;
      _blockCount = prefs.getInt(_keyBlockCount) ?? 0;
      _lastEmail = prefs.getString(_keyLastEmail);

      final blockedTimestamp = prefs.getInt(_keyBlockedUntil);
      if (blockedTimestamp != null) {
        _blockedUntil = DateTime.fromMillisecondsSinceEpoch(blockedTimestamp);

        // Si le blocage est expiré, reset
        if (DateTime.now().isAfter(_blockedUntil!)) {
          await _resetAfterBlock();
        } else {
          _startCountdown();
        }
      }

      notifyListeners();
      debugPrint('🛡️ Rate limiter loaded: attempts=$_failedAttempts, blocks=$_blockCount');
    } catch (e) {
      debugPrint('❌ Rate limiter load error: $e');
    }
  }

  /// 💾 Sauvegarder l'état
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setInt(_keyAttempts, _failedAttempts);
      await prefs.setInt(_keyBlockCount, _blockCount);

      if (_lastEmail != null) {
        await prefs.setString(_keyLastEmail, _lastEmail!);
      }

      if (_blockedUntil != null) {
        await prefs.setInt(
          _keyBlockedUntil,
          _blockedUntil!.millisecondsSinceEpoch,
        );
      } else {
        await prefs.remove(_keyBlockedUntil);
      }
    } catch (e) {
      debugPrint('❌ Rate limiter save error: $e');
    }
  }

  /// ✅ Vérifier si l'utilisateur peut tenter une connexion
  bool canAttemptLogin() {
    if (!isBlocked) return true;

    debugPrint('🚫 Login blocked until: $_blockedUntil');
    return false;
  }

  /// ❌ Enregistrer une tentative échouée
  Future<void> recordFailedAttempt(String email) async {
    // Si l'email change, reset le compteur
    if (_lastEmail != null && _lastEmail != email) {
      debugPrint('🔄 Email changed, resetting attempts');
      await _resetAttempts();
    }

    _lastEmail = email;
    _failedAttempts++;

    debugPrint('❌ Failed attempt #$_failedAttempts for: $email');

    // Bloquer après 3 tentatives
    if (_failedAttempts >= 3) {
      await _blockUser();
    }

    await _saveState();
    notifyListeners();
  }

  /// 🔒 Bloquer l'utilisateur
  Future<void> _blockUser() async {
    // Calculer la durée du blocage selon le nombre de fois qu'il a été bloqué
    final blockIndex = _blockCount.clamp(0, _blockDurations.length - 1);
    final blockSeconds = _blockDurations[blockIndex];

    _blockedUntil = DateTime.now().add(Duration(seconds: blockSeconds));
    _blockCount++;

    debugPrint('🔒 User blocked until: $_blockedUntil (${blockSeconds}s) - Block #$_blockCount');

    _startCountdown();
    await _saveState();
    notifyListeners();
  }

  /// ⏱️ Démarrer le compte à rebours
  void _startCountdown() {
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isBlocked) {
        timer.cancel();
        _resetAfterBlock();
      }
      notifyListeners();
    });
  }

  /// 🔄 Reset après expiration du blocage
  Future<void> _resetAfterBlock() async {
    debugPrint('🔄 Block expired, resetting attempts');

    _failedAttempts = 0;
    _blockedUntil = null;
    _countdownTimer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAttempts);
    await prefs.remove(_keyBlockedUntil);
    // On garde _lastEmail et _blockCount

    notifyListeners();
  }

  /// 🔄 Reset des tentatives (changement d'email)
  Future<void> _resetAttempts() async {
    _failedAttempts = 0;
    _blockedUntil = null;
    _countdownTimer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAttempts);
    await prefs.remove(_keyBlockedUntil);

    notifyListeners();
  }

  /// ✅ Succès de connexion
  Future<void> recordSuccess() async {
    debugPrint('✅ Login success, resetting rate limiter');
    await _fullReset();
  }

  /// 🧹 Nettoyage complet (logout)
  Future<void> clear() async {
    debugPrint('🧹 Clearing rate limiter');
    await _fullReset();
  }

  /// 🔄 Reset complet
  Future<void> _fullReset() async {
    _failedAttempts = 0;
    _blockCount = 0;
    _blockedUntil = null;
    _lastEmail = null;
    _countdownTimer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAttempts);
    await prefs.remove(_keyBlockCount);
    await prefs.remove(_keyBlockedUntil);
    await prefs.remove(_keyLastEmail);

    notifyListeners();
  }
}
