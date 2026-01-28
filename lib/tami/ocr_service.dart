// ═══════════════════════════════════════════════════════════════════
// 📸 OCR SERVICE - OPTIMISÉ ET REFACTORISÉ
// ═══════════════════════════════════════════════════════════════════
// Version service injectable (pas ChangeNotifier)
// Compatible avec google_mlkit_text_recognition ^0.13.0
// Gestion correcte des formats d'image selon plateforme
// ═══════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service OCR optimisé pour documents algériens
/// Utilise Google ML Kit On-Device (100% GRATUIT)
class OCRService {
  late final TextRecognizer _textRecognizer;
  
  bool _isInitialized = false;
  bool _isProcessing = false;

  // ═══════════════════════════════════════════════════════════════════
  // 🚀 INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════

  OCRService() {
    _initialize();
  }

  void _initialize() {
    if (_isInitialized) return;

    // Script Latin pour documents algériens (français + chiffres)
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _isInitialized = true;
    
    debugPrint('✅ OCRService initialized');
  }

  // ═══════════════════════════════════════════════════════════════════
  // 📸 PROCESS IMAGE
  // ═══════════════════════════════════════════════════════════════════

  /// Traiter une image depuis son chemin (RECOMMANDÉ)
  Future<OCRResult> processImageFromPath(String imagePath) async {
    if (_isProcessing) {
      return OCRResult.error('OCR déjà en cours');
    }

    _isProcessing = true;

    try {
      debugPrint('🔍 OCR: Processing image from path...');

      // ✅ MÉTHODE RECOMMANDÉE: InputImage.fromFilePath
      final inputImage = InputImage.fromFilePath(imagePath);

      final result = await _processInputImage(inputImage);
      
      _isProcessing = false;
      return result;
    } catch (e, stack) {
      debugPrint('❌ OCR Error: $e');
      debugPrint('Stack: $stack');
      
      _isProcessing = false;
      return OCRResult.error('Erreur OCR: $e');
    }
  }

  /// Traiter une image depuis un File (Alternative)
  Future<OCRResult> processImageFromFile(File imageFile) async {
    if (_isProcessing) {
      return OCRResult.error('OCR déjà en cours');
    }

    _isProcessing = true;

    try {
      debugPrint('🔍 OCR: Processing image from file...');

      // ✅ InputImage.fromFile
      final inputImage = InputImage.fromFile(imageFile);

      final result = await _processInputImage(inputImage);
      
      _isProcessing = false;
      return result;
    } catch (e, stack) {
      debugPrint('❌ OCR Error: $e');
      debugPrint('Stack: $stack');
      
      _isProcessing = false;
      return OCRResult.error('Erreur OCR: $e');
    }
  }

