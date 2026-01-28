// ==================== MODÈLES UNIFIÉS (VERSION UNIQUE) ====================

enum DocumentType {
  chifa('Carte Chifa'),
  cni('CNI Biométrique'),
  passport('Passeport');

  final String label;
  const DocumentType(this.label);
}

enum ChifaRank {
  assure('Assuré'),
  ayantDroit('Ayant-droit');

  final String label;
  const ChifaRank(this.label);
}

// ==================== CLASSE ABSTRAITE ====================

abstract class ScannedDocument {
  final String? id;
  final String userId;
  final DocumentType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String fullName;
  final String phoneNumber;
  final DateTime? birthDate;
  final double confidenceScore;
  final bool isManuallyVerified;

  ScannedDocument({
    this.id,
    required this.userId,
    required this.type,
    DateTime? createdAt,
    DateTime? updatedAt,
    required this.fullName,
    this.phoneNumber = '',
    this.birthDate,
    this.confidenceScore = 0.0,
    this.isManuallyVerified = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toSupabaseJson();

  factory ScannedDocument.fromSupabaseJson(Map<String, dynamic> json) {
    final typeStr = json['document_type'] as String;
    switch (typeStr) {
      case 'chifa':
        return ChifaCard.fromSupabaseJson(json);
      case 'cni':
        return CNICard.fromSupabaseJson(json);
      case 'passport':
        return PassportCard.fromSupabaseJson(json);
      default:
        throw ArgumentError('Type document inconnu: $typeStr');
    }
  }
}

// ==================== CHIFA CARD ====================

class ChifaCard extends ScannedDocument {
  final String chifaNumber;
  final String organism;
  final DateTime? expiryDate;
  final ChifaRank rank;

  ChifaCard({
    super.id,
    required super.userId,
    required super.fullName,
    super.phoneNumber = '',
    super.birthDate,
    required this.chifaNumber,
    required this.organism,
    this.expiryDate,
    this.rank = ChifaRank.assure,
    super.confidenceScore,
    super.isManuallyVerified,
    super.createdAt,
    super.updatedAt,
  }) : super(type: DocumentType.chifa);

  @override
  Map<String, dynamic> toSupabaseJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'document_type': 'chifa',
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'full_name': fullName,
      'phone_number': phoneNumber,
      'birth_date': birthDate?.toIso8601String().split('T')[0],
      'chifa_number': chifaNumber,
      'chifa_organism': organism,
      'chifa_expiry_date': expiryDate?.toIso8601String().split('T')[0],
      'chifa_rank': rank.name,
      'confidence_score': confidenceScore,
      'is_manually_verified': isManuallyVerified,
    };
  }

