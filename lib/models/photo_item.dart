import 'dart:io';

enum PhotoSource {
  remote, // Déjà sur Supabase
  local, // Nouvelle photo locale
}

class PhotoItem {
  final String id;
  final PhotoSource source;
  final String? remotePath; // URL Supabase
  final File? localFile; // Fichier local
  final int displayOrder;
  final String type; // 'profile', 'cover', 'gallery'
  final bool isModified; // Pour tracker les changements

  // ✅ NOUVEAU : Infos pour badges avancés
  final String? status; // 'pending', 'approved', 'rejected'
  final bool hasWatermark; // Photo prise avec la caméra
  final DateTime? uploadedAt; // Date d'upload
  final DateTime? moderatedAt; // Date de modération

  PhotoItem({
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
  });

  // Helper: Obtenir le chemin d'affichage
  dynamic get displayPath =>
      source == PhotoSource.remote ? remotePath : localFile;

  // Helper: Est-ce une nouvelle photo à uploader ?
  bool get needsUpload => source == PhotoSource.local;

  // ✅ NOUVEAU : Helpers pour badges
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isFromCamera => hasWatermark;

  // Copy with
  PhotoItem copyWith({
    String? id,
    PhotoSource? source,
    String? remotePath,
    File? localFile,
    int? displayOrder,
    String? type,
    bool? isModified,
    String? status,
    bool? hasWatermark,
    DateTime? uploadedAt,
    DateTime? moderatedAt,
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
    );
  }
}
