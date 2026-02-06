// lib/widgets/photo_source_picker.dart - ✅ VERSION OPTIMISÉE ANDROID + WINDOWS

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 📸 Type de source photo
enum PhotoSource {
  camera,
  gallery,
}

/// ✅ WIDGET PRINCIPAL - Bottom Sheet coloré pour Android + Windows
class PhotoSourcePicker {
  /// 📱 Afficher le bottom sheet et retourner la source choisie
  /// 
  /// Optimisé pour Android + Windows avec design coloré
  /// 
  /// Usage:
  /// ```dart
  /// final source = await PhotoSourcePicker.show(
  ///   context,
  ///   title: 'Choisir une photo',
  /// );
  /// 
  /// if (source == PhotoSource.camera) {
  ///   // Caméra (Android uniquement)
  /// } else if (source == PhotoSource.gallery) {
  ///   // Galerie
  /// }
  /// ```
  static Future<PhotoSource?> show(
    BuildContext context, {
    String? title,
    String? subtitle,
  }) async {
    // ✅ Détection automatique de la plateforme
    final isCameraAvailable = !kIsWeb && Platform.isAndroid;
    
    return await showModalBottomSheet<PhotoSource>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return _PhotoSourcePickerContent(
          title: title,
          subtitle: subtitle,
          showCamera: isCameraAvailable,
        );
      },
    );
  }
}

/// 🎨 Contenu du bottom sheet avec design coloré
class _PhotoSourcePickerContent extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final bool showCamera;

  const _PhotoSourcePickerContent({
    this.title,
    this.subtitle,
    required this.showCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ═══════════════════════════════════════════════════
            // 📋 HEADER
            // ═══════════════════════════════════════════════════
            if (title != null || subtitle != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ═══════════════════════════════════════════════════
            // 🎯 OPTIONS COLORÉES
            // ═══════════════════════════════════════════════════
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // 📷 CAMERA (Android uniquement)
                  if (showCamera)
                    Expanded(
                      child: _ColorfulOptionCard(
                        icon: Icons.camera_alt_rounded,
                        label: 'Caméra',
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        ),
                        onTap: () => Navigator.pop(context, PhotoSource.camera),
                      ),
                    ),

                  if (showCamera) const SizedBox(width: 12),

                  // 🖼️ GALERIE
                  Expanded(
                    child: _ColorfulOptionCard(
                      icon: Icons.photo_library_rounded,
                      label: 'Galerie',
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
                      ),
                      onTap: () => Navigator.pop(context, PhotoSource.gallery),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ═══════════════════════════════════════════════════
            // ❌ BOUTON ANNULER
            // ═══════════════════════════════════════════════════
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  child: const Text(
                    'Annuler',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🌈 Card colorée avec gradient et ombre
class _ColorfulOptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ColorfulOptionCard({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône avec cercle blanc
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Label
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