  factory ChifaCard.fromSupabaseJson(Map<String, dynamic> json) {
    return ChifaCard(
      id: json['id'],
      userId: json['user_id'],
      fullName: json['full_name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      birthDate: json['birth_date'] != null ? DateTime.parse(json['birth_date']) : null,
      chifaNumber: json['chifa_number'] ?? '',
      organism: json['chifa_organism'] ?? '',
      expiryDate: json['chifa_expiry_date'] != null ? DateTime.parse(json['chifa_expiry_date']) : null,
      rank: json['chifa_rank'] == 'ayantDroit' ? ChifaRank.ayantDroit : ChifaRank.assure,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      isManuallyVerified: json['is_manually_verified'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  ChifaCard copyWith({
    String? id,
    String? fullName,
    String? phoneNumber,
    DateTime? birthDate,
    String? chifaNumber,
    String? organism,
    DateTime? expiryDate,
    ChifaRank? rank,
    double? confidenceScore,
    bool? isManuallyVerified,
  }) {
    return ChifaCard(
      id: id ?? this.id,
      userId: userId,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      birthDate: birthDate ?? this.birthDate,
      chifaNumber: chifaNumber ?? this.chifaNumber,
      organism: organism ?? this.organism,
      expiryDate: expiryDate ?? this.expiryDate,
      rank: rank ?? this.rank,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      isManuallyVerified: isManuallyVerified ?? this.isManuallyVerified,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

// ==================== CNI CARD ====================

class CNICard extends ScannedDocument {
  final String cniNumber;
  final String birthPlace;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String? mrzLine1;
  final String? mrzLine2;

  CNICard({
    super.id,
    required super.userId,
    required super.fullName,
    super.phoneNumber = '',
    super.birthDate,
    required this.cniNumber,
    required this.birthPlace,
    this.issueDate,
    this.expiryDate,
    this.mrzLine1,
    this.mrzLine2,
    super.confidenceScore,
    super.isManuallyVerified,
    super.createdAt,
    super.updatedAt,
  }) : super(type: DocumentType.cni);

  @override
  Map<String, dynamic> toSupabaseJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'document_type': 'cni',
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'full_name': fullName,
      'phone_number': phoneNumber,
      'birth_date': birthDate?.toIso8601String().split('T')[0],
      'cni_number': cniNumber,
      'cni_birth_place': birthPlace,
      'cni_issue_date': issueDate?.toIso8601String().split('T')[0],
      'cni_expiry_date': expiryDate?.toIso8601String().split('T')[0],
      'cni_mrz_line1': mrzLine1,
      'cni_mrz_line2': mrzLine2,
      'confidence_score': confidenceScore,
      'is_manually_verified': isManuallyVerified,
    };
  }

  factory CNICard.fromSupabaseJson(Map<String, dynamic> json) {
    return CNICard(
      id: json['id'],
      userId: json['user_id'],
      fullName: json['full_name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      birthDate: json['birth_date'] != null ? DateTime.parse(json['birth_date']) : null,
      cniNumber: json['cni_number'] ?? '',
      birthPlace: json['cni_birth_place'] ?? '',
      issueDate: json['cni_issue_date'] != null ? DateTime.parse(json['cni_issue_date']) : null,
      expiryDate: json['cni_expiry_date'] != null ? DateTime.parse(json['cni_expiry_date']) : null,
      mrzLine1: json['cni_mrz_line1'],
      mrzLine2: json['cni_mrz_line2'],
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      isManuallyVerified: json['is_manually_verified'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  CNICard copyWith({
    String? id,
    String? fullName,
    String? phoneNumber,
    DateTime? birthDate,
    String? cniNumber,
    String? birthPlace,
    DateTime? issueDate,
    DateTime? expiryDate,
    double? confidenceScore,
    bool? isManuallyVerified,
  }) {
    return CNICard(
      id: id ?? this.id,
      userId: userId,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      birthDate: birthDate ?? this.birthDate,
      cniNumber: cniNumber ?? this.cniNumber,
      birthPlace: birthPlace ?? this.birthPlace,
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
      mrzLine1: mrzLine1,
      mrzLine2: mrzLine2,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      isManuallyVerified: isManuallyVerified ?? this.isManuallyVerified,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

// ==================== PASSPORT CARD ====================

class PassportCard extends ScannedDocument {
  final String passportNumber;
  final String issuePlace;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String? mrzLine1;
  final String? mrzLine2;

  PassportCard({
    super.id,
    required super.userId,
    required super.fullName,
    super.phoneNumber = '',
    super.birthDate,
    required this.passportNumber,
    required this.issuePlace,
    this.issueDate,
    this.expiryDate,
    this.mrzLine1,
    this.mrzLine2,
    super.confidenceScore,
    super.isManuallyVerified,
    super.createdAt,
    super.updatedAt,
  }) : super(type: DocumentType.passport);

  @override
  Map<String, dynamic> toSupabaseJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'document_type': 'passport',
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'full_name': fullName,
      'phone_number': phoneNumber,
      'birth_date': birthDate?.toIso8601String().split('T')[0],
      'passport_number': passportNumber,
      'passport_issue_place': issuePlace,
      'passport_issue_date': issueDate?.toIso8601String().split('T')[0],
      'passport_expiry_date': expiryDate?.toIso8601String().split('T')[0],
      'passport_mrz_line1': mrzLine1,
      'passport_mrz_line2': mrzLine2,
      'confidence_score': confidenceScore,
      'is_manually_verified': isManuallyVerified,
    };
  }

  factory PassportCard.fromSupabaseJson(Map<String, dynamic> json) {
    return PassportCard(
      id: json['id'],
      userId: json['user_id'],
      fullName: json['full_name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      birthDate: json['birth_date'] != null ? DateTime.parse(json['birth_date']) : null,
      passportNumber: json['passport_number'] ?? '',
      issuePlace: json['passport_issue_place'] ?? '',
      issueDate: json['passport_issue_date'] != null ? DateTime.parse(json['passport_issue_date']) : null,
      expiryDate: json['passport_expiry_date'] != null ? DateTime.parse(json['passport_expiry_date']) : null,
      mrzLine1: json['passport_mrz_line1'],
      mrzLine2: json['passport_mrz_line2'],
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      isManuallyVerified: json['is_manually_verified'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  PassportCard copyWith({
    String? id,
    String? fullName,
    String? phoneNumber,
    DateTime? birthDate,
    String? passportNumber,
    String? issuePlace,
    DateTime? issueDate,
    DateTime? expiryDate,
    double? confidenceScore,
    bool? isManuallyVerified,
  }) {
    return PassportCard(
      id: id ?? this.id,
      userId: userId,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      birthDate: birthDate ?? this.birthDate,
      passportNumber: passportNumber ?? this.passportNumber,
      issuePlace: issuePlace ?? this.issuePlace,
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
      mrzLine1: mrzLine1,
      mrzLine2: mrzLine2,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      isManuallyVerified: isManuallyVerified ?? this.isManuallyVerified,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
