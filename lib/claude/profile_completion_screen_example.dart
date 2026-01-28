// lib/screens/profile_completion_screen.dart - ✅ EXEMPLE COMPLET OPTIMISÉ
// Écran de complétion de profil utilisant la nouvelle architecture

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/photo_item.dart';
import '../providers/photos_provider.dart';
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
    final userId = services.supabaseService.currentUserId;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Utilisateur non connecté')),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => PhotosProvider(userId: userId),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complétez votre profil'),
          actions: [
            // ✅ Bouton refresh
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
      ),
    );
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
          // Avatar
          GestureDetector(
            onTap: () => _pickProfilePhoto(context, photosProvider),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300],
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
              ),
              child: profilePhoto != null
                  ? _buildProfileImage(profilePhoto)
                  : const Icon(Icons.person, size: 60, color: Colors.grey),
            ),
          ),
          
          // Bouton edit
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                onPressed: () => _pickProfilePhoto(context, photosProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage(PhotoItem photo) {
    if (photo.isLocal && photo.localFile != null) {
      return ClipOval(
        child: Image.file(
          photo.localFile!,
          fit: BoxFit.cover,
          width: 120,
          height: 120,
        ),
      );
    }

    if (photo.remotePath != null) {
      final url = services.photoUrlHelper.buildPhotoUrl(photo.remotePath!);
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          width: 120,
          height: 120,
          placeholder: (_, __) => const CircularProgressIndicator(),
          errorWidget: (_, __, ___) => const Icon(Icons.error),
        ),
      );
    }

    return const Icon(Icons.person, size: 60);
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
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: canAddMore ? galleryPhotos.length + 1 : galleryPhotos.length,
      itemBuilder: (context, index) {
        // Bouton ajouter
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
    return GestureDetector(
      onTap: () => _pickGalleryPhoto(context, photosProvider),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[400]!, width: 2),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('Ajouter', style: TextStyle(color: Colors.grey)),
          ],
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
        // Image
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: photo.isLocal && photo.localFile != null
              ? Image.file(photo.localFile!, fit: BoxFit.cover)
              : photo.remotePath != null
                  ? CachedNetworkImage(
                      imageUrl: services.photoUrlHelper
                          .buildPhotoUrl(photo.remotePath!),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.error),
                      ),
                    )
                  : Container(color: Colors.grey[300]),
        ),

        // Badge statut
        if (photo.isPending)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'EN ATTENTE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Bouton supprimer
        Positioned(
          top: 4,
          right: 4,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => _deletePhoto(context, photo, photosProvider),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(PhotosProvider photosProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatRow('Total', photosProvider.totalPhotos.toString()),
            const Divider(),
            _buildStatRow('Approuvées', photosProvider.approvedCount.toString()),
            const Divider(),
            _buildStatRow('En attente', photosProvider.pendingCount.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: canSubmit && !_isUploading
            ? () => _submitProfile(context, photosProvider)
            : null,
        child: _isUploading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Valider le profil'),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🎬 ACTIONS
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _pickProfilePhoto(
    BuildContext context,
    PhotosProvider photosProvider,
  ) async {
    // Utiliser ImageService pour picker l'image
    final imageFile = await services.imageService.captureFromCamera();

    if (imageFile == null) return;

    // Ajouter localement
    photosProvider.addLocalPhoto(
      file: imageFile,
      type: 'profile',
      hasWatermark: true,
    );

    // Upload
    final localPhoto = photosProvider.profilePhotos
        .firstWhere((p) => p.needsUpload);
    
    await photosProvider.uploadPhoto(localPhoto);
  }

  Future<void> _pickGalleryPhoto(
    BuildContext context,
    PhotosProvider photosProvider,
  ) async {
    final imageFile = await services.imageService.pickFromGallery();

    if (imageFile == null) return;

    photosProvider.addLocalPhoto(
      file: imageFile,
      type: 'gallery',
      hasWatermark: false,
    );

    final localPhoto = photosProvider.galleryPhotos
        .firstWhere((p) => p.needsUpload);
    
    await photosProvider.uploadPhoto(localPhoto);
  }

  Future<void> _deletePhoto(
    BuildContext context,
    PhotoItem photo,
    PhotosProvider photosProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la photo ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
      // Upload toutes les photos locales d'abord
      await photosProvider.uploadAllLocalPhotos();

      // Marquer le profil comme complété
      await services.supabaseService.updateCurrentUserData({
        'profile_completed': true,
        'completion_percentage': 100,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profil validé avec succès !'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigation vers la home
      // Navigator.pushReplacementNamed(context, '/home');

    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
}
