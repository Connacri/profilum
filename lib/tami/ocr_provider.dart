// ==================== OCR PROVIDER OPTIMISÉ ====================
// lib/providers/ocr_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Provider OCR optimisé pour documents algériens
/// Utilise Google ML Kit On-Device (100% GRATUIT)
class OCRProvider extends ChangeNotifier {
  late final TextRecognizer _textRecognizer;
  bool _isProcessing = false;
  String? _errorMessage;
  double _progress = 0.0;

  OCRProvider() {
    // Script Latin pour documents algériens (français + chiffres)
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  double get progress => _progress;

  /// Traite une image et extrait le texte (SIMPLIFIÉ - ML Kit optimise automatiquement)
  Future<String?> processImage(Uint8List imageBytes) async {
    if (_isProcessing) return null;

    _isProcessing = true;
    _errorMessage = null;
    _progress = 0.0;
    notifyListeners();

    try {
      _updateProgress(0.2, 'Préparation de l\'image...');

      // Créer InputImage depuis bytes
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: Size(imageBytes.length.toDouble(), imageBytes.length.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: imageBytes.length,
        ),
      );

      _updateProgress(0.5, 'Analyse OCR en cours...');

      // ML Kit fait l'optimisation automatiquement (contraste, netteté, etc.)
      final recognizedText = await _textRecognizer.processImage(inputImage);

      _updateProgress(0.8, 'Extraction des données...');

      // Post-traitement léger uniquement
      final cleanedText = _postProcessText(recognizedText.text);

      _updateProgress(1.0, 'Terminé !');

      _isProcessing = false;
      notifyListeners();

      return cleanedText;
    } catch (e) {
      _errorMessage = 'Erreur OCR: $e';
      _isProcessing = false;
      _progress = 0.0;
      notifyListeners();
      return null;
    }
  }

  void _updateProgress(double value, String message) {
    _progress = value;
    debugPrint('📄 OCR Progress: ${(value * 100).toInt()}% - $message');
    notifyListeners();
  }

  /// Post-traitement minimal du texte extrait
  String _postProcessText(String rawText) {
    String cleaned = rawText;

    // Nettoyage basique
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    cleaned = cleaned.replaceAll(RegExp(r' {2,}'), ' ');

    // Corrections OCR courantes dans les numéros
    final corrections = {
      'O': '0',
      'l': '1',
      'I': '1',
      'S': '5',
      'B': '8',
      '|': '1',
      '!': '1',
      '°': '0',
    };

    // Application uniquement dans les séquences numériques
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b\d*[OlISB|!°]\d*\b'),
          (match) {
        String result = match.group(0)!;
        corrections.forEach((key, value) {
          result = result.replaceAll(key, value);
        });
        return result;
      },
    );

    // Suppression caractères invalides
    cleaned = cleaned.replaceAll(
      RegExp(r'[^\w\s\.\-\/\:\,\(\)\n]', unicode: true),
      '',
    );

    return cleaned.trim();
  }

  /// Analyse la qualité de l'OCR
  double analyzeConfidence(String extractedText) {
    if (extractedText.isEmpty) return 0.0;

    double confidence = 0.5; // Base

    // Bonus selon le contenu détecté
    if (extractedText.length > 100) confidence += 0.1;
    if (RegExp(r'\d{12,18}').hasMatch(extractedText)) confidence += 0.15; // Numéro long
    if (RegExp(r'\d{2}/\d{2}/\d{4}').hasMatch(extractedText)) confidence += 0.1; // Date
    if (RegExp(r'[A-Z]{3,}').hasMatch(extractedText)) confidence += 0.1; // Majuscules
    if (extractedText.split('\n').length > 5) confidence += 0.05; // Multi-lignes

    return confidence.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }
}