// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';
// import 'package:shimmer/shimmer.dart';
//
// import '../models/photo_item.dart';
//
// /// 🎨 Version AVANCÉE avec badges multiples
// /// Active cette version si tu as étendu PhotoItem avec status/hasWatermark
// class PhotoGridItemAdvanced extends StatelessWidget {
//   final PhotoItem photo;
//   final int index;
//   final bool isSelected;
//   final VoidCallback onTap;
//   final VoidCallback onRemove;
//   final bool showAllBadges; // ✅ Toggle pour activer tous les badges
//
//   const PhotoGridItemAdvanced({
//     super.key,
//     required this.photo,
//     required this.index,
//     this.isSelected = false,
//     required this.onTap,
//     required this.onRemove,
//     this.showAllBadges = false, // Par défaut : simple
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//
//     return GestureDetector(
//       onTap: onTap,
//       child: Stack(
//         fit: StackFit.expand,
//         children: [
//           // Image
//           ClipRRect(
//             borderRadius: BorderRadius.circular(12),
//             child: photo.source == PhotoSource.remote
//                 ? _buildRemoteImage()
//                 : _buildLocalImage(),
//           ),
//
//           // Border si sélectionné
//           if (isSelected)
//             Container(
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: theme.colorScheme.primary, width: 3),
//               ),
//             ),
//
//           // ✅ Badges dynamiques (simple ou complet)
//           if (showAllBadges)
//             ..._buildAllBadges()
//           else
//             Positioned(top: 8, left: 8, child: _buildSimpleBadge()),
//
//           // Badge numéro (en bas à gauche)
//           Positioned(
//             bottom: 8,
//             left: 8,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//               decoration: BoxDecoration(
//                 color: Colors.black.withOpacity(0.7),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Text(
//                 '${index + 1}',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 12,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           ),
//
//           // Bouton supprimer (en haut à droite)
//           Positioned(
//             top: 4,
//             right: 4,
//             child: Container(
//               decoration: BoxDecoration(
//                 color: Colors.black.withOpacity(0.7),
//                 shape: BoxShape.circle,
//               ),
//               child: IconButton(
//                 icon: const Icon(Icons.close, color: Colors.white, size: 18),
//                 padding: EdgeInsets.zero,
//                 constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
//                 onPressed: onRemove,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   /// ✅ Badge simple : seulement "NOUVEAU" pour photos locales
//   Widget _buildSimpleBadge() {
//     if (photo.source == PhotoSource.local) {
//       return _buildBadge(
//         label: 'NOUVEAU',
//         icon: Icons.fiber_new,
//         gradient: [Colors.green.shade600, Colors.green.shade400],
//         shadowColor: Colors.green,
//       );
//     }
//     return const SizedBox.shrink();
//   }
//
//   /// ✅ Tous les badges (empilés verticalement en haut à gauche)
//   List<Widget> _buildAllBadges() {
//     final badges = <Widget>[];
//     double topOffset = 8.0;
//
//     // Badge LOCAL (priorité 1)
//     if (photo.source == PhotoSource.local) {
//       badges.add(
//         Positioned(
//           top: topOffset,
//           left: 8,
//           child: _buildBadge(
//             label: 'NOUVEAU',
//             icon: Icons.fiber_new,
//             gradient: [Colors.green.shade600, Colors.green.shade400],
//             shadowColor: Colors.green,
//           ),
//         ),
//       );
//       topOffset += 30; // Espace pour le prochain badge
//     }
//     // Badge MODÉRATION (priorité 2)
//     else if (photo.isPending) {
//       badges.add(
//         Positioned(
//           top: topOffset,
//           left: 8,
//           child: _buildBadge(
//             label: 'MODÉRATION',
//             icon: Icons.hourglass_empty,
//             gradient: [Colors.orange.shade600, Colors.orange.shade400],
//             shadowColor: Colors.orange,
//           ),
//         ),
//       );
//       topOffset += 30;
//     }
//     // Badge VALIDÉE (priorité 3)
//     else if (photo.isApproved) {
//       badges.add(
//         Positioned(
//           top: topOffset,
//           left: 8,
//           child: _buildBadge(
//             label: 'VALIDÉE',
//             icon: Icons.verified,
//             gradient: [Colors.teal.shade600, Colors.teal.shade400],
//             shadowColor: Colors.teal,
//           ),
//         ),
//       );
//       topOffset += 30;
//     }
//
//     // Badge CAMÉRA (en bas de la pile si applicable)
//     if (photo.isFromCamera) {
//       badges.add(
//         Positioned(
//           top: topOffset,
//           left: 8,
//           child: _buildBadge(
//             label: 'CAMÉRA',
//             icon: Icons.camera_alt,
//             gradient: [Colors.purple.shade600, Colors.purple.shade400],
//             shadowColor: Colors.purple,
//           ),
//         ),
//       );
//     }
//
//     return badges;
//   }
//
//   /// Widget badge générique
//   Widget _buildBadge({
//     required String label,
//     required IconData icon,
//     required List<Color> gradient,
//     required Color shadowColor,
//   }) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(colors: gradient),
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: shadowColor.withOpacity(0.4),
//             blurRadius: 6,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, color: Colors.white, size: 14),
//           const SizedBox(width: 4),
//           Text(
//             label,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 10,
//               fontWeight: FontWeight.bold,
//               letterSpacing: 0.5,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildRemoteImage() {
//     return CachedNetworkImage(
//       imageUrl: photo.remotePath!,
//       fit: BoxFit.cover,
//       placeholder: (_, __) => Shimmer.fromColors(
//         baseColor: Colors.grey[300]!,
//         highlightColor: Colors.grey[100]!,
//         child: Container(color: Colors.white),
//       ),
//       errorWidget: (_, __, ___) => Container(
//         color: Colors.grey[300],
//         child: const Icon(Icons.broken_image, color: Colors.grey),
//       ),
//     );
//   }
//
//   Widget _buildLocalImage() {
//     return Image.file(
//       photo.localFile!,
//       fit: BoxFit.cover,
//       errorBuilder: (_, __, ___) => Container(
//         color: Colors.grey[300],
//         child: const Icon(Icons.broken_image, color: Colors.grey),
//       ),
//     );
//   }
// }