  /// Traiter une image depuis bytes (À ÉVITER SI POSSIBLE)
  /// Nécessite métadonnées exactes (dimensions, format, etc.)
  Future<OCRResult> processImageFromBytes({
    required Uint8List bytes,
    required int width,
    required int height,
  }) async {
    if (_isProcessing) {
      return OCRResult.error('OCR déjà en cours');
    }

    _isProcessing = true;

    try {
      debugPrint('🔍 OCR: Processing image from bytes...');

      // ⚠️ Format selon plateforme
      final format = Platform.isAndroid 
          ? InputImageFormat.nv21 
          : InputImageFormat.bgra8888;

      // Calculer bytesPerRow selon format
      final bytesPerRow = _calculateBytesPerRow(width, format);

      final metadata = InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: format,
        bytesPerRow: bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: metadata,
      );

      final result = await _processInputImage(inputImage);
      
      _isProcessing = false;
      return result;
    } catch (e, stack) {
      debugPrint('❌ OCR Error: $e');
      debugPrint('Stack: $stack');
      
      _isProcessing = false;
      return OCRResult.error('Erreur OCR: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔧 CORE PROCESSING
  // ═══════════════════════════════════════════════════════════════════

  Future<OCRResult> _processInputImage(InputImage inputImage) async {
    try {
      // ML Kit fait l'optimisation automatiquement
      final recognizedText = await _textRecognizer.processImage(inputImage);

      if (recognizedText.text.isEmpty) {
        return OCRResult.error('Aucun texte détecté dans l\'image');
      }

      debugPrint('✅ OCR: ${recognizedText.text.length} caractères extraits');

      // Post-traitement
      final cleanedText = _postProcessText(recognizedText.text);
      final confidence = _analyzeConfidence(cleanedText);

      return OCRResult(
        rawText: recognizedText.text,
        cleanedText: cleanedText,
        confidence: confidence,
        blocks: recognizedText.blocks.length,
      );
    } catch (e) {
      return OCRResult.error('Erreur traitement: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🧹 POST-PROCESSING
  // ═══════════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════════
  // 📊 CONFIDENCE ANALYSIS
  // ═══════════════════════════════════════════════════════════════════

  double _analyzeConfidence(String extractedText) {
    if (extractedText.isEmpty) return 0.0;

    double confidence = 0.5; // Base

    // Bonus selon le contenu détecté
    if (extractedText.length > 100) confidence += 0.1;
    if (RegExp(r'\d{12,18}').hasMatch(extractedText)) confidence += 0.15;
    if (RegExp(r'\d{2}/\d{2}/\d{4}').hasMatch(extractedText)) confidence += 0.1;
    if (RegExp(r'[A-Z]{3,}').hasMatch(extractedText)) confidence += 0.1;
    if (extractedText.split('\n').length > 5) confidence += 0.05;

    return confidence.clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔧 UTILITIES
  // ═══════════════════════════════════════════════════════════════════

  int _calculateBytesPerRow(int width, InputImageFormat format) {
    switch (format) {
      case InputImageFormat.nv21:
        return width; // NV21: 1 byte per pixel (Y plane)
      
      case InputImageFormat.yuv420:
        return width; // YUV420: 1 byte per pixel (Y plane)
      
      case InputImageFormat.bgra8888:
        return width * 4; // BGRA: 4 bytes per pixel
      
      case InputImageFormat.yuv_420_888:
        return width; // YUV420_888: 1 byte per pixel (Y plane)
      
      default:
        return width * 4; // Fallback: assume 4 bytes per pixel
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🧹 CLEANUP
  // ═══════════════════════════════════════════════════════════════════

  void dispose() {
    _textRecognizer.close();
    _isInitialized = false;
    debugPrint('✅ OCRService disposed');
  }
}

// ═══════════════════════════════════════════════════════════════════
// 📊 OCR RESULT MODEL
// ═══════════════════════════════════════════════════════════════════

class OCRResult {
  final String rawText;
  final String cleanedText;
  final double confidence;
  final int blocks;
  final String? errorMessage;

  OCRResult({
    required this.rawText,
    required this.cleanedText,
    required this.confidence,
    required this.blocks,
    this.errorMessage,
  });

  factory OCRResult.error(String message) {
    return OCRResult(
      rawText: '',
      cleanedText: '',
      confidence: 0.0,
      blocks: 0,
      errorMessage: message,
    );
  }

  bool get isSuccess => errorMessage == null && cleanedText.isNotEmpty;
  bool get hasError => errorMessage != null;

  Map<String, dynamic> toJson() {
    return {
      'rawText': rawText,
      'cleanedText': cleanedText,
      'confidence': confidence,
      'blocks': blocks,
      'errorMessage': errorMessage,
    };
  }

  @override
  String toString() {
    return 'OCRResult(confidence: ${(confidence * 100).toInt()}%, '
        'blocks: $blocks, length: ${cleanedText.length})';
  }
}

// ═══════════════════════════════════════════════════════════════════
// 🔧 SERVICE LOCATOR EXTENSION
// ═══════════════════════════════════════════════════════════════════

// À ajouter dans service_locator.dart
/*
class ServiceLocator {
  // ... existing code ...
  
  late final OCRService ocr;
  
  Future<void> init(...) async {
    // ... existing init code ...
    
    ocr = OCRService();
    
    // ... rest of init ...
  }
}
*/
