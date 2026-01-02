// lib/features/moderator/screens/moderator_panel_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class ModeratorPanelScreen extends StatefulWidget {
  const ModeratorPanelScreen({super.key});

  @override
  State<ModeratorPanelScreen> createState() => _ModeratorPanelScreenState();
}

class _ModeratorPanelScreenState extends State<ModeratorPanelScreen> {
  final _supabase = Supabase.instance.client;
  final _pageController = PageController();
  
  List<Map<String, dynamic>> _pendingPhotos = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadPendingPhotos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingPhotos() async {
    setState(() => _isLoading = true);

    try {
      final photos = await _supabase
          .from('photos')
          .select('''
            *,
            profiles:user_id (
              full_name,
              email,
              date_of_birth,
              gender,
              city,
              country
            )
          ''')
          .eq('status', 'pending')
          .order('uploaded_at', ascending: true)
          .limit(50);

      setState(() {
        _pendingPhotos = List<Map<String, dynamic>>.from(photos);
        _isLoading = false;
        _currentIndex = 0;
      });
    } catch (e) {
      debugPrint('Load photos error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approvePhoto() async {
    if (_isProcessing || _pendingPhotos.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final currentPhoto = _pendingPhotos[_currentIndex];
      final moderatorId = _supabase.auth.currentUser!.id;

      // Update photo status
      await _supabase
          .from('photos')
          .update({
            'status': 'approved',
            'moderated_at': DateTime.now().toIso8601String(),
            'moderator_id': moderatorId,
          })
          .eq('id', currentPhoto['id']);

      // Créer notification pour l'utilisateur
      await _supabase.from('notifications').insert({
        'user_id': currentPhoto['user_id'],
        'type': 'photo_approved',
        'title': 'Photo approuvée',
        'body': 'Votre photo a été approuvée et est maintenant visible',
        'created_at': DateTime.now().toIso8601String(),
      });

      _removeCurrentPhoto();
    } catch (e) {
      debugPrint('Approve error: $e');
      _showErrorSnackbar('Erreur lors de l\'approbation');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectPhoto(String reason) async {
    if (_isProcessing || _pendingPhotos.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final currentPhoto = _pendingPhotos[_currentIndex];
      final moderatorId = _supabase.auth.currentUser!.id;

      // Update photo status
      await _supabase
          .from('photos')
          .update({
            'status': 'rejected',
            'moderated_at': DateTime.now().toIso8601String(),
            'moderator_id': moderatorId,
            'rejection_reason': reason,
          })
          .eq('id', currentPhoto['id']);

      // Créer notification pour l'utilisateur
      await _supabase.from('notifications').insert({
        'user_id': currentPhoto['user_id'],
        'type': 'photo_rejected',
        'title': 'Photo rejetée',
        'body': 'Votre photo a été rejetée : $reason',
        'created_at': DateTime.now().toIso8601String(),
      });

      _removeCurrentPhoto();
    } catch (e) {
      debugPrint('Reject error: $e');
      _showErrorSnackbar('Erreur lors du rejet');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _removeCurrentPhoto() {
    setState(() {
      _pendingPhotos.removeAt(_currentIndex);
      if (_currentIndex >= _pendingPhotos.length && _currentIndex > 0) {
        _currentIndex--;
      }
    });

    if (_pendingPhotos.isEmpty) {
      Navigator.pop(context);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showRejectDialog() {
    final reasons = [
      'Contenu inapproprié',
      'Photo de mauvaise qualité',
      'Pas de visage visible',
      'Photo ne respecte pas les règles',
      'Autre',
    ];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Raison du rejet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...reasons.map((reason) => ListTile(
              title: Text(reason),
              onTap: () {
                Navigator.pop(ctx);
                _rejectPhoto(reason);
              },
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          _pendingPhotos.isEmpty
              ? 'Aucune photo en attente'
              : '${_currentIndex + 1} / ${_pendingPhotos.length}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingPhotos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _pendingPhotos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 80,
                        color: Colors.green[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Toutes les photos sont modérées',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemCount: _pendingPhotos.length,
                  itemBuilder: (context, index) {
                    return _buildPhotoCard(_pendingPhotos[index], theme);
                  },
                ),
      bottomNavigationBar: _pendingPhotos.isEmpty || _isProcessing
          ? null
          : Container(
              color: Colors.black,
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showRejectDialog,
                      icon: const Icon(Icons.close),
                      label: const Text('Rejeter'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _approvePhoto,
                      icon: const Icon(Icons.check),
                      label: const Text('Approuver'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPhotoCard(Map<String, dynamic> photo, ThemeData theme) {
    final profile = photo['profiles'];
    final uploadedAt = DateTime.parse(photo['uploaded_at']);

    return Column(
      children: [
        // Photo
        Expanded(
          child: Center(
            child: CachedNetworkImage(
              imageUrl: photo['remote_path'],
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (_, __, ___) => const Center(
                child: Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 48,
                ),
              ),
            ),
          ),
        ),

        // User Info
        Container(
          color: Colors.black87,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      (profile['full_name'] ?? profile['email'])[0]
                          .toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile['full_name'] ?? profile['email'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${profile['city'] ?? ''}, ${profile['country'] ?? ''}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text(profile['gender'] ?? 'N/A'),
                    backgroundColor: Colors.blue.withOpacity(0.3),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                  if (profile['date_of_birth'] != null)
                    Chip(
                      label: Text(
                        '${_calculateAge(DateTime.parse(profile['date_of_birth']))} ans',
                      ),
                      backgroundColor: Colors.green.withOpacity(0.3),
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  Chip(
                    label: Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(uploadedAt),
                    ),
                    backgroundColor: Colors.orange.withOpacity(0.3),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              if (photo['has_watermark']) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.verified, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Photo caméra avec watermark',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}