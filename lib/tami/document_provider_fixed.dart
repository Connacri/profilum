// ==================== DOCUMENT PROVIDER UNIFIÉ ====================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models_unified.dart';
import 'ocr_provider.dart';

enum ScanState { idle, processing, success, error }

class DocumentProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _ocrProvider = OCRProvider();

  ScanState _state = ScanState.idle;
  String? _errorMessage;
  ScannedDocument? _currentDocument;
  List<ScannedDocument> _userDocuments = [];

  ScanState get state => _state;

  String? get errorMessage => _errorMessage;

  ScannedDocument? get currentDocument => _currentDocument;

  List<ScannedDocument> get userDocuments => _userDocuments;

  // Setter pour permettre la modification depuis l'extérieur
  set currentDocument(ScannedDocument? doc) {
    _currentDocument = doc;
    notifyListeners();
  }

  /// Charger les documents de l'utilisateur
  Future<void> loadUserDocuments() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _supabase
          .from('scanned_documents')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _userDocuments = (response as List)
          .map((json) => ScannedDocument.fromSupabaseJson(json))
          .toList();

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur chargement: $e';
      notifyListeners();
    }
  }

  /// Scanner un document avec OCR
  Future<void> scanDocument({
    required Uint8List imageBytes,
    required DocumentType documentType,
  }) async {
    _state = ScanState.processing;
    _errorMessage = null;
    notifyListeners();

    try {
      // OCR avec provider optimisé
      final extractedText = await _ocrProvider.processImage(imageBytes);

      if (extractedText == null || extractedText.isEmpty) {
        throw Exception('Aucun texte détecté');
      }

      // Calculer score de confiance
      final confidence = _ocrProvider.analyzeConfidence(extractedText);

      // Parser selon le type
      final userId = _supabase.auth.currentUser!.id;
      ScannedDocument? doc;

      switch (documentType) {
        case DocumentType.chifa:
          doc = _parseChifa(extractedText, userId, confidence);
          break;
        case DocumentType.cni:
          doc = _parseCNI(extractedText, userId, confidence);
          break;
        case DocumentType.passport:
          doc = _parsePassport(extractedText, userId, confidence);
          break;
      }

      if (doc == null) {
        throw Exception('Impossible d\'extraire les données');
      }

      // Vérifier si existe déjà
      final existingDoc = await _checkExistingDocument(doc);
      if (existingDoc != null) {
        _currentDocument = existingDoc;
        _state = ScanState.success;
        notifyListeners();
        return;
      }

      _currentDocument = doc;
      _state = ScanState.success;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur OCR: $e';
      _state = ScanState.error;
      notifyListeners();
    }
  }

  /// Vérifier si document existe
  Future<ScannedDocument?> _checkExistingDocument(ScannedDocument doc) async {
    try {
      String? number;
      String column;

      if (doc is ChifaCard) {
        number = doc.chifaNumber;
        column = 'chifa_number';
      } else if (doc is CNICard) {
        number = doc.cniNumber;
        column = 'cni_number';
      } else if (doc is PassportCard) {
        number = doc.passportNumber;
        column = 'passport_number';
      } else {
        return null;
      }

      final response = await _supabase
          .from('scanned_documents')
          .select()
          .eq(column, number)
          .eq('user_id', doc.userId)
          .maybeSingle();

      if (response != null) {
        return ScannedDocument.fromSupabaseJson(response);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Parser Chifa (AMÉLIORÉ avec regex plus robustes)
  ChifaCard? _parseChifa(String text, String userId, double confidence) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

    String? chifaNumber;
    String? fullName;
    String organism = 'AUTRE';
    DateTime? birthDate;
    DateTime? expiryDate;

    // Numéro Chifa: 12-13 chiffres consécutifs
    final chifaRegex = RegExp(r'\b(\d{12,13})\b');
    final chifaMatch = chifaRegex.firstMatch(text);
    if (chifaMatch != null) {
      chifaNumber = chifaMatch.group(1);
    }

    // Nom: généralement ligne en MAJUSCULES avec espaces
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == trimmed.toUpperCase() &&
          trimmed.length > 5 &&
          trimmed.contains(' ') &&
          RegExp(r'^[A-Z\s]+$').hasMatch(trimmed)) {
        fullName = trimmed;
        break;
      }
    }

    // Organisme
    if (text.toUpperCase().contains('CNAS')) {
      organism = 'CNAS';
    } else if (text.toUpperCase().contains('CASNOS')) {
      organism = 'CASNOS';
    }

    // Dates au format DD/MM/YYYY ou DD-MM-YYYY
    final dateRegex = RegExp(r'\b(\d{2})[/-](\d{2})[/-](\d{4})\b');
    final dates = dateRegex.allMatches(text).toList();

    if (dates.isNotEmpty) {
      final firstMatch = dates[0];
      try {
        birthDate = DateTime(
          int.parse(firstMatch.group(3)!),
          int.parse(firstMatch.group(2)!),
          int.parse(firstMatch.group(1)!),
        );
      } catch (_) {}
    }

    if (dates.length > 1) {
      final secondMatch = dates[1];
      try {
        expiryDate = DateTime(
          int.parse(secondMatch.group(3)!),
          int.parse(secondMatch.group(2)!),
          int.parse(secondMatch.group(1)!),
        );
      } catch (_) {}
    }

    if (chifaNumber == null || fullName == null) {
      return null;
    }

    return ChifaCard(
      userId: userId,
      fullName: fullName,
      chifaNumber: chifaNumber,
      organism: organism,
      birthDate: birthDate,
      expiryDate: expiryDate,
      confidenceScore: confidence,
    );
  }

  /// Parser CNI (AMÉLIORÉ)
  CNICard? _parseCNI(String text, String userId, double confidence) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

    String? cniNumber;
    String? fullName;
    String birthPlace = '';
    DateTime? birthDate;

    // Numéro CNI: exactement 18 chiffres
    final cniRegex = RegExp(r'\b(\d{18})\b');
    final cniMatch = cniRegex.firstMatch(text);
    if (cniMatch != null) {
      cniNumber = cniMatch.group(1);
    }

    // Nom
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == trimmed.toUpperCase() &&
          trimmed.length > 5 &&
          RegExp(r'^[A-Z\s]+$').hasMatch(trimmed)) {
        fullName = trimmed;
        break;
      }
    }

    // Lieu de naissance: chercher "Né à" ou "Née à"
    final birthPlaceRegex =
        RegExp(r'N[ée]+\s+[àa]\s+([A-Z\s]+)', caseSensitive: false);
    final birthMatch = birthPlaceRegex.firstMatch(text);
    if (birthMatch != null) {
      birthPlace = birthMatch.group(1)?.trim() ?? '';
    }

    // Date
    final dateRegex = RegExp(r'\b(\d{2})[/-](\d{2})[/-](\d{4})\b');
    final dateMatch = dateRegex.firstMatch(text);
    if (dateMatch != null) {
      try {
        birthDate = DateTime(
          int.parse(dateMatch.group(3)!),
          int.parse(dateMatch.group(2)!),
          int.parse(dateMatch.group(1)!),
        );
      } catch (_) {}
    }

    if (cniNumber == null || fullName == null) {
      return null;
    }

    return CNICard(
      userId: userId,
      fullName: fullName,
      cniNumber: cniNumber,
      birthPlace: birthPlace,
      birthDate: birthDate,
      confidenceScore: confidence,
    );
  }

  /// Parser Passeport (AMÉLIORÉ)
  PassportCard? _parsePassport(String text, String userId, double confidence) {
    String? passportNumber;
    String? fullName;
    String issuePlace = 'ALGÉRIE';

    // Numéro passeport: 2 lettres + 7 chiffres (format algérien standard)
    final passportRegex = RegExp(r'\b([A-Z]{2}\d{7})\b');
    final passMatch = passportRegex.firstMatch(text);
    if (passMatch != null) {
      passportNumber = passMatch.group(1);
    }

    // Nom
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == trimmed.toUpperCase() &&
          trimmed.length > 5 &&
          RegExp(r'^[A-Z\s]+$').hasMatch(trimmed)) {
        fullName = trimmed;
        break;
      }
    }

    if (passportNumber == null || fullName == null) {
      return null;
    }

    return PassportCard(
      userId: userId,
      fullName: fullName,
      passportNumber: passportNumber,
      issuePlace: issuePlace,
      confidenceScore: confidence,
    );
  }

  /// Sauvegarder le document
  Future<bool> saveCurrentDocument() async {
    if (_currentDocument == null) return false;

    try {
      final existing = await _checkExistingDocument(_currentDocument!);

      if (existing != null) {
        // Mise à jour
        await _supabase
            .from('scanned_documents')
            .update(_currentDocument!.toSupabaseJson())
            .eq('id', existing.id!);
      } else {
        // Création
        await _supabase
            .from('scanned_documents')
            .insert(_currentDocument!.toSupabaseJson());
      }

      await loadUserDocuments();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur sauvegarde: $e';
      notifyListeners();
      return false;
    }
  }

  /// Supprimer un document
  Future<bool> deleteDocument(String documentId) async {
    try {
      await _supabase.from('scanned_documents').delete().eq('id', documentId);
      await loadUserDocuments();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur suppression: $e';
      notifyListeners();
      return false;
    }
  }

  void resetState() {
    _state = ScanState.idle;
    _errorMessage = null;
    _currentDocument = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ocrProvider.dispose();
    super.dispose();
  }
}
