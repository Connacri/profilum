// lib/models/social_link.dart

/// Modèle pour les liens de réseaux sociaux
/// Structure flexible pour supporter n'importe quelle plateforme
class SocialLink {
  final String name; // Instagram, Facebook, TikTok, Spotify, LinkedIn, etc.
  final String url;

  const SocialLink({
    required this.name,
    required this.url,
  });

  /// Factory depuis JSON
  factory SocialLink.fromJson(Map<String, dynamic> json) {
    return SocialLink(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
    );
  }

  /// Convertir en JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
    };
  }

  /// Validation de l'URL
  bool get isValid {
    if (url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Obtenir l'icône appropriée selon la plateforme
  static String getIconName(String name) {
    final lowercaseName = name.toLowerCase();
    
    switch (lowercaseName) {
      case 'instagram':
        return 'camera_alt';
      case 'facebook':
        return 'facebook';
      case 'tiktok':
        return 'music_note';
      case 'spotify':
        return 'music_video';
      case 'linkedin':
        return 'work';
      case 'twitter':
      case 'x':
        return 'alternate_email';
      case 'youtube':
        return 'play_circle';
      case 'snapchat':
        return 'photo_camera';
      default:
        return 'link';
    }
  }

  /// Obtenir la couleur de marque
  static int getColorHex(String name) {
    final lowercaseName = name.toLowerCase();
    
    switch (lowercaseName) {
      case 'instagram':
        return 0xFFE4405F; // Rose Instagram
      case 'facebook':
        return 0xFF1877F2; // Bleu Facebook
      case 'tiktok':
        return 0xFF000000; // Noir TikTok
      case 'spotify':
        return 0xFF1DB954; // Vert Spotify
      case 'linkedin':
        return 0xFF0A66C2; // Bleu LinkedIn
      case 'twitter':
      case 'x':
        return 0xFF1DA1F2; // Bleu Twitter
      case 'youtube':
        return 0xFFFF0000; // Rouge YouTube
      case 'snapchat':
        return 0xFFFFFC00; // Jaune Snapchat
      default:
        return 0xFF6366F1; // Indigo par défaut
    }
  }

  /// Valider le format d'URL selon la plateforme
  static String? validatePlatformUrl(String name, String url) {
    if (url.isEmpty) return null; // Optionnel
    
    final lowercaseName = name.toLowerCase();
    final lowerUrl = url.toLowerCase();
    
    switch (lowercaseName) {
      case 'instagram':
        if (!lowerUrl.contains('instagram.com/')) {
          return 'URL Instagram invalide';
        }
        break;
      case 'facebook':
        if (!lowerUrl.contains('facebook.com/') && 
            !lowerUrl.contains('fb.com/')) {
          return 'URL Facebook invalide';
        }
        break;
      case 'tiktok':
        if (!lowerUrl.contains('tiktok.com/@')) {
          return 'URL TikTok invalide';
        }
        break;
      case 'spotify':
        if (!lowerUrl.contains('open.spotify.com/')) {
          return 'URL Spotify invalide';
        }
        break;
      case 'linkedin':
        if (!lowerUrl.contains('linkedin.com/in/')) {
          return 'URL LinkedIn invalide';
        }
        break;
    }
    
    return null; // Valide
  }

  /// Copier avec modifications
  SocialLink copyWith({String? name, String? url}) {
    return SocialLink(
      name: name ?? this.name,
      url: url ?? this.url,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SocialLink && 
           other.name == name && 
           other.url == url;
  }

  @override
  int get hashCode => name.hashCode ^ url.hashCode;

  @override
  String toString() => 'SocialLink(name: $name, url: $url)';
}

/// Extension pour listes de SocialLinks
extension SocialLinksExtension on List<SocialLink> {
  /// Obtenir un lien par nom de plateforme
  SocialLink? getByName(String name) {
    try {
      return firstWhere(
        (link) => link.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Vérifier si une plateforme existe
  bool hasPlatform(String name) {
    return any((link) => link.name.toLowerCase() == name.toLowerCase());
  }

  /// Filtrer les liens valides uniquement
  List<SocialLink> get validLinks {
    return where((link) => link.isValid).toList();
  }
}
