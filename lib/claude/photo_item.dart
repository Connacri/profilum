// lib/models/photo_item.dart - ✅ MODÈLE PHOTO OPTIMISÉ
// Classe légère pour manipulation UI (pas d'entité ObjectBox)

import 'dart:io';

enum PhotoSourceremote {
  remote, // Déjà sur Supabase
  local, // Nouvelle photo locale (pas encore uploadée)
}

/// 📸 Classe de modèle photo pour l'UI
/// Utilisée pour le drag & drop, affichage grilles, etc.
class PhotoItem {
  final String id;
  final PhotoSourceremote source;
  final String? remotePath; // PATH uniquement (ex: "user_123/gallery/uuid.jpg")
  final File? localFile; // Fichier local
  final int displayOrder;
  final String type; // 'profile', 'gallery'
  final bool isModified; // Pour tracker les changements

  // ✅ Métadonnées de modération
  final String? status; // 'pending', 'approved', 'rejected'
  final bool hasWatermark; // Photo prise avec la caméra
  final DateTime? uploadedAt;
  final DateTime? moderatedAt;
  final String? moderatorId;
  final String? rejectionReason;

  const PhotoItem({
    required this.id,
    required this.source,
    this.remotePath,
    this.localFile,
    required this.displayOrder,
    required this.type,
    this.isModified = false,
    this.status,
    this.hasWatermark = false,
    this.uploadedAt,
    this.moderatedAt,
    this.moderatorId,
    this.rejectionReason,
  });

  // ═══════════════════════════════════════════════════════════════════
  // 🏭 FACTORY - Création depuis différentes sources
  // ═══════════════════════════════════════════════════════════════════

  /// Créer depuis un fichier local (nouvelle photo)
  factory PhotoItem.fromLocal({
    required File file,
    required String type,
    required int displayOrder,
    bool hasWatermark = false,
  }) {
    return PhotoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      source: PhotoSourceremote.local,
      localFile: file,
      type: type,
      displayOrder: displayOrder,
      hasWatermark: hasWatermark,
      status: 'pending', // Nouvelle photo = pending
    );
  }

  /// Créer depuis des données Supabase
  factory PhotoItem.fromSupabase(Map<String, dynamic> data) {
    return PhotoItem(
      id: data['id'] as String,
      source: PhotoSourceremote.remote,
      remotePath: data['remote_path'] as String?,
      type: data['type'] as String? ?? 'gallery',
      displayOrder: data['display_order'] as int? ?? 0,
      status: data['status'] as String?,
      hasWatermark: data['has_watermark'] as bool? ?? false,
      uploadedAt: data['uploaded_at'] != null
          ? DateTime.parse(data['uploaded_at'] as String)
          : null,
      moderatedAt: data['moderated_at'] != null
          ? DateTime.parse(data['moderated_at'] as String)
          : null,
      moderatorId: data['moderator_id'] as String?,
      rejectionReason: data['rejection_reason'] as String?,
    );
  }

  /// Convertir vers Map pour Supabase
  Map<String, dynamic> toSupabaseMap({required String userId}) {
    return {
      'id': id,
      'user_id': userId,
      'remote_path': remotePath,
      'type': type,
      'display_order': displayOrder,
      'status': status ?? 'pending',
      'has_watermark': hasWatermark,
      'uploaded_at': uploadedAt?.toIso8601String(),
      'moderated_at': moderatedAt?.toIso8601String(),
      'moderator_id': moderatorId,
      'rejection_reason': rejectionReason,
    };
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔍 HELPERS - Propriétés calculées
  // ═══════════════════════════════════════════════════════════════════

  /// Obtenir le chemin d'affichage (File ou String)
  dynamic get displayPath =>
      source == PhotoSourceremote.remote ? remotePath : localFile;

  /// Est-ce une nouvelle photo à uploader ?
  bool get needsUpload => source == PhotoSourceremote.local;

  /// Est-ce une photo remote ?
  bool get isRemote => source == PhotoSourceremote.remote;

  /// Est-ce une photo locale ?
  bool get isLocal => source == PhotoSourceremote.local;

  /// Photo en attente de modération ?
  bool get isPending => status == 'pending';

  /// Photo approuvée ?
  bool get isApproved => status == 'approved';

  /// Photo rejetée ?
  bool get isRejected => status == 'rejected';

  /// Photo prise avec la caméra ?
  bool get isFromCamera => hasWatermark;

  /// Est-ce une photo de profil ?
  bool get isProfilePhoto => type == 'profile';

  /// Est-ce une photo de galerie ?
  bool get isGalleryPhoto => type == 'gallery';

  /// Peut-elle être supprimée ? (locale ou rejetée)
  bool get canBeDeleted => isLocal || isRejected;

  /// A-t-elle été modérée ?
  bool get isModerated => moderatedAt != null;

  // ═══════════════════════════════════════════════════════════════════
  // 📝 COPY WITH
  // ═══════════════════════════════════════════════════════════════════

  PhotoItem copyWith({
    String? id,
    PhotoSourceremote? source,
    String? remotePath,
    File? localFile,
    int? displayOrder,
    String? type,
    bool? isModified,
    String? status,
    bool? hasWatermark,
    DateTime? uploadedAt,
    DateTime? moderatedAt,
    String? moderatorId,
    String? rejectionReason,
  }) {
    return PhotoItem(
      id: id ?? this.id,
      source: source ?? this.source,
      remotePath: remotePath ?? this.remotePath,
      localFile: localFile ?? this.localFile,
      displayOrder: displayOrder ?? this.displayOrder,
      type: type ?? this.type,
      isModified: isModified ?? this.isModified,
      status: status ?? this.status,
      hasWatermark: hasWatermark ?? this.hasWatermark,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      moderatedAt: moderatedAt ?? this.moderatedAt,
      moderatorId: moderatorId ?? this.moderatorId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔧 EQUALITY & HASH
  // ═══════════════════════════════════════════════════════════════════

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PhotoItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PhotoItem('
        'id: $id, '
        'source: $source, '
        'type: $type, '
        'status: $status, '
        'order: $displayOrder'
        ')';
  }
}

/// 📋 Extension pour listes de PhotoItem
extension PhotoItemListExtension on List<PhotoItem> {
  /// Trier par displayOrder
  List<PhotoItem> sortedByOrder() {
    final sorted = List<PhotoItem>.from(this);
    sorted.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return sorted;
  }

  /// Filtrer par type
  List<PhotoItem> whereType(String type) {
    return where((p) => p.type == type).toList();
  }

  /// Filtrer par statut
  List<PhotoItem> whereStatus(String status) {
    return where((p) => p.status == status).toList();
  }

  /// Seulement les photos approuvées
  List<PhotoItem> get approved {
    return where((p) => p.isApproved).toList();
  }

  /// Seulement les photos en attente
  List<PhotoItem> get pending {
    return where((p) => p.isPending).toList();
  }

  /// Seulement les photos locales (à uploader)
  List<PhotoItem> get needingUpload {
    return where((p) => p.needsUpload).toList();
  }

  /// Réindexer les displayOrder
  List<PhotoItem> reindex() {
    final sorted = sortedByOrder();
    return sorted
        .asMap()
        .entries
        .map((e) => e.value.copyWith(displayOrder: e.key))
        .toList();
  }
}
