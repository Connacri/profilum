import 'package:flutter/material.dart';

/// 🎨 Collection de badges pour différents états de photos

class PhotoBadges {
  /// Badge "NOUVEAU" (photo locale)
  static Widget newBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade400],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.fiber_new, color: Colors.white, size: 14),
          SizedBox(width: 4),
          Text(
            'NOUVEAU',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Badge "SUR SERVEUR" (photo remote)
  static Widget cloudBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.cloud_done, color: Colors.white, size: 14),
          SizedBox(width: 4),
          Text(
            'EN LIGNE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Badge "EN MODÉRATION" (status pending)
  static Widget pendingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade600, Colors.orange.shade400],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 4),
          Text(
            'MODÉRATION',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Badge "APPROUVÉE" (status approved)
  static Widget approvedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade600, Colors.teal.shade400],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.verified, color: Colors.white, size: 14),
          SizedBox(width: 4),
          Text(
            'VALIDÉE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Badge "CAMÉRA" (has watermark)
  static Widget cameraBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade600, Colors.purple.shade400],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.camera_alt, color: Colors.white, size: 14),
          SizedBox(width: 4),
          Text(
            'CAMÉRA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Badge dynamique selon l'état de la photo
  static Widget getBadgeForPhoto({
    required bool isLocal,
    required String? status,
    required bool hasWatermark,
  }) {
    // Priorité : local > pending > approved > watermark
    if (isLocal) {
      return newBadge();
    }

    if (status == 'pending') {
      return pendingBadge();
    }

    if (status == 'approved') {
      return approvedBadge();
    }

    if (hasWatermark) {
      return cameraBadge();
    }

    // Par défaut : badge cloud
    return cloudBadge();
  }
}

/// 📋 Exemple d'utilisation dans PhotoGridItem

/*
// Dans le Stack de PhotoGridItem :

if (photo.source == PhotoSource.local)
  Positioned(
    top: 8,
    left: 8,
    child: PhotoBadges.newBadge(), // Badge "NOUVEAU"
  ),

// OU pour un badge dynamique :

Positioned(
  top: 8,
  left: 8,
  child: PhotoBadges.getBadgeForPhoto(
    isLocal: photo.source == PhotoSource.local,
    status: photo.status,
    hasWatermark: photo.hasWatermark,
  ),
),
*/
