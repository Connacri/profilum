// lib/screens/moderation_detail_screen.dart - ✅ NOUVEAU
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_image_service.dart';

class ModerationDetailScreen extends StatefulWidget {
  final String status; // 'pending', 'rejected', 'approved'

  const ModerationDetailScreen({super.key, required this.status});

  @override
  State<ModerationDetailScreen> createState() => _ModerationDetailScreenState();
}

class _ModerationDetailScreenState extends State<ModerationDetailScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _photos = [];
  int _page = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String? _profileImageUrl;
  bool _isLoadingImage = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    try {
      setState(() => _isLoadingImage = true);

      // Charger l'URL de l'image de profil
      final url = await context
          .read<ProfileImageService>()
          .getCurrentUserProfileImage();

      if (!mounted) return;

      setState(() {
        _profileImageUrl = url;
        _isLoadingImage = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Erreur: $e';
        _isLoadingImage = false;
      });
    }
  }

  Future<void> _loadPhotos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final photos = await _supabase
          .from('photos')
          .select(
            'id, user_id, remote_path, uploaded_at, status, type, rejection_reason, profiles!photos_user_id_fkey(id, full_name, email, gender, city, bio, date_of_birth)',
          )
          .eq('status', widget.status)
          .not('remote_path', 'is', null)
          .order('uploaded_at', ascending: false)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1);

      // ✅ Construire les URLs
      final photosWithUrls = photos.map<Map<String, dynamic>>((p) {
        final url = _buildPhotoUrl(p['remote_path'] as String);
        return {...p, 'url': url};
      }).toList();

      _hasMore = photos.length == _pageSize;

      if (!mounted) return;
      setState(() {
        _photos = photosWithUrls;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMorePhotos() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    _page++;

    try {
      final photos = await _supabase
          .from('photos')
          .select(
            'id, user_id, remote_path, uploaded_at, status, type, rejection_reason, profiles!photos_user_id_fkey(id, full_name, email, gender, city, bio, date_of_birth)',
          )
          .eq('status', widget.status)
          .not('remote_path', 'is', null)
          .order('uploaded_at', ascending: false)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1);

      final photosWithUrls = photos.map<Map<String, dynamic>>((p) {
        final url = _buildPhotoUrl(p['remote_path'] as String);
        return {...p, 'url': url};
      }).toList();

      _hasMore = photos.length == _pageSize;

      if (mounted) {
        setState(() {
          _photos.addAll(photosWithUrls);
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Load more error: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  String _buildPhotoUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final cleanPath = path
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+'), '/');
    return _supabase.storage.from('profiles').getPublicUrl(cleanPath);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor();
    final statusLabel = _getStatusLabel();

    return Scaffold(
      appBar: AppBar(
        title: Text(statusLabel),
        backgroundColor: statusColor.withOpacity(0.1),
        foregroundColor: statusColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
          ? _buildEmptyState(theme, statusColor)
          : _buildPhotosList(theme),
    );
  }

  /// 📊 En-tête avec infos
  Widget _buildHeader(ThemeData theme) {
    final statusColor = _getStatusColor();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: statusColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(_getStatusIcon(), color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusLabel(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                Text(
                  '${_photos.length} photo${_photos.length > 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: _loadPhotos,
            style: FilledButton.styleFrom(
              backgroundColor: statusColor.withOpacity(0.2),
              foregroundColor: statusColor,
            ),
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosList(ThemeData theme) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(child: _buildHeader(theme)),

        // Photos
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index == _photos.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: _isLoadingMore
                        ? const CircularProgressIndicator()
                        : _hasMore
                        ? OutlinedButton.icon(
                            onPressed: _loadMorePhotos,
                            icon: const Icon(Icons.expand_more),
                            label: const Text('Charger plus'),
                          )
                        : const SizedBox.shrink(),
                  ),
                );
              }
              return _buildPhotoItem(theme, _photos[index]);
            }, childCount: _photos.length + (_hasMore ? 1 : 0)),
          ),
        ),
      ],
    );
  }

  /// 📸 Carte photo détaillée
  Widget _buildPhotoItem(ThemeData theme, Map<String, dynamic> photo) {
    final profile = photo['profiles'];
    final userName = profile?['full_name'] ?? profile?['email'] ?? 'Inconnu';
    final userEmail = profile?['email'] ?? '';
    final userCity = profile?['city'] ?? '';
    final photoUrl = photo['url'] as String;
    final status = photo['status'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: CachedNetworkImage(
              imageUrl: photoUrl,
              fit: BoxFit.cover,
              height: 280,
              width: double.infinity,
              placeholder: (_, __) => Container(
                height: 280,
                color: theme.colorScheme.surfaceVariant,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 280,
                color: theme.colorScheme.errorContainer,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 8),
                    Text('Erreur chargement', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),

          // Infos
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Utilisateur
                Row(
                  children: [
                    _buildUserAvatar(
                      userId: profile?['id'] as String? ?? '',
                      userName: userName,
                      radius: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (userCity.isNotEmpty)
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  userCity,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Métadonnées
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat(
                        'dd/MM/yyyy HH:mm',
                      ).format(DateTime.parse(photo['uploaded_at'])),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(),
                        ),
                      ),
                    ),
                  ],
                ),

                // Raison rejet si applicable
                if (status == 'rejected' && photo['rejection_reason'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Raison du rejet:',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            photo['rejection_reason'],
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Boutons d'action
                _buildActionButtons(theme, photo),

                const SizedBox(height: 12),

                // Bouton voir profil
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showUserProfile(context, theme, profile),
                    icon: const Icon(Icons.person),
                    label: const Text('Voir le profil'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🎯 Boutons d'action selon le statut
  Widget _buildActionButtons(ThemeData theme, Map<String, dynamic> photo) {
    final status = photo['status'] as String;

    if (status == 'approved') {
      // Photos approuvées: reject ou delete
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _rejectPhoto(photo),
              icon: const Icon(Icons.block, size: 18),
              label: const Text('Rejeter'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _deletePhoto(photo),
              icon: const Icon(Icons.delete, size: 18),
              label: const Text('Supprimer'),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
            ),
          ),
        ],
      );
    } else if (status == 'rejected') {
      // Photos rejetées: approve ou delete
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _approvePhoto(photo),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Approuver'),
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _deletePhoto(photo),
              icon: const Icon(Icons.delete, size: 18),
              label: const Text('Supprimer'),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
            ),
          ),
        ],
      );
    } else {
      // Photos pending: approve ou reject
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _rejectPhoto(photo),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Rejeter'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _approvePhoto(photo),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Approuver'),
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
            ),
          ),
        ],
      );
    }
  }

  /// 👤 Afficher profil utilisateur
  void _showUserProfile(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> profile,
  ) {
    final userName = profile?['full_name'] ?? 'Inconnu';
    final userEmail = profile?['email'] ?? '';
    final userGender = profile?['gender'] ?? '';
    final userCity = profile?['city'] ?? '';
    final userBio = profile?['bio'] ?? '';
    final birthDate = profile?['date_of_birth'];

    int? age;
    if (birthDate != null) {
      final bd = DateTime.tryParse(birthDate);
      if (bd != null) {
        final now = DateTime.now();
        age = now.year - bd.year;
        if (now.month < bd.month ||
            (now.month == bd.month && now.day < bd.day)) {
          age--;
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Avatar
              Center(
                child: _buildUserAvatar(
                  userId: profile['id'] as String? ?? '',
                  userName: userName,
                  radius: 24,
                ),
              ),
              const SizedBox(height: 16),

              // Nom
              Center(
                child: Text(
                  userName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Infos
              const SizedBox(height: 24),
              _buildProfileInfo('Email', userEmail, Icons.email),
              if (age != null) _buildProfileInfo('Âge', '$age ans', Icons.cake),
              if (userGender.isNotEmpty)
                _buildProfileInfo('Genre', userGender, Icons.person),
              if (userCity.isNotEmpty)
                _buildProfileInfo('Ville', userCity, Icons.location_on),

              // Bio
              if (userBio.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Bio',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(userBio, style: theme.textTheme.bodyMedium),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfo(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🗑️ Supprimer photo
  Future<void> _deletePhoto(Map<String, dynamic> photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la photo'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer cette photo ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase.from('photos').delete().eq('id', photo['id']);

      if (mounted) {
        setState(() => _photos.removeWhere((p) => p['id'] == photo['id']));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Photo supprimée'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Delete error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// ✅ Approuver photo
  Future<void> _approvePhoto(Map<String, dynamic> photo) async {
    try {
      final moderatorId = _supabase.auth.currentUser!.id;
      await _supabase
          .from('photos')
          .update({
            'status': 'approved',
            'moderated_at': DateTime.now().toIso8601String(),
            'moderator_id': moderatorId,
          })
          .eq('id', photo['id']);

      if (mounted) {
        setState(() => _photos.removeWhere((p) => p['id'] == photo['id']));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Photo approuvée'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Approve error: $e');
    }
  }

  /// ❌ Rejeter photo
  Future<void> _rejectPhoto(Map<String, dynamic> photo) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Raison du rejet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children:
              [
                    'Contenu inapproprié',
                    'Mauvaise qualité',
                    'Pas de visage',
                    'Duplicate',
                    'Autre',
                  ]
                  .map(
                    (r) => ListTile(
                      title: Text(r),
                      onTap: () => Navigator.pop(ctx, r),
                    ),
                  )
                  .toList(),
        ),
      ),
    );

    if (reason == null) return;

    try {
      final moderatorId = _supabase.auth.currentUser!.id;
      await _supabase
          .from('photos')
          .update({
            'status': 'rejected',
            'moderated_at': DateTime.now().toIso8601String(),
            'moderator_id': moderatorId,
            'rejection_reason': reason,
          })
          .eq('id', photo['id']);

      if (mounted) {
        setState(() => _photos.removeWhere((p) => p['id'] == photo['id']));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Photo rejetée: $reason'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Reject error: $e');
    }
  }

  Widget _buildEmptyState(ThemeData theme, Color statusColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getStatusIcon(), size: 80, color: statusColor.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Aucune photo ${widget.status}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Il n\'y a rien à modérer pour le moment',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadPhotos,
            icon: const Icon(Icons.refresh),
            label: const Text('Rafraîchir'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (widget.status) {
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'approved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'rejected':
        return Icons.cloud_circle;
      case 'approved':
        return Icons.check_circle;
      default:
        return Icons.image;
    }
  }

  String _getStatusLabel() {
    switch (widget.status) {
      case 'pending':
        return 'Photos en attente';
      case 'rejected':
        return 'Photos rejetées';
      case 'approved':
        return 'Photos approuvées';
      default:
        return widget.status;
    }
  }

  /// 🖼️ Widget pour afficher l'image de profil d'un utilisateur
  Widget _buildUserAvatar({
    required String userId,
    required String userName,
    double radius = 20,
  }) {
    return FutureBuilder<String?>(
      future: context.read<ProfileImageService>().getUserProfileImage(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final imageUrl = snapshot.data;
        if (imageUrl == null || imageUrl.isEmpty) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey[300],
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
                color: Colors.grey[600],
              ),
            ),
          );
        }

        return CircleAvatar(
          radius: radius,
          backgroundImage: CachedNetworkImageProvider(imageUrl),
          onBackgroundImageError: (exception, stackTrace) {
            debugPrint('❌ Failed to load avatar: $imageUrl');
          },
        );
      },
    );
  }
}
