// ═══════════════════════════════════════════════════════════════════
// 👤 GUEST MODE PROVIDER
// ═══════════════════════════════════════════════════════════════════
// Gère le mode invité: scan de documents sans authentification
// Stockage local uniquement, option de conversion vers compte permanent
// ═══════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models_unified.dart';


class GuestModeProvider extends ChangeNotifier {
  // ═══════════════════════════════════════════════════════════════════
  // 📦 STATE
  // ═══════════════════════════════════════════════════════════════════

  List<ScannedDocument> _guestDocuments = [];
  bool _isLoading = false;
  String? _errorMessage;

  static const String _keyGuestDocs = 'guest_documents';
  static const String _keyGuestMode = 'is_guest_mode';

  // ═══════════════════════════════════════════════════════════════════
  // 🔍 GETTERS
  // ═══════════════════════════════════════════════════════════════════

  List<ScannedDocument> get guestDocuments => List.unmodifiable(_guestDocuments);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasDocuments => _guestDocuments.isNotEmpty;
  int get documentCount => _guestDocuments.length;

  // ═══════════════════════════════════════════════════════════════════
  // 🚀 INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════

  /// Charger les documents du guest depuis SharedPreferences
  Future<void> loadGuestDocuments() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final docsJson = prefs.getString(_keyGuestDocs);

      if (docsJson != null) {
        final List<dynamic> decoded = jsonDecode(docsJson);
        _guestDocuments = decoded
            .map((json) => ScannedDocument.fromSupabaseJson(json))
            .toList();

        debugPrint('✅ ${_guestDocuments.length} guest documents loaded');
      }
    } catch (e) {
      _errorMessage = 'Erreur chargement: $e';
      debugPrint('❌ GuestModeProvider.loadGuestDocuments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 💾 SAVE DOCUMENT
  // ═══════════════════════════════════════════════════════════════════

  /// Ajouter un document scanné en mode guest
  Future<bool> addGuestDocument(ScannedDocument document) async {
    try {
      // Générer un ID temporaire unique
      final tempId = 'guest_${DateTime.now().millisecondsSinceEpoch}';

      // Créer une copie avec l'ID temporaire
      ScannedDocument docWithId;

      if (document is ChifaCard) {
        docWithId = document.copyWith(id: tempId);
      } else if (document is CNICard) {
        docWithId = document.copyWith(id: tempId);
      } else if (document is PassportCard) {
        docWithId = document.copyWith(id: tempId);
      } else {
        throw Exception('Type de document non supporté');
      }

      _guestDocuments.add(docWithId);
      await _saveToLocal();

      debugPrint('✅ Guest document added: $tempId');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur sauvegarde: $e';
      debugPrint('❌ GuestModeProvider.addGuestDocument: $e');
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🗑️ DELETE DOCUMENT
  // ═══════════════════════════════════════════════════════════════════

  /// Supprimer un document guest
  Future<bool> deleteGuestDocument(String documentId) async {
    try {
      _guestDocuments.removeWhere((doc) => doc.id == documentId);
      await _saveToLocal();

      debugPrint('✅ Guest document deleted: $documentId');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur suppression: $e';
      debugPrint('❌ GuestModeProvider.deleteGuestDocument: $e');
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔄 UPDATE DOCUMENT
  // ═══════════════════════════════════════════════════════════════════

  /// Mettre à jour un document guest
  Future<bool> updateGuestDocument(ScannedDocument document) async {
    try {
      final index = _guestDocuments.indexWhere((doc) => doc.id == document.id);

      if (index == -1) {
        _errorMessage = 'Document non trouvé';
        return false;
      }

      _guestDocuments[index] = document;
      await _saveToLocal();

      debugPrint('✅ Guest document updated: ${document.id}');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur mise à jour: $e';
      debugPrint('❌ GuestModeProvider.updateGuestDocument: $e');
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 💾 SAVE TO LOCAL STORAGE
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final docsJson = _guestDocuments
          .map((doc) => doc.toSupabaseJson())
          .toList();

      await prefs.setString(_keyGuestDocs, jsonEncode(docsJson));
      debugPrint('💾 Guest documents saved to local storage');
    } catch (e) {
      debugPrint('❌ Error saving to local: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔄 CONVERSION TO PERMANENT ACCOUNT
  // ═══════════════════════════════════════════════════════════════════

  /// Récupérer les documents pour migration vers compte permanent
  List<Map<String, dynamic>> exportDocumentsForMigration() {
    return _guestDocuments
        .map((doc) => doc.toSupabaseJson())
        .toList();
  }

  /// Marquer comme converti (vider le cache guest)
  Future<void> clearAfterMigration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyGuestDocs);
      await prefs.remove(_keyGuestMode);

      _guestDocuments.clear();

      debugPrint('✅ Guest data cleared after migration');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error clearing guest data: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔍 SEARCH
  // ═══════════════════════════════════════════════════════════════════

  /// Rechercher parmi les documents guest
  List<ScannedDocument> searchDocuments(String query) {
    if (query.isEmpty) return _guestDocuments;

    final lowerQuery = query.toLowerCase();

    return _guestDocuments.where((doc) {
      final matchesName = doc.fullName.toLowerCase().contains(lowerQuery);
      final matchesPhone = doc.phoneNumber.contains(query);

      String? docNumber;
      if (doc is ChifaCard) docNumber = doc.chifaNumber;
      if (doc is CNICard) docNumber = doc.cniNumber;
      if (doc is PassportCard) docNumber = doc.passportNumber;

      final matchesNumber = docNumber?.toLowerCase().contains(lowerQuery) ?? false;

      return matchesName || matchesPhone || matchesNumber;
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 📊 STATISTICS
  // ═══════════════════════════════════════════════════════════════════

  int get chifaCount => _guestDocuments
      .where((doc) => doc.type == DocumentType.chifa)
      .length;

  int get cniCount => _guestDocuments
      .where((doc) => doc.type == DocumentType.cni)
      .length;

  int get passportCount => _guestDocuments
      .where((doc) => doc.type == DocumentType.passport)
      .length;

  // ═══════════════════════════════════════════════════════════════════
  // 🧹 CLEAR ALL
  // ═══════════════════════════════════════════════════════════════════

  /// Supprimer tous les documents guest (avec confirmation)
  Future<bool> clearAllDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyGuestDocs);

      _guestDocuments.clear();

      debugPrint('✅ All guest documents cleared');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur suppression: $e';
      debugPrint('❌ GuestModeProvider.clearAllDocuments: $e');
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔧 UTILITIES
  // ═══════════════════════════════════════════════════════════════════

  /// Vérifier si un document existe déjà (éviter doublons)
  bool documentExists({
    required DocumentType type,
    required String number,
  }) {
    return _guestDocuments.any((doc) {
      if (doc.type != type) return false;

      String? docNumber;
      if (doc is ChifaCard) docNumber = doc.chifaNumber;
      if (doc is CNICard) docNumber = doc.cniNumber;
      if (doc is PassportCard) docNumber = doc.passportNumber;

      return docNumber == number;
    });
  }

  /// Récupérer un document par ID
  ScannedDocument? getDocumentById(String id) {
    try {
      return _guestDocuments.firstWhere((doc) => doc.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Mode guest activé
  Future<bool> isGuestModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyGuestMode) ?? false;
  }

  /// Activer mode guest
  Future<void> enableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGuestMode, true);
    debugPrint('✅ Guest mode enabled');
  }

  /// Désactiver mode guest
  Future<void> disableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyGuestMode);
    debugPrint('✅ Guest mode disabled');
  }
}