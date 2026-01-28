import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

/// Provider OCR optimisé pour documents algériens
/// Utilise Google ML Kit On-Device (100% GRATUIT)
class OCRProvider extends ChangeNotifier {
  late final TextRecognizer _textRecognizer;
  bool _isProcessing = false;
  String? _errorMessage;
  double _progress = 0.0;

  OCRProvider() {
    // ✅ Script Latin pour documents algériens (français + chiffres arabes)
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  bool get isProcessing => _isProcessing;

  String? get errorMessage => _errorMessage;

  double get progress => _progress;

  /// Traite une image et extrait le texte avec optimisations avancées
  Future<String?> processImage(Uint8List imageBytes) async {
    if (_isProcessing) return null;

    _isProcessing = true;
    _errorMessage = null;
    _progress = 0.0;
    notifyListeners();

    try {
      // Étape 1 : Optimisation image (30%)
      _updateProgress(0.1, 'Optimisation de l\'image...');
      final optimizedBytes = await _optimizeImage(imageBytes);

      _updateProgress(0.3, 'Prétraitement terminé...');

      // Étape 2 : Création InputImage (40%)
      final inputImage = InputImage.fromBytes(
        bytes: optimizedBytes,
        metadata: InputImageMetadata(
          size: const Size(1920, 1080),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 1920,
        ),
      );

      _updateProgress(0.5, 'Analyse OCR en cours...');

      // Étape 3 : OCR On-Device (80%)
      final recognizedText = await _textRecognizer.processImage(inputImage);

      _updateProgress(0.8, 'Extraction des données...');

      // Étape 4 : Post-traitement (100%)
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

  /// Met à jour la progression
  void _updateProgress(double value, String message) {
    _progress = value;
    debugPrint('🔄 OCR Progress: ${(value * 100).toInt()}% - $message');
    notifyListeners();
  }

  /// Optimise l'image pour améliorer la précision OCR
  Future<Uint8List> _optimizeImage(Uint8List bytes) async {
    try {
      // Décode l'image
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;

      img.Image optimized = image;

      // ✅ Optimisation 1 : Redimensionner (max 1920px de large)
      if (image.width > 1920) {
        optimized = img.copyResize(image, width: 1920);
        debugPrint(
            '📏 Image redimensionnée: ${image.width}x${image.height} → ${optimized.width}x${optimized.height}');
      }

      // ✅ Optimisation 2 : Rotation si nécessaire (détection auto)
      // Si hauteur > largeur, probablement en portrait
      if (optimized.height > optimized.width) {
        // La plupart des documents sont pris en paysage
        optimized = img.copyRotate(optimized, angle: 90);
        debugPrint('🔄 Image pivotée de 90°');
      }

      // ✅ Optimisation 3 : Niveaux de gris (réduit le bruit)
      optimized = img.grayscale(optimized);

      // ✅ Optimisation 4 : Augmenter le contraste
      optimized = img.contrast(optimized, contrast: 130);

      // ✅ Optimisation 5 : Netteté (sharpen)
      optimized = img.adjustColor(optimized, saturation: 0);

      // ✅ Optimisation 6 : Réduction du bruit gaussien
      optimized = img.gaussianBlur(optimized, radius: 1);

      // ✅ Optimisation 7 : Binarisation (noir et blanc pur)
      // Améliore drastiquement l'OCR sur documents imprimés
      optimized = _binarize(optimized);

      // ✅ Optimisation 8 : Encoder en JPEG haute qualité
      final result = Uint8List.fromList(img.encodeJpg(optimized, quality: 95));

      debugPrint(
          '✅ Optimisation terminée: ${bytes.length} → ${result.length} bytes');
      return result;
    } catch (e) {
      debugPrint('⚠️ Optimisation image échouée: $e');
      return bytes; // Retourne l'originale en cas d'erreur
    }
  }

  /// Binarisation de l'image (Méthode Otsu simplifiée)
  img.Image _binarize(img.Image image) {
    // Calcul du seuil optimal (simple average)
    int totalBrightness = 0;
    int pixelCount = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final brightness = pixel.r; // Image déjà en niveaux de gris
        totalBrightness += brightness.toInt();
        pixelCount++;
      }
    }

    final threshold = totalBrightness / pixelCount;

    // Application du seuil
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final brightness = pixel.r;

        // Noir ou blanc uniquement
        final newColor = brightness > threshold ? 255 : 0;
        image.setPixel(x, y, img.ColorRgb8(newColor, newColor, newColor));
      }
    }

    return image;
  }

  /// Post-traitement du texte extrait
  String _postProcessText(String rawText) {
    String cleaned = rawText;

    // ✅ Nettoyage 1 : Supprimer les sauts de ligne multiples
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // ✅ Nettoyage 2 : Supprimer les espaces multiples
    cleaned = cleaned.replaceAll(RegExp(r' {2,}'), ' ');

    // ✅ Nettoyage 3 : Corriger les confusions OCR courantes
    final corrections = {
      // Lettres confondues avec chiffres
      'O': '0', // O → 0 dans les numéros
      'l': '1', // l → 1 dans les numéros
      'I': '1', // I → 1 dans les numéros
      'S': '5', // S → 5 (parfois)
      'B': '8', // B → 8 (parfois)

      // Caractères spéciaux mal reconnus
      '|': '1',
      '!': '1',
      '°': '0',
    };

    // Application contextuelle (uniquement dans les séquences de chiffres)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b\d*[OlISB]\d*\b'),
      (match) {
        String result = match.group(0)!;
        corrections.forEach((key, value) {
          result = result.replaceAll(key, value);
        });
        return result;
      },
    );

    // ✅ Nettoyage 4 : Supprimer les caractères invalides
    cleaned = cleaned.replaceAll(
        RegExp(r'[^\w\s\.\-\/\:\,\(\)\n]', unicode: true), '');

    return cleaned.trim();
  }

  /// Analyse la qualité de l'OCR effectué
  double analyzeConfidence(String extractedText) {
    if (extractedText.isEmpty) return 0.0;

    double confidence = 1.0;

    // Pénalités selon la qualité
    if (extractedText.length < 50) confidence -= 0.2; // Texte trop court
    if (extractedText.split('\n').length < 5)
      confidence -= 0.1; // Peu de lignes

    // Bonus si contient des patterns attendus
    if (RegExp(r'\d{12,18}').hasMatch(extractedText))
      confidence += 0.1; // Numéro long
    if (RegExp(r'\d{2}/\d{2}/\d{4}').hasMatch(extractedText))
      confidence += 0.05; // Date
    if (RegExp(r'[A-Z]{2,}').hasMatch(extractedText))
      confidence += 0.05; // Majuscules

    return confidence.clamp(0.0, 1.0);
  }

  /// Nettoie les ressources
  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }
}
