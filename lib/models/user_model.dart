// lib/models/user_model.dart - ✅ MODÈLE USER SIMPLE (remplace UserEntity)

import 'dart:convert';

/// 👤 Modèle utilisateur simple pour remplacer ObjectBox UserEntity
class UserModel {
  final String userId;
  final String email;
  final String? fullName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? lookingFor;
  final String? bio;
  final bool profileCompleted;
  final int completionPercentage;
  final String? occupation;
  final List<String> interests;
  final int? heightCm;
  final String? education;
  final String? relationshipStatus;
  final List<SocialLink> socialLinks;
  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String role;
  final DateTime? lastActiveAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.userId,
    required this.email,
    this.fullName,
    this.dateOfBirth,
    this.gender,
    this.lookingFor,
    this.bio,
    this.profileCompleted = false,
    this.completionPercentage = 0,
    this.occupation,
    this.interests = const [],
    this.heightCm,
    this.education,
    this.relationshipStatus,
    this.socialLinks = const [],
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    this.role = 'user',
    this.lastActiveAt,
    required this.createdAt,
    required this.updatedAt,
  });

  // ═══════════════════════════════════════════════════════════════════
  // 🏭 FACTORY - Création depuis différentes sources
  // ═══════════════════════════════════════════════════════════════════

  /// Créer depuis Supabase
  factory UserModel.fromSupabase(Map<String, dynamic> data) {
    return UserModel(
      userId: data['id'] as String,
      email: data['email'] as String,
      fullName: data['full_name'] as String?,
      dateOfBirth: data['date_of_birth'] != null
          ? DateTime.tryParse(data['date_of_birth'] as String)
          : null,
      gender: data['gender'] as String?,
      lookingFor: data['looking_for'] as String?,
      bio: data['bio'] as String?,
      profileCompleted: data['profile_completed'] as bool? ?? false,
      completionPercentage: data['completion_percentage'] as int? ?? 0,
      occupation: data['occupation'] as String?,
      interests: _parseList(data['interests']),
      heightCm: data['height_cm'] as int?,
      education: data['education'] as String?,
      relationshipStatus: data['relationship_status'] as String?,
      socialLinks: _parseSocialLinks(data['social_links']),
      city: data['city'] as String?,
      country: data['country'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      role: data['role'] as String? ?? 'user',
      lastActiveAt: data['last_active_at'] != null
          ? DateTime.tryParse(data['last_active_at'] as String)
          : null,
      createdAt: DateTime.tryParse(data['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Créer depuis JSON (SharedPreferences)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String?,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'] as String)
          : null,
      gender: json['gender'] as String?,
      lookingFor: json['lookingFor'] as String?,
      bio: json['bio'] as String?,
      profileCompleted: json['profileCompleted'] as bool? ?? false,
      completionPercentage: json['completionPercentage'] as int? ?? 0,
      occupation: json['occupation'] as String?,
      interests: List<String>.from(json['interests'] ?? []),
      heightCm: json['heightCm'] as int?,
      education: json['education'] as String?,
      relationshipStatus: json['relationshipStatus'] as String?,
      socialLinks: (json['socialLinks'] as List?)
              ?.map((e) => SocialLink.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      city: json['city'] as String?,
      country: json['country'] as String?,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      role: json['role'] as String? ?? 'user',
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.tryParse(json['lastActiveAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 📤 SERIALIZATION
  // ═══════════════════════════════════════════════════════════════════

  /// Convertir en JSON (pour SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'fullName': fullName,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'lookingFor': lookingFor,
      'bio': bio,
      'profileCompleted': profileCompleted,
      'completionPercentage': completionPercentage,
      'occupation': occupation,
      'interests': interests,
      'heightCm': heightCm,
      'education': education,
      'relationshipStatus': relationshipStatus,
      'socialLinks': socialLinks.map((e) => e.toJson()).toList(),
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'role': role,
      'lastActiveAt': lastActiveAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Convertir en Map Supabase
  Map<String, dynamic> toSupabase() {
    return {
      'id': userId,
      'email': email,
      'full_name': fullName,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'looking_for': lookingFor,
      'bio': bio,
      'profile_completed': profileCompleted,
      'completion_percentage': completionPercentage,
      'occupation': occupation,
      'interests': interests,
      'height_cm': heightCm,
      'education': education,
      'relationship_status': relationshipStatus,
      'social_links': socialLinks.map((e) => e.toJson()).toList(),
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'role': role,
      'last_active_at': lastActiveAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔄 COPY WITH
  // ═══════════════════════════════════════════════════════════════════

  UserModel copyWith({
    String? userId,
    String? email,
    String? fullName,
    DateTime? dateOfBirth,
    String? gender,
    String? lookingFor,
    String? bio,
    bool? profileCompleted,
    int? completionPercentage,
    String? occupation,
    List<String>? interests,
    int? heightCm,
    String? education,
    String? relationshipStatus,
    List<SocialLink>? socialLinks,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    String? role,
    DateTime? lastActiveAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      lookingFor: lookingFor ?? this.lookingFor,
      bio: bio ?? this.bio,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      occupation: occupation ?? this.occupation,
      interests: interests ?? this.interests,
      heightCm: heightCm ?? this.heightCm,
      education: education ?? this.education,
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      socialLinks: socialLinks ?? this.socialLinks,
      city: city ?? this.city,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      role: role ?? this.role,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔧 HELPERS
  // ═══════════════════════════════════════════════════════════════════

  static List<String> _parseList(dynamic value) {
    if (value == null) return [];
    if (value is List) return List<String>.from(value);
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        return List<String>.from(decoded);
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  static List<SocialLink> _parseSocialLinks(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map((e) => SocialLink.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value) as List;
        return decoded
            .map((e) => SocialLink.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  @override
  String toString() {
    return 'UserModel(userId: $userId, email: $email, fullName: $fullName)';
  }
}

/// 🔗 Social Link Model (utilisé dans UserModel)
class SocialLink {
  final String platform;
  final String url;

  SocialLink({required this.platform, required this.url});

  factory SocialLink.fromJson(Map<String, dynamic> json) {
    return SocialLink(
      platform: json['platform'] as String,
      url: json['url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      'url': url,
    };
  }
}
