// ==================== ADMIN AUTH PROVIDER COMPLET ====================

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_models.dart';

class AdminAuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  AdminUser? _currentAdmin;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  AdminUser? get currentAdmin => _currentAdmin;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Vérifier l'authentification au démarrage
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAdminId = prefs.getString('admin_id');

      if (savedAdminId != null) {
        final response = await _supabase
            .from('admin_users')
            .select()
            .eq('id', savedAdminId)
            .eq('is_active', true)
            .maybeSingle();

        if (response != null) {
          _currentAdmin = AdminUser.fromJson(response);
          _isAuthenticated = true;
        } else {
          await logout();
        }
      }
    } catch (e) {
      debugPrint('Erreur checkAuthStatus: $e');
      await logout();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Connexion admin
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Hash du mot de passe (SHA-256)
      final passwordHash = sha256.convert(utf8.encode(password)).toString();

      final response = await _supabase
          .from('admin_users')
          .select()
          .eq('email', email.toLowerCase())
          .eq('password_hash', passwordHash)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        _errorMessage = 'Email ou mot de passe incorrect';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentAdmin = AdminUser.fromJson(response);
      _isAuthenticated = true;

      // Sauvegarder session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_id', _currentAdmin!.id);

      // Mettre à jour last_login
      await _supabase.from('admin_users').update({
        'last_login': DateTime.now().toIso8601String(),
      }).eq('id', _currentAdmin!.id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur de connexion: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_id');

    _currentAdmin = null;
    _isAuthenticated = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Récupérer tous les admins (Super Admin uniquement)
  Future<List<AdminUser>> getAllAdmins() async {
    if (_currentAdmin?.isSuperAdmin != true) {
      return [];
    }

    try {
      final response = await _supabase
          .from('admin_users')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => AdminUser.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Erreur getAllAdmins: $e');
      return [];
    }
  }

  /// Créer un admin (Super Admin uniquement)
  Future<bool> createAdmin({
    required String email,
    required String password,
    required String fullName,
    required AdminRole role,
  }) async {
    if (_currentAdmin?.isSuperAdmin != true) {
      _errorMessage = 'Accès refusé: réservé au super admin';
      notifyListeners();
      return false;
    }

    try {
      final passwordHash = sha256.convert(utf8.encode(password)).toString();

      await _supabase.from('admin_users').insert({
        'email': email.toLowerCase(),
        'password_hash': passwordHash,
        'full_name': fullName,
        'role': role.name,
        'is_active': true,
      });

      return true;
    } catch (e) {
      _errorMessage = 'Erreur création admin: $e';
      notifyListeners();
      return false;
    }
  }

  /// Changer le mot de passe d'un admin (Super Admin uniquement)
  Future<bool> changeAdminPassword({
    required String adminId,
    required String newPassword,
  }) async {
    if (_currentAdmin?.isSuperAdmin != true) {
      _errorMessage = 'Accès refusé: réservé au super admin';
      notifyListeners();
      return false;
    }

    try {
      final passwordHash = sha256.convert(utf8.encode(newPassword)).toString();

      await _supabase.from('admin_users').update({
        'password_hash': passwordHash,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', adminId);

      return true;
    } catch (e) {
      _errorMessage = 'Erreur changement mot de passe: $e';
      notifyListeners();
      return false;
    }
  }

  /// Activer/Désactiver un admin (Super Admin uniquement)
  Future<bool> toggleAdminStatus(String adminId, bool isActive) async {
    if (_currentAdmin?.isSuperAdmin != true) {
      return false;
    }

    try {
      await _supabase.from('admin_users').update({
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', adminId);

      return true;
    } catch (e) {
      debugPrint('Erreur toggleAdminStatus: $e');
      return false;
    }
  }

  /// Supprimer un admin (Super Admin uniquement)
  Future<bool> deleteAdmin(String adminId) async {
    if (_currentAdmin?.isSuperAdmin != true) {
      return false;
    }

    // Empêcher la suppression de soi-même
    if (adminId == _currentAdmin!.id) {
      _errorMessage = 'Impossible de supprimer votre propre compte';
      notifyListeners();
      return false;
    }

    try {
      await _supabase.from('admin_users').delete().eq('id', adminId);
      return true;
    } catch (e) {
      _errorMessage = 'Erreur suppression admin: $e';
      notifyListeners();
      return false;
    }
  }
}
