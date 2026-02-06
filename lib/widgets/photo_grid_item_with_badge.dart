import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../claude/photo_item.dart';


class PhotoGridItem extends StatelessWidget {
  final PhotoItem photo;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const PhotoGridItem({
    super.key,
    required this.photo,
    required this.index,
    this.isSelected = false,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: photo.source == PhotoSourceremote.remote
                ? _buildRemoteImage()
                : _buildLocalImage(),
          ),

          // Border si sélectionné
          if (isSelected)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 3,
                ),
              ),
            ),

          // ✅ Badge "nouveau" pour photos locales
          if (photo.source == PhotoSourceremote.local)
            Positioned(
              top: 8,
              left: 8,
              child: _buildNewBadge(),
            ),

          // Badge numéro (en bas à gauche)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Bouton supprimer (en haut à droite)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onRemove,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ NOUVEAU : Badge "NOUVEAU" pour les photos locales
  Widget _buildNewBadge() {
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
          Icon(
            Icons.fiber_new,
            color: Colors.white,
            size: 14,
          ),
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

  Widget _buildRemoteImage() {
    return CachedNetworkImage(
      imageUrl: photo.remotePath!,
      fit: BoxFit.cover,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(color: Colors.white),
      ),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  Widget _buildLocalImage() {
    return Image.file(
      photo.localFile!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }
}
