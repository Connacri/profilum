// // lib/screens/profile_completion_screen.dart
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
//
// import '../models/photo_item.dart';
// import '../models/social_link_model.dart';
// import '../providers/auth_provider.dart';
// import '../providers/profile_completion_provider.dart';
// import '../widgets/photo_grid_item_with_badge.dart';
//
// class ProfileCompletionScreen extends StatefulWidget {
//   const ProfileCompletionScreen({super.key});
//
//   @override
//   State<ProfileCompletionScreen> createState() =>
//       _ProfileCompletionScreenState();
// }
//
// class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
//   final _pageController = PageController();
//   int _currentPage = 0;
//   final int _totalPages = 6;
//   late final SupabaseClient _supabase;
//
//   // Controllers
//   final _nameController = TextEditingController();
//   final _bioController = TextEditingController();
//   final _cityController = TextEditingController();
//   final _occupationController = TextEditingController();
//   final _socialLinkController = TextEditingController();
//
//   // Form data
//   String? _selectedGender;
//   String? _selectedLookingFor;
//   DateTime? _selectedDate;
//   int? _selectedHeight;
//   String? _selectedEducation;
//   String? _selectedRelationship;
//   List<String> _selectedInterests = [];
//   List<SocialLink> _socialLinks = [];
//
//   // State
//   bool _isLoadingLocation = false;
//   bool _isSkipping = false;
//
//   final List<String> _availableInterests = [
//     'Sport',
//     'Musique',
//     'Voyages',
//     'Cuisine',
//     'Art',
//     'Cinéma',
//     'Lecture',
//     'Gaming',
//     'Nature',
//     'Technologie',
//     'Danse',
//     'Photographie',
//     'Mode',
//     'Yoga',
//     'Méditation',
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     _supabase = context.read<SupabaseClient>();
//     final authProvider = context.read<AuthProvider>();
//     final user = authProvider.currentUser;
//
//     if (user != null) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (!mounted) return;
//         context.read<ProfileCompletionProvider>().initialize(user);
//       });
//       // Charger les données existantes
//       _nameController.text = user.fullName ?? '';
//       _bioController.text = user.bio ?? '';
//       _cityController.text = user.city ?? '';
//       _occupationController.text = user.occupation ?? '';
//       _socialLinks = List.from(user.socialLinks);
//       _selectedGender = user.gender;
//       _selectedLookingFor = user.lookingFor;
//       _selectedDate = user.dateOfBirth;
//       _selectedHeight = user.heightCm;
//       _selectedEducation = user.education;
//       _selectedRelationship = user.relationshipStatus;
//       _selectedInterests = List.from(user.interests);
//     }
//   }
//
//   @override
//   void dispose() {
//     _pageController.dispose();
//     _nameController.dispose();
//     _bioController.dispose();
//     _cityController.dispose();
//     _occupationController.dispose();
//     _socialLinkController.dispose();
//     super.dispose();
//   }
//
//   void _nextPage() {
//     if (_currentPage < _totalPages - 1) {
//       _pageController.nextPage(
//         duration: const Duration(milliseconds: 300),
//         curve: Curves.easeInOut,
//       );
//     }
//   }
//
//   void _previousPage() {
//     if (_currentPage > 0) {
//       _pageController.previousPage(
//         duration: const Duration(milliseconds: 300),
//         curve: Curves.easeInOut,
//       );
//     }
//   }
//
//   Future<void> _getLocation() async {
//     setState(() => _isLoadingLocation = true);
//
//     try {
//       await _showLocationDialog();
//     } catch (e) {
//       debugPrint('Location error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoadingLocation = false);
//       }
//     }
//   }
//
//   Future<void> _showLocationDialog() async {
//     final cityController = TextEditingController(text: _cityController.text);
//
//     final result = await showDialog<Map<String, String>>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Votre localisation'),
//         content: TextField(
//           controller: cityController,
//           decoration: InputDecoration(
//             labelText: 'Ville',
//             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text('Annuler'),
//           ),
//           FilledButton(
//             onPressed: () {
//               Navigator.pop(ctx, {
//                 'city': cityController.text,
//                 'country': 'Algérie',
//               });
//             },
//             child: const Text('Confirmer'),
//           ),
//         ],
//       ),
//     );
//
//     if (result != null) {
//       setState(() {
//         _cityController.text = result['city'] ?? '';
//       });
//     }
//   }
//
//   Future<void> _skip() async {
//     if (_isSkipping) return;
//
//     final confirmed = await showDialog<bool>(
//       context: context,
//       barrierDismissible: false,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Passer pour l\'instant ?'),
//         content: const Text(
//           'Vous pourrez compléter votre profil plus tard.\n\n'
//           'Note : Un profil complet augmente vos chances de match !',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx, false),
//             child: const Text('Annuler'),
//           ),
//           FilledButton(
//             onPressed: () => Navigator.pop(ctx, true),
//             child: const Text('Passer'),
//           ),
//         ],
//       ),
//     );
//
//     if (confirmed != true || !mounted) return;
//
//     setState(() => _isSkipping = true);
//
//     try {
//       final authProvider = context.read<AuthProvider>();
//       final success = await authProvider.skipProfileCompletion();
//
//       if (!success && mounted) {
//         setState(() => _isSkipping = false);
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Erreur lors du skip'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() => _isSkipping = false);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
//         );
//       }
//     }
//   }
//
//   Future<void> _complete() async {
//     if (_isSkipping) return;
//     setState(() => _isSkipping = true);
//
//     final provider = context.read<ProfileCompletionProvider>();
//     final authProvider = context.read<AuthProvider>();
//
//     // Mettre à jour les champs
//     provider.updateField('full_name', _nameController.text);
//     provider.updateField('bio', _bioController.text);
//     provider.updateField('city', _cityController.text);
//     provider.updateField('country', 'Algérie');
//     provider.updateField('occupation', _occupationController.text);
//     provider.updateField('gender', _selectedGender);
//     provider.updateField('looking_for', _selectedLookingFor);
//     provider.updateField('date_of_birth', _selectedDate);
//     provider.updateField('height_cm', _selectedHeight);
//     provider.updateField('education', _selectedEducation);
//     provider.updateField('relationship_status', _selectedRelationship);
//     provider.updateField('interests', _selectedInterests);
//     provider.updateField('social_links', _socialLinks);
//
//     // Sauvegarder
//     final success = await provider.saveProfile(isSkipped: false);
//
//     if (!mounted) return;
//
//     if (success) {
//       await authProvider.reloadCurrentUser();
//     } else {
//       setState(() => _isSkipping = false);
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('Erreur de sauvegarde')));
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         automaticallyImplyLeading: false,
//         actions: [
//           TextButton.icon(
//             onPressed: _isSkipping ? null : _skip,
//             icon: _isSkipping
//                 ? const SizedBox(
//                     width: 16,
//                     height: 16,
//                     child: CircularProgressIndicator(strokeWidth: 2),
//                   )
//                 : const Icon(Icons.skip_next),
//             label: Text(_isSkipping ? 'Chargement...' : 'Passer'),
//           ),
//           const SizedBox(width: 8),
//         ],
//       ),
//       body: PopScope(
//         canPop: !_isSkipping,
//         child: Column(
//           children: [
//             // Progress Bar
//             Consumer<ProfileCompletionProvider>(
//               builder: (context, provider, _) {
//                 return Padding(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 24,
//                     vertical: 16,
//                   ),
//                   child: Column(
//                     children: [
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Complétion du profil',
//                             style: theme.textTheme.titleMedium?.copyWith(
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           Text(
//                             '${provider.completionPercentage}%',
//                             style: theme.textTheme.titleMedium?.copyWith(
//                               fontWeight: FontWeight.bold,
//                               color: theme.colorScheme.primary,
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 8),
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(8),
//                         child: LinearProgressIndicator(
//                           value: provider.completionPercentage / 100,
//                           minHeight: 8,
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             ),
//
//             // Pages
//             Expanded(
//               child: PageView(
//                 controller: _pageController,
//                 physics: _isSkipping
//                     ? const NeverScrollableScrollPhysics()
//                     : null,
//                 onPageChanged: (index) {
//                   setState(() => _currentPage = index);
//                 },
//                 children: [
//                   _buildBasicInfoPage(),
//                   _buildProfilePhotoPage(),
//                   _buildGalleryPhotosPage(),
//                   _buildPersonalityPage(),
//                   _buildDetailsPage(),
//                   _buildInterestsPage(),
//                 ],
//               ),
//             ),
//
//             // Navigation Buttons
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Row(
//                 children: [
//                   if (_currentPage > 0)
//                     Expanded(
//                       child: OutlinedButton(
//                         onPressed: _isSkipping ? null : _previousPage,
//                         child: const Text('Précédent'),
//                       ),
//                     ),
//                   if (_currentPage > 0) const SizedBox(width: 16),
//                   Expanded(
//                     flex: 2,
//                     child: FilledButton(
//                       onPressed: _isSkipping
//                           ? null
//                           : (_currentPage == _totalPages - 1
//                                 ? _complete
//                                 : _nextPage),
//                       child: _isSkipping
//                           ? const SizedBox(
//                               width: 20,
//                               height: 20,
//                               child: CircularProgressIndicator(
//                                 strokeWidth: 2,
//                                 color: Colors.white,
//                               ),
//                             )
//                           : Text(
//                               _currentPage == _totalPages - 1
//                                   ? 'Terminer'
//                                   : 'Suivant',
//                             ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildBasicInfoPage() {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(24),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           Text(
//             'Informations de base',
//             style: Theme.of(
//               context,
//             ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Les champs marqués * sont obligatoires',
//             style: Theme.of(
//               context,
//             ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
//           ),
//           const SizedBox(height: 24),
//
//           TextField(
//             controller: _nameController,
//             decoration: InputDecoration(
//               labelText: 'Nom complet *',
//               hintText: 'Entrez votre nom',
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               prefixIcon: const Icon(Icons.person),
//             ),
//             textCapitalization: TextCapitalization.words,
//           ),
//
//           const SizedBox(height: 16),
//
//           InkWell(
//             onTap: () async {
//               final date = await showDatePicker(
//                 context: context,
//                 initialDate: _selectedDate ?? DateTime(2000),
//                 firstDate: DateTime(1950),
//                 lastDate: DateTime.now().subtract(
//                   const Duration(days: 365 * 18),
//                 ),
//                 helpText: 'Sélectionnez votre date de naissance',
//               );
//               if (date != null) {
//                 setState(() => _selectedDate = date);
//               }
//             },
//             child: InputDecorator(
//               decoration: InputDecoration(
//                 labelText: 'Date de naissance *',
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 prefixIcon: const Icon(Icons.calendar_today),
//               ),
//               child: Text(
//                 _selectedDate != null
//                     ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
//                     : 'Sélectionner votre date',
//                 style: TextStyle(
//                   color: _selectedDate != null ? null : Colors.grey[600],
//                 ),
//               ),
//             ),
//           ),
//
//           const SizedBox(height: 16),
//
//           DropdownButtonFormField<String>(
//             value: _selectedGender,
//             decoration: InputDecoration(
//               labelText: 'Genre *',
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               prefixIcon: const Icon(Icons.wc),
//             ),
//             hint: const Text('Sélectionnez votre genre'),
//             items: const [
//               DropdownMenuItem(value: 'male', child: Text('Homme')),
//               DropdownMenuItem(value: 'female', child: Text('Femme')),
//               DropdownMenuItem(value: 'mtf', child: Text('MTF')),
//               DropdownMenuItem(value: 'ftm', child: Text('FTM')),
//             ],
//             onChanged: (value) => setState(() => _selectedGender = value),
//           ),
//
//           const SizedBox(height: 16),
//
//           DropdownButtonFormField<String>(
//             value: _selectedLookingFor,
//             decoration: InputDecoration(
//               labelText: 'Vous recherchez *',
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               prefixIcon: const Icon(Icons.favorite),
//             ),
//             hint: const Text('Qui souhaitez-vous rencontrer ?'),
//             items: const [
//               DropdownMenuItem(value: 'male', child: Text('Hommes')),
//               DropdownMenuItem(value: 'female', child: Text('Femmes')),
//               DropdownMenuItem(value: 'everyone', child: Text('Tout le monde')),
//             ],
//             onChanged: (value) => setState(() => _selectedLookingFor = value),
//           ),
//
//           const SizedBox(height: 16),
//
//           Row(
//             children: [
//               Expanded(
//                 child: TextField(
//                   controller: _cityController,
//                   decoration: InputDecoration(
//                     labelText: 'Ville *',
//                     hintText: 'Ex: Oran',
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     prefixIcon: const Icon(Icons.location_city),
//                   ),
//                   textCapitalization: TextCapitalization.words,
//                 ),
//               ),
//               const SizedBox(width: 8),
//               IconButton.filled(
//                 onPressed: _isLoadingLocation ? null : _getLocation,
//                 icon: _isLoadingLocation
//                     ? const SizedBox(
//                         width: 20,
//                         height: 20,
//                         child: CircularProgressIndicator(
//                           strokeWidth: 2,
//                           color: Colors.white,
//                         ),
//                       )
//                     : const Icon(Icons.my_location),
//                 tooltip: 'Détecter ma position',
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//   // ✅ Remplacer la méthode _buildProfilePhotoPage dans profile_completion_screen.dart
//
//   Widget _buildProfilePhotoPage() {
//     return Consumer<ProfileCompletionProvider>(
//       builder: (context, provider, _) {
//         final profilePhoto = provider.profilePhoto;
//
//         return SingleChildScrollView(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               Text(
//                 'Photo de profil',
//                 style: Theme.of(context).textTheme.headlineSmall?.copyWith(
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 'Choisissez une photo claire de votre visage',
//                 style: Theme.of(
//                   context,
//                 ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
//               ),
//               const SizedBox(height: 32),
//
//               Center(
//                 child: GestureDetector(
//                   onTap: () => _showPhotoSourceDialog(isProfile: true),
//                   child: Stack(
//                     clipBehavior: Clip.none, // ✅ Important pour le badge
//                     children: [
//                       Container(
//                         width: 200,
//                         height: 200,
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           color: Colors.grey[200],
//                           border: Border.all(
//                             color: Theme.of(context).colorScheme.primary,
//                             width: 3,
//                           ),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.1),
//                               blurRadius: 20,
//                               offset: const Offset(0, 10),
//                             ),
//                           ],
//                         ),
//                         child: profilePhoto != null
//                             ? ClipOval(child: _buildPhotoPreview(profilePhoto))
//                             : Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(
//                                     Icons.add_a_photo,
//                                     size: 48,
//                                     color: Colors.grey[600],
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Text(
//                                     'Ajouter une photo',
//                                     style: TextStyle(
//                                       color: Colors.grey[600],
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                       ),
//
//                       // ✅ Badge "NOUVEAU" pour photo locale
//                       if (profilePhoto != null &&
//                           profilePhoto.source == PhotoSource.local)
//                         Positioned(
//                           top: -5,
//                           right: -5,
//                           child: _buildNewBadgeProfile(),
//                         ),
//
//                       // Bouton edit (toujours affiché si photo présente)
//                       if (profilePhoto != null)
//                         Positioned(
//                           bottom: 0,
//                           right: 0,
//                           child: Container(
//                             decoration: BoxDecoration(
//                               color: Theme.of(context).colorScheme.primary,
//                               shape: BoxShape.circle,
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.black.withOpacity(0.2),
//                                   blurRadius: 8,
//                                   offset: const Offset(0, 2),
//                                 ),
//                               ],
//                             ),
//                             padding: const EdgeInsets.all(8),
//                             child: const Icon(
//                               Icons.edit,
//                               color: Colors.white,
//                               size: 20,
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//               ),
//
//               const SizedBox(height: 24),
//
//               if (profilePhoto == null)
//                 Card(
//                   color: Colors.blue[50],
//                   child: Padding(
//                     padding: const EdgeInsets.all(16),
//                     child: Row(
//                       children: [
//                         Icon(Icons.tips_and_updates, color: Colors.blue[700]),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Text(
//                             'Conseil: Une photo de profil claire augmente vos chances de match de 40%',
//                             style: TextStyle(
//                               color: Colors.blue[900],
//                               fontSize: 13,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   /// ✅ NOUVEAU : Badge pour photo de profil
//   Widget _buildNewBadgeProfile() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Colors.green.shade600, Colors.green.shade400],
//         ),
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.green.withOpacity(0.5),
//             blurRadius: 8,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: const [
//           Icon(Icons.fiber_new, color: Colors.white, size: 16),
//           SizedBox(width: 4),
//           Text(
//             'NOUVEAU',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 11,
//               fontWeight: FontWeight.bold,
//               letterSpacing: 0.5,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildGalleryPhotosPage() {
//     return Consumer<ProfileCompletionProvider>(
//       builder: (context, provider, _) {
//         if (provider.isLoadingPhotos) {
//           return const Center(child: CircularProgressIndicator());
//         }
//
//         final galleryPhotos = provider.galleryPhotos;
//         final canAddMore = galleryPhotos.length < 6;
//         final theme = Theme.of(context);
//
//         return SingleChildScrollView(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'Photos de galerie',
//                           style: theme.textTheme.headlineSmall?.copyWith(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           'Ajoutez 3 à 6 photos',
//                           style: theme.textTheme.bodyMedium?.copyWith(
//                             color: Colors.grey[600],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 6,
//                     ),
//                     decoration: BoxDecoration(
//                       color: galleryPhotos.length >= 3
//                           ? Colors.green[100]
//                           : Colors.orange[100],
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     child: Text(
//                       '${galleryPhotos.length}/6',
//                       style: TextStyle(
//                         color: galleryPhotos.length >= 3
//                             ? Colors.green[900]
//                             : Colors.orange[900],
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//
//               const SizedBox(height: 24),
//
//               GridView.builder(
//                 shrinkWrap: true,
//                 physics: const NeverScrollableScrollPhysics(),
//                 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                   crossAxisCount: 3,
//                   crossAxisSpacing: 12,
//                   mainAxisSpacing: 12,
//                   childAspectRatio: 0.75,
//                 ),
//                 itemCount: galleryPhotos.length + (canAddMore ? 1 : 0),
//                 itemBuilder: (context, index) {
//                   if (index == galleryPhotos.length) {
//                     return _buildAddPhotoCard();
//                   }
//
//                   final photo = galleryPhotos[index];
//                   return PhotoGridItem(
//                     photo: photo,
//                     index: index,
//                     onTap: () {},
//                     onRemove: () => provider.removeGalleryPhoto(index),
//                   );
//                 },
//               ),
//
//               if (galleryPhotos.length < 3) ...[
//                 const SizedBox(height: 16),
//                 Card(
//                   color: Colors.orange[50],
//                   child: Padding(
//                     padding: const EdgeInsets.all(16),
//                     child: Row(
//                       children: [
//                         Icon(Icons.info_outline, color: Colors.orange[700]),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Text(
//                             'Minimum 3 photos requises pour continuer',
//                             style: TextStyle(
//                               color: Colors.orange[900],
//                               fontSize: 13,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   // ✅ Nouveau helper pour afficher PhotoItem
//   Widget _buildPhotoPreview(PhotoItem photo) {
//     if (photo.source == PhotoSource.remote) {
//       return Image.network(
//         photo.remotePath!,
//         fit: BoxFit.cover,
//         errorBuilder: (_, __, ___) => Container(
//           color: Colors.grey[300],
//           child: const Icon(Icons.broken_image, color: Colors.grey),
//         ),
//       );
//     } else {
//       return Image.file(
//         photo.localFile!,
//         fit: BoxFit.cover,
//         errorBuilder: (_, __, ___) => Container(
//           color: Colors.grey[300],
//           child: const Icon(Icons.broken_image, color: Colors.grey),
//         ),
//       );
//     }
//   }
//
//   void _showPhotoSourceDialog({required bool isProfile}) {
//     showModalBottomSheet(
//       context: context,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (ctx) => SafeArea(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const SizedBox(height: 16),
//             Container(
//               width: 40,
//               height: 4,
//               decoration: BoxDecoration(
//                 color: Colors.grey[300],
//                 borderRadius: BorderRadius.circular(2),
//               ),
//             ),
//             const SizedBox(height: 16),
//             ListTile(
//               leading: Container(
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: Theme.of(context).colorScheme.primaryContainer,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Icon(
//                   Icons.camera_alt,
//                   color: Theme.of(context).colorScheme.primary,
//                 ),
//               ),
//               title: const Text('Prendre une photo'),
//               onTap: () {
//                 Navigator.pop(ctx);
//                 if (isProfile) {
//                   context.read<ProfileCompletionProvider>().setProfilePhoto(
//                     fromCamera: true,
//                   );
//                 } else {
//                   context.read<ProfileCompletionProvider>().addGalleryPhotos(
//                     fromCamera: true,
//                   );
//                 }
//               },
//             ),
//             ListTile(
//               leading: Container(
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: Theme.of(context).colorScheme.secondaryContainer,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Icon(
//                   Icons.photo_library,
//                   color: Theme.of(context).colorScheme.secondary,
//                 ),
//               ),
//               title: const Text('Galerie'),
//               onTap: () {
//                 Navigator.pop(ctx);
//                 if (isProfile) {
//                   context.read<ProfileCompletionProvider>().setProfilePhoto(
//                     fromCamera: false,
//                   );
//                 } else {
//                   context.read<ProfileCompletionProvider>().addGalleryPhotos(
//                     fromCamera: false,
//                   );
//                 }
//               },
//             ),
//             const SizedBox(height: 16),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildAddPhotoCard() {
//     return InkWell(
//       onTap: () => _showPhotoSourceDialog(isProfile: false),
//       borderRadius: BorderRadius.circular(12),
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.grey[100],
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(
//             color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
//             width: 2,
//           ),
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.add_photo_alternate,
//               size: 40,
//               color: Theme.of(context).colorScheme.primary,
//             ),
//             const SizedBox(height: 4),
//             Text(
//               'Ajouter',
//               style: TextStyle(
//                 color: Theme.of(context).colorScheme.primary,
//                 fontSize: 12,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Les autres pages (Personality, Details, Interests) restent inchangées
//   Widget _buildPersonalityPage() {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(24),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           Text(
//             'Parlez de vous',
//             style: Theme.of(
//               context,
//             ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Présentez-vous en quelques lignes',
//             style: Theme.of(
//               context,
//             ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
//           ),
//           const SizedBox(height: 24),
//
//           TextField(
//             controller: _bioController,
//             maxLines: 8,
//             maxLength: 500,
//             decoration: InputDecoration(
//               labelText: 'Bio *',
//               hintText:
//                   'Parlez de vos passions, vos valeurs, ce qui vous rend unique...',
//               helperText: 'Minimum 50 caractères',
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               alignLabelWithHint: true,
//             ),
//             textCapitalization: TextCapitalization.sentences,
//           ),
//
//           const SizedBox(height: 16),
//
//           Card(
//             color: Colors.blue[50],
//             child: Padding(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Icon(Icons.lightbulb_outline, color: Colors.blue[700]),
//                       const SizedBox(width: 8),
//                       Text(
//                         'Conseils pour une bio réussie',
//                         style: TextStyle(
//                           color: Colors.blue[900],
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     '• Soyez authentique et positif\n'
//                     '• Mentionnez vos passions\n'
//                     '• Ajoutez une touche d\'humour\n'
//                     '• Évitez les clichés',
//                     style: TextStyle(
//                       color: Colors.blue[900],
//                       fontSize: 13,
//                       height: 1.5,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDetailsPage() {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(24),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           Text(
//             'Détails supplémentaires',
//             style: Theme.of(
//               context,
//             ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 24),
//
//           TextField(
//             controller: _occupationController,
//             decoration: InputDecoration(
//               labelText: 'Profession *',
//               hintText: 'Ex: Développeur, Médecin...',
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               prefixIcon: const Icon(Icons.work),
//             ),
//             textCapitalization: TextCapitalization.words,
//           ),
//
//           const SizedBox(height: 16),
//
//           DropdownButtonFormField<String>(
//             value: _selectedEducation,
//             decoration: InputDecoration(
//               labelText: 'Éducation *',
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               prefixIcon: const Icon(Icons.school),
//             ),
//             hint: const Text('Sélectionnez votre niveau'),
//             items: const [
//               DropdownMenuItem(value: 'high_school', child: Text('Lycée')),
//               DropdownMenuItem(value: 'bachelor', child: Text('Licence')),
//               DropdownMenuItem(value: 'master', child: Text('Master')),
//               DropdownMenuItem(value: 'phd', child: Text('Doctorat')),
//             ],
//             onChanged: (value) => setState(() => _selectedEducation = value),
//           ),
//
//           const SizedBox(height: 16),
//
//           DropdownButtonFormField<int>(
//             value: _selectedHeight,
//             decoration: InputDecoration(
//               labelText: 'Taille (cm) *',
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               prefixIcon: const Icon(Icons.height),
//             ),
//             hint: const Text('Sélectionnez votre taille'),
//             items: List.generate(
//               81,
//               (i) => DropdownMenuItem(
//                 value: 150 + i,
//                 child: Text('${150 + i} cm'),
//               ),
//             ),
//             onChanged: (value) => setState(() => _selectedHeight = value),
//           ),
//
//           const SizedBox(height: 16),
//
//           DropdownButtonFormField<String>(
//             value: _selectedRelationship,
//             decoration: InputDecoration(
//               labelText: 'Situation *',
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               prefixIcon: const Icon(Icons.favorite_border),
//             ),
//             hint: const Text('Votre situation actuelle'),
//             items: const [
//               DropdownMenuItem(value: 'single', child: Text('Célibataire')),
//               DropdownMenuItem(value: 'divorced', child: Text('Divorcé(e)')),
//               DropdownMenuItem(value: 'widowed', child: Text('Veuf/Veuve')),
//             ],
//             onChanged: (value) => setState(() => _selectedRelationship = value),
//           ),
//
//           const SizedBox(height: 24),
//
//           _buildSocialLinksSection(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildSocialLinksSection() {
//     final theme = Theme.of(context);
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         Row(
//           children: [
//             Icon(Icons.share, color: theme.colorScheme.primary, size: 20),
//             const SizedBox(width: 8),
//             Text(
//               'Réseaux sociaux',
//               style: theme.textTheme.titleMedium?.copyWith(
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(width: 8),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//               decoration: BoxDecoration(
//                 color: Colors.grey[200],
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Text(
//                 'Optionnel',
//                 style: TextStyle(
//                   fontSize: 11,
//                   color: Colors.grey[700],
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ),
//           ],
//         ),
//
//         const SizedBox(height: 8),
//
//         Text(
//           'Format: Plateforme: @username ou URL',
//           style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
//         ),
//
//         const SizedBox(height: 12),
//
//         TextField(
//           controller: _socialLinkController,
//           decoration: InputDecoration(
//             hintText: 'Ex: Instagram: @john_doe',
//             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//             prefixIcon: const Icon(Icons.add_link),
//             suffixIcon: IconButton(
//               icon: const Icon(Icons.add_circle),
//               color: theme.colorScheme.primary,
//               onPressed: _addSocialLink,
//               tooltip: 'Ajouter',
//             ),
//           ),
//           onSubmitted: (_) => _addSocialLink(),
//           textInputAction: TextInputAction.done,
//         ),
//
//         if (_socialLinks.isNotEmpty) ...[
//           const SizedBox(height: 16),
//           Wrap(
//             spacing: 8,
//             runSpacing: 8,
//             children: _socialLinks.asMap().entries.map((entry) {
//               final index = entry.key;
//               final link = entry.value;
//
//               return Chip(
//                 avatar: CircleAvatar(
//                   backgroundColor: Color(SocialLink.getColorHex(link.name)),
//                   child: Icon(
//                     _getSocialIcon(link.name),
//                     size: 16,
//                     color: Colors.white,
//                   ),
//                 ),
//                 label: Text(
//                   '${link.name}: ${_shortenUrl(link.url)}',
//                   style: const TextStyle(fontSize: 13),
//                 ),
//                 deleteIcon: const Icon(Icons.close, size: 18),
//                 onDeleted: () {
//                   setState(() {
//                     _socialLinks.removeAt(index);
//                   });
//                 },
//               );
//             }).toList(),
//           ),
//         ],
//       ],
//     );
//   }
//
//   void _addSocialLink() {
//     final input = _socialLinkController.text.trim();
//
//     if (input.isEmpty) return;
//
//     final parts = input.split(':');
//
//     if (parts.length < 2) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Format: Plateforme: @username (ex: Instagram: @john)'),
//           backgroundColor: Colors.orange,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//       return;
//     }
//
//     final platform = parts[0].trim();
//     final url = parts.sublist(1).join(':').trim();
//
//     if (platform.isEmpty || url.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Plateforme et URL requis'),
//           backgroundColor: Colors.orange,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//       return;
//     }
//
//     String normalizedUrl = url;
//     if (!url.startsWith('http')) {
//       if (url.startsWith('@')) {
//         normalizedUrl = _buildPlatformUrl(platform, url.substring(1));
//       } else {
//         normalizedUrl = _buildPlatformUrl(platform, url);
//       }
//     }
//
//     if (_socialLinks.any(
//       (l) => l.name.toLowerCase() == platform.toLowerCase(),
//     )) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('$platform déjà ajouté'),
//           backgroundColor: Colors.orange,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//       return;
//     }
//
//     setState(() {
//       _socialLinks.add(SocialLink(name: platform, url: normalizedUrl));
//       _socialLinkController.clear();
//     });
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('$platform ajouté avec succès'),
//         backgroundColor: Colors.green,
//         behavior: SnackBarBehavior.floating,
//         duration: const Duration(seconds: 1),
//       ),
//     );
//   }
//
//   String _buildPlatformUrl(String platform, String handle) {
//     final lowerPlatform = platform.toLowerCase();
//
//     switch (lowerPlatform) {
//       case 'instagram':
//         return 'https://instagram.com/$handle';
//       case 'facebook':
//         return 'https://facebook.com/$handle';
//       case 'tiktok':
//         return 'https://tiktok.com/@$handle';
//       case 'twitter':
//       case 'x':
//         return 'https://twitter.com/$handle';
//       case 'linkedin':
//         return 'https://linkedin.com/in/$handle';
//       case 'youtube':
//         return 'https://youtube.com/@$handle';
//       case 'snapchat':
//         return 'https://snapchat.com/add/$handle';
//       case 'spotify':
//         return 'https://open.spotify.com/user/$handle';
//       default:
//         return handle;
//     }
//   }
//
//   String _shortenUrl(String url) {
//     if (url.length <= 25) return url;
//
//     final uri = Uri.tryParse(url);
//     if (uri != null && uri.pathSegments.isNotEmpty) {
//       final lastSegment = uri.pathSegments.last;
//       return '@$lastSegment';
//     }
//
//     return '${url.substring(0, 22)}...';
//   }
//
//   IconData _getSocialIcon(String platform) {
//     final lower = platform.toLowerCase();
//
//     switch (lower) {
//       case 'instagram':
//         return Icons.camera_alt;
//       case 'facebook':
//         return Icons.facebook;
//       case 'tiktok':
//         return Icons.music_note;
//       case 'spotify':
//         return Icons.music_video;
//       case 'linkedin':
//         return Icons.work;
//       case 'twitter':
//       case 'x':
//         return Icons.alternate_email;
//       case 'youtube':
//         return Icons.play_circle;
//       case 'snapchat':
//         return Icons.photo_camera;
//       default:
//         return Icons.link;
//     }
//   }
//
//   Widget _buildInterestsPage() {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(24),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           Text(
//             'Vos centres d\'intérêt',
//             style: Theme.of(
//               context,
//             ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Text(
//                 'Sélectionnez au moins 3 centres d\'intérêt',
//                 style: Theme.of(
//                   context,
//                 ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
//               ),
//               const Spacer(),
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 6,
//                 ),
//                 decoration: BoxDecoration(
//                   color: _selectedInterests.length >= 3
//                       ? Colors.green[100]
//                       : Colors.orange[100],
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Text(
//                   '${_selectedInterests.length}/15',
//                   style: TextStyle(
//                     color: _selectedInterests.length >= 3
//                         ? Colors.green[900]
//                         : Colors.orange[900],
//                     fontWeight: FontWeight.bold,
//                     fontSize: 12,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 24),
//
//           Wrap(
//             spacing: 8,
//             runSpacing: 8,
//             children: _availableInterests.map((interest) {
//               final isSelected = _selectedInterests.contains(interest);
//
//               return FilterChip(
//                 label: Text(interest),
//                 selected: isSelected,
//                 onSelected: (selected) {
//                   setState(() {
//                     if (selected) {
//                       if (_selectedInterests.length < 15) {
//                         _selectedInterests.add(interest);
//                       } else {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(
//                             content: Text('Maximum 15 centres d\'intérêt'),
//                             behavior: SnackBarBehavior.floating,
//                           ),
//                         );
//                       }
//                     } else {
//                       _selectedInterests.remove(interest);
//                     }
//                   });
//                 },
//                 selectedColor: Theme.of(context).colorScheme.primaryContainer,
//                 checkmarkColor: Theme.of(context).colorScheme.primary,
//               );
//             }).toList(),
//           ),
//
//           if (_selectedInterests.length < 3) ...[
//             const SizedBox(height: 16),
//             Card(
//               color: Colors.orange[50],
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Row(
//                   children: [
//                     Icon(Icons.info_outline, color: Colors.orange[700]),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Text(
//                         'Sélectionnez au moins 3 centres d\'intérêt',
//                         style: TextStyle(
//                           color: Colors.orange[900],
//                           fontSize: 13,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }
