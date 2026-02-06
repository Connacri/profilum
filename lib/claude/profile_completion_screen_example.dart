import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/photos_provider.dart';

import '../widgets/photo_source_picker_final.dart';
import 'photo_item.dart';
import 'service_locator.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {



    return  Scaffold(
        appBar: AppBar(
          title: const Text('Complétez votre profil'),
          actions: [
            Consumer<PhotosProvider>(
              builder: (context, photosProvider, _) {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => photosProvider.refresh(),
                );
              },
            ),
          ],
        ),
        body: Consumer<PhotosProvider>(
          builder: (context, photosProvider, _) {
            if (photosProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (photosProvider.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(photosProvider.error ?? 'Erreur inconnue'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => photosProvider.refresh(),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ═══════════════════════════════════════════════════
                  // 📸 PHOTO DE PROFIL
                  // ═══════════════════════════════════════════════════

                  _buildSectionTitle('Photo de profil'),
                  const SizedBox(height: 16),

                  _buildProfilePhotoSection(context, photosProvider),

                  const SizedBox(height: 32),

                  // ═══════════════════════════════════════════════════
                  // 🖼️ GALERIE PHOTOS
                  // ═══════════════════════════════════════════════════

                  _buildSectionTitle('Galerie (${photosProvider.galleryPhotos.length}/6)'),
                  const SizedBox(height: 16),

                  _buildGallerySection(context, photosProvider),

                  const SizedBox(height: 32),

                  // ═══════════════════════════════════════════════════
                  // 📊 STATISTIQUES
                  // ═══════════════════════════════════════════════════

                  _buildStatsSection(photosProvider),

                  const SizedBox(height: 32),

                  // ═══════════════════════════════════════════════════
                  // ✅ BOUTON VALIDER
                  // ═══════════════════════════════════════════════════

                  _buildSubmitButton(context, photosProvider),
                ],
              ),
            );
          },
        ),
      ) ;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🏗️ BUILDERS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildProfilePhotoSection(
      BuildContext context,
      PhotosProvider photosProvider,
      ) {
    final profilePhoto = photosProvider.approvedProfilePhoto;

    return Center(
      child: Stack(
        children: [
          // Avatar avec effet gradient
          GestureDetector(
            onTap: () => _handleProfilePhotoTap(context, photosProvider),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: profilePhoto == null
                    ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: (profilePhoto == null
                        ? const Color(0xFF667EEA)
                        : Theme.of(context).colorScheme.primary)
                        .withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: ClipOval(
                  child: profilePhoto != null
                      ? _buildProfileImage(profilePhoto)
                      : Center(
                    child: Icon(
                      Icons.person_rounded,
                      size: 70,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bouton edit avec gradient
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleProfilePhotoTap(context, photosProvider),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage(PhotoItem photo) {
    if (photo.isLocal && photo.localFile != null) {
      return Image.file(
        photo.localFile!,
        fit: BoxFit.cover,
        width: 132,
        height: 132,
      );
    }

    if (photo.remotePath != null) {
      final url = services.photoUrlHelper.buildPhotoUrl(photo.remotePath!);
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: 132,
        height: 132,
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (_, __, ___) => const Icon(Icons.error, color: Colors.red),
      );
    }

    return const Icon(Icons.person_rounded, size: 70);
  }

  Widget _buildGallerySection(
      BuildContext context,
      PhotosProvider photosProvider,
      ) {
    final galleryPhotos = photosProvider.galleryPhotos;
    final canAddMore = galleryPhotos.length < 6;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: canAddMore ? galleryPhotos.length + 1 : galleryPhotos.length,
      itemBuilder: (context, index) {
        if (canAddMore && index == galleryPhotos.length) {
          return _buildAddPhotoButton(context, photosProvider);
        }

        final photo = galleryPhotos[index];
        return _buildPhotoCard(context, photo, photosProvider);
      },
    );
  }

  Widget _buildAddPhotoButton(
      BuildContext context,
      PhotosProvider photosProvider,
      ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleGalleryPhotoTap(context, photosProvider),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFF093FB).withOpacity(0.15),
                const Color(0xFFF5576C).withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFF093FB).withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ajouter',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF5576C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCard(
      BuildContext context,
      PhotoItem photo,
      PhotosProvider photosProvider,
      ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Image avec coins arrondis
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: photo.isLocal && photo.localFile != null
              ? Image.file(photo.localFile!, fit: BoxFit.cover)
              : photo.remotePath != null
              ? CachedNetworkImage(
            imageUrl: services.photoUrlHelper
                .buildPhotoUrl(photo.remotePath!),
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey[300]!,
                    Colors.grey[400]!,
                  ],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.error),
            ),
          )
              : Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.grey[300]!, Colors.grey[400]!],
              ),
            ),
          ),
        ),

        // Badge statut avec gradient
        if (photo.isPending)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9A56), Color(0xFFFF6B6B)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF9A56).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'EN ATTENTE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

        // Bouton supprimer avec gradient
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFF5252)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B6B).withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _deletePhoto(context, photo, photosProvider),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(PhotosProvider photosProvider) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildStatRow(
              'Total',
              photosProvider.totalPhotos.toString(),
              Icons.photo_library_rounded,
              const Color(0xFF667EEA),
            ),
            const Divider(height: 24),
            _buildStatRow(
              'Approuvées',
              photosProvider.approvedCount.toString(),
              Icons.check_circle_rounded,
              Colors.green,
            ),
            const Divider(height: 24),
            _buildStatRow(
              'En attente',
              photosProvider.pendingCount.toString(),
              Icons.schedule_rounded,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(
      BuildContext context,
      PhotosProvider photosProvider,
      ) {
    final canSubmit = photosProvider.hasApprovedProfilePhoto &&
        photosProvider.approvedCount >= 3;

    return Container(
      decoration: BoxDecoration(
        gradient: canSubmit
            ? const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        )
            : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: canSubmit
            ? [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canSubmit && !_isUploading
              ? () => _submitProfile(context, photosProvider)
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: _isUploading
                  ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Text(
                'Valider le profil',
                style: TextStyle(
                  color: canSubmit ? Colors.white : Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🎬 ACTIONS - AVEC BOTTOM SHEET COLORÉ
  // ═══════════════════════════════════════════════════════════════════

  /// ✅ Handler pour la photo de profil (UNE SEULE PHOTO)
  Future<void> _handleProfilePhotoTap(
      BuildContext context,
      PhotosProvider photosProvider,
      ) async {
    final source = await PhotoSourcePicker.show(
      context,
      title: 'Photo de profil',
      subtitle: 'Choisissez votre plus belle photo',
    );

    if (source == null) return;

    await _pickSinglePhoto(
      context,
      photosProvider,
      source,
      photoType: 'profile',
    );
  }

  /// ✅ Handler pour les photos de galerie (UNE SEULE PHOTO à la fois)
  Future<void> _handleGalleryPhotoTap(
      BuildContext context,
      PhotosProvider photosProvider,
      ) async {
    final source = await PhotoSourcePicker.show(
      context,
      title: 'Ajouter une photo',
      subtitle: 'Galerie (${photosProvider.galleryPhotos.length}/6)',
    );

    if (source == null) return;

    await _pickSinglePhoto(
      context,
      photosProvider,
      source,
      photoType: 'gallery',
    );
  }

  /// 📸 Ajouter UNE SEULE photo (profile ou gallery)
  Future<void> _pickSinglePhoto(
      BuildContext context,
      PhotosProvider photosProvider,
      PhotoSource source, {
        required String photoType,
      }) async {
    // ✅ Capturer UNE SEULE image
    File? imageFile;

    if (source == PhotoSource.camera) {
      imageFile = await services.imageService.captureFromCamera();
    } else {
      // ✅ Galerie : UNE SEULE image (pas pickMultiple)
      imageFile = await services.imageService.pickFromGallery();
    }

    if (imageFile == null) return;

    // Ajouter localement
    photosProvider.addLocalPhoto(
      file: imageFile,
      type: photoType,
      hasWatermark: source == PhotoSource.camera, // ✅ Watermark uniquement caméra
    );

    // Upload
    final localPhoto = photoType == 'profile'
        ? photosProvider.profilePhotos.firstWhere((p) => p.needsUpload)
        : photosProvider.galleryPhotos.firstWhere((p) => p.needsUpload);

    final success = await photosProvider.uploadPhoto(localPhoto);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                success
                    ? photoType == 'profile'
                    ? '✅ Photo de profil ajoutée'
                    : '✅ Photo ajoutée (${photosProvider.galleryPhotos.length}/6)'
                    : '❌ Erreur lors de l\'ajout',
              ),
            ),
          ],
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deletePhoto(
      BuildContext context,
      PhotoItem photo,
      PhotosProvider photosProvider,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 12),
            Text('Supprimer la photo ?'),
          ],
        ),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (photo.isLocal) {
      photosProvider.deleteLocalPhoto(photo.id);
    } else {
      await photosProvider.deletePhoto(photo.id);
    }
  }

  Future<void> _submitProfile(
      BuildContext context,
      PhotosProvider photosProvider,
      ) async {
    setState(() => _isUploading = true);

    try {
      await photosProvider.uploadAllLocalPhotos();

      await services.supabaseService.updateCurrentUserData({
        'profile_completed': true,
        'completion_percentage': 100,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.celebration, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('✅ Profil validé avec succès !')),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      // Navigator.pushReplacementNamed(context, '/home');

    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('❌ Erreur: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
}