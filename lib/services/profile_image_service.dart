// lib/services/profile_image_service.dart - ✅ SERVICE RÉUTILISABLE
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileImageService {
  final SupabaseClient _supabase;

  ProfileImageService(this._supabase);

  /// 📸 Récupérer l'URL de la photo de profil du current user
  /// Retourne null si pas de photo
  Future<String?> getCurrentUserProfileImage() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        debugPrint('❌ No current user');
        return null;
      }

      final photo = await _supabase
          .from('photos')
          .select('remote_path, status')
          .eq('user_id', currentUserId)
          .eq('type', 'profile')
          .eq('status', 'approved')
          .maybeSingle();

      if (photo == null) {
        debugPrint('⚠️ No profile photo found for user: $currentUserId');
        return null;
      }

      final remotePath = photo['remote_path'] as String?;
      if (remotePath == null || remotePath.isEmpty) {
        debugPrint('⚠️ Remote path is empty');
        return null;
      }

      return _buildPhotoUrl(remotePath);
    } catch (e) {
      debugPrint('❌ Error getting profile image: $e');
      return null;
    }
  }

  /// 📸 Récupérer l'URL de la photo de profil d'un user spécifique
  Future<String?> getUserProfileImage(String userId) async {
    try {
      if (userId.isEmpty) {
        debugPrint('❌ User ID is empty');
        return null;
      }

      final photo = await _supabase
          .from('photos')
          .select('remote_path, status')
          .eq('user_id', userId)
          .eq('type', 'profile')
          .eq('status', 'approved')
          .maybeSingle();

      if (photo == null) {
        debugPrint('⚠️ No profile photo found for user: $userId');
        return null;
      }

      final remotePath = photo['remote_path'] as String?;
      if (remotePath == null || remotePath.isEmpty) {
        return null;
      }

      return _buildPhotoUrl(remotePath);
    } catch (e) {
      debugPrint('❌ Error getting profile image for user $userId: $e');
      return null;
    }
  }

  /// 🖼️ Construire l'URL complète (depuis ProfilePage)
  String _buildPhotoUrl(String path) {
    // ✅ Valider que le path ne contient pas déjà l'URL complète
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    // ✅ Nettoyer le path
    final cleanPath = path
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+'), '/');

    // ✅ Construire l'URL publique
    final url = _supabase.storage.from('profiles').getPublicUrl(cleanPath);

    debugPrint('🔗 Built profile image URL: $url');
    return url;
  }

  /// 🎨 Widget prêt à l'emploi pour afficher la photo
  /// Utilisation simple: ProfileImageService.buildProfileImageWidget(context, userId)
  static Widget buildProfileImageWidget(
    String? imageUrl, {
    double radius = 24,
    String userName = '',
    bool cacheable = true,
  }) {
    // ✅ Si pas d'image, afficher avatar par défaut
    if (imageUrl == null || imageUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        child: Icon(Icons.person, size: radius, color: Colors.grey[600]),
      );
    }

    // ✅ Avec CachedNetworkImage pour meilleure performance
    if (cacheable) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(imageUrl),
        onBackgroundImageError: (exception, stackTrace) {
          debugPrint('❌ Failed to load image: $imageUrl - $exception');
        },
      );
    }

    // ✅ Sans cache (pour updates rapides)
    return CircleAvatar(
      radius: radius,
      backgroundImage: NetworkImage(imageUrl),
      onBackgroundImageError: (exception, stackTrace) {
        debugPrint('❌ Failed to load image: $imageUrl - $exception');
      },
    );
  }
}
