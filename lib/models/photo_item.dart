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

  PhotoItem({
    required this.id,
    required this.source,
    this.remotePath,
    this.localFile,
    required this.displayOrder,
    required this.type,
    this.isModified = false,
  });

  // Helper: Obtenir le chemin d'affichage
  dynamic get displayPath =>
      source == PhotoSource.remote ? remotePath : localFile;

  // Helper: Est-ce une nouvelle photo à uploader ?
  bool get needsUpload => source == PhotoSource.local;

  // Copy with
  PhotoItem copyWith({
    String? id,
    PhotoSource? source,
    String? remotePath,
    File? localFile,
    int? displayOrder,
    String? type,
    bool? isModified,
  }) {
    return PhotoItem(
      id: id ?? this.id,
      source: source ?? this.source,
      remotePath: remotePath ?? this.remotePath,
      localFile: localFile ?? this.localFile,
      displayOrder: displayOrder ?? this.displayOrder,
      type: type ?? this.type,
      isModified: isModified ?? this.isModified,
    );
  }
}
