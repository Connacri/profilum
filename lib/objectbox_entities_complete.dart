// lib/objectbox_entities_complete.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:objectbox/objectbox.dart';
import 'package:objectbox/objectbox.dart';
import 'models/social_link_model.dart';

// ============================================
// USER ENTITY - REFACTORISÉ
// ============================================

@Entity()
class UserEntity {
  @Id()
  int id = 0;

  @Unique()
  @Index()
  String userId;

  @Index()
  String email;

  String? fullName;

  @Property(type: PropertyType.date)
  DateTime? dateOfBirth;

  String? gender;
  String? lookingFor;
  String? bio;

  // ❌ SUPPRIMÉ: photosJson, photoUrl, coverUrl
  // Les photos sont maintenant dans PhotoEntity

  bool profileCompleted;
  int completionPercentage;

  String? occupation;

  // Intérêts (inchangé)
  String interestsJson;

  int? heightCm;
  String? education;
  String? relationshipStatus;

  // ✅ NOUVEAU: Social links au lieu de instagram_handle et spotify_anthem
  String socialLinksJson; // JSON: [{name: "Instagram", url: "..."}]

  String? city;
  String? country;

  double? latitude;
  double? longitude;

  @Index()
  String role;

  @Property(type: PropertyType.date)
  DateTime? lastActiveAt;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  String? accessToken;
  String? refreshToken;

  @Property(type: PropertyType.date)
  DateTime? tokenExpiresAt;

  bool needsSync;
  String pendingActionsJson;

  UserEntity({
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
    String? interestsJson,
    this.heightCm,
    this.education,
    this.relationshipStatus,
    String? socialLinksJson,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    this.role = 'user',
    this.lastActiveAt,
    required this.createdAt,
    required this.updatedAt,
    this.accessToken,
    this.refreshToken,
    this.tokenExpiresAt,
    this.needsSync = false,
    String? pendingActionsJson,
  }) : interestsJson = interestsJson ?? '[]',
        socialLinksJson = socialLinksJson ?? '[]',
        pendingActionsJson = pendingActionsJson ?? '[]';

  // ✅ GETTER: Interests
  List<String> get interests {
    if (interestsJson.isEmpty || interestsJson == '[]') return [];
    try {
      final decoded = jsonDecode(interestsJson);
      if (decoded is List) return List<String>.from(decoded);
      return [];
    } catch (e) {
      debugPrint('❌ Error decoding interests: $e');
      return [];
    }
  }

  // ✅ SETTER: Interests
  set interests(List<String> value) {
    interestsJson = jsonEncode(value);
  }

  // ✅ NOUVEAU: GETTER Social Links
  List<SocialLink> get socialLinks {
    if (socialLinksJson.isEmpty || socialLinksJson == '[]') return [];
    try {
      final decoded = jsonDecode(socialLinksJson) as List;
      return decoded.map((e) => SocialLink.fromJson(e)).toList();
    } catch (e) {
      debugPrint('❌ Error decoding social links: $e');
      return [];
    }
  }

  // ✅ NOUVEAU: SETTER Social Links
  set socialLinks(List<SocialLink> value) {
    socialLinksJson = jsonEncode(value.map((e) => e.toJson()).toList());
  }

  // ✅ GETTER: Pending Actions
  List<String> get pendingActions {
    if (pendingActionsJson.isEmpty || pendingActionsJson == '[]') return [];
    try {
      final decoded = jsonDecode(pendingActionsJson);
      if (decoded is List) return List<String>.from(decoded);
      return [];
    } catch (e) {
      return [];
    }
  }

  // ✅ SETTER: Pending Actions
  set pendingActions(List<String> value) {
    pendingActionsJson = jsonEncode(value);
  }
}

// ============================================
// PHOTO ENTITY - REFACTORISÉ
// ============================================

@Entity()
class PhotoEntity {
  @Id()
  int id = 0;

  @Unique()
  String photoId;

  @Index()
  String userId;

  // ✅ NOUVEAU: Type de photo (profile, cover, gallery)
  @Index()
  String type; // 'profile', 'cover', 'gallery'

  String localPath;
  String? remotePath;

  @Index()
  String status; // pending, approved, rejected

  bool hasWatermark;

  @Property(type: PropertyType.date)
  DateTime uploadedAt;

  @Property(type: PropertyType.date)
  DateTime? moderatedAt;

  String? moderatorId;
  String? rejectionReason;

  // displayOrder est maintenant crucial pour les covers/gallery
  int displayOrder;

  PhotoEntity({
    required this.photoId,
    required this.userId,
    required this.type, // OBLIGATOIRE
    required this.localPath,
    this.remotePath,
    this.status = 'pending',
    this.hasWatermark = false,
    required this.uploadedAt,
    this.moderatedAt,
    this.moderatorId,
    this.rejectionReason,
    this.displayOrder = 0,
  });

  // Helper: Est-ce une photo de profil ?
  bool get isProfilePhoto => type == 'profile';

  // Helper: Est-ce une cover ?
  bool get isCoverPhoto => type == 'cover';

  // Helper: Est-ce une photo de galerie ?
  bool get isGalleryPhoto => type == 'gallery';

  // Helper: Photo approuvée ?
  bool get isApproved => status == 'approved';

  // Helper: Photo en attente ?
  bool get isPending => status == 'pending';

  // Helper: Photo rejetée ?
  bool get isRejected => status == 'rejected';
}

// ============================================
// GROUP ENTITY (inchangé)
// ============================================

@Entity()
class GroupEntity {
  @Id()
  int id = 0;

  @Unique()
  String groupId;

  String name;
  String? description;
  String? photoUrl;

  @Index()
  String creatorId;

  String memberIdsJson;

  int memberCount;

  @Index()
  String category;

  bool isPrivate;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  GroupEntity({
    required this.groupId,
    required this.name,
    this.description,
    this.photoUrl,
    required this.creatorId,
    String? memberIdsJson,
    this.memberCount = 0,
    required this.category,
    this.isPrivate = false,
    required this.createdAt,
    required this.updatedAt,
  }) : memberIdsJson = memberIdsJson ?? '[]';

  List<String> get memberIds {
    try {
      return List<String>.from(
        (memberIdsJson.isEmpty || memberIdsJson == '[]')
            ? []
            : Uri.decodeComponent(memberIdsJson).split(','),
      );
    } catch (e) {
      return [];
    }
  }

  set memberIds(List<String> value) {
    memberIdsJson = value.isEmpty ? '[]' : Uri.encodeComponent(value.join(','));
  }
}

// ============================================
// NOTIFICATION ENTITY (inchangé)
// ============================================

@Entity()
class NotificationEntity {
  @Id()
  int id = 0;

  @Unique()
  String notificationId;

  @Index()
  String userId;

  @Index()
  String type;

  String title;
  String body;
  String? imageUrl;
  String? actionRoute;

  String? metadataJson;

  @Index()
  bool isRead;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  NotificationEntity({
    required this.notificationId,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.imageUrl,
    this.actionRoute,
    this.metadataJson,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic>? get metadata {
    if (metadataJson == null || metadataJson!.isEmpty) return null;
    try {
      return jsonDecode(metadataJson!) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  set metadata(Map<String, dynamic>? value) {
    metadataJson = value != null ? jsonEncode(value) : null;
  }
}

// ============================================
// MATCH ENTITY (inchangé)
// ============================================

@Entity()
class MatchEntity {
  @Id()
  int id = 0;

  @Unique()
  String matchId;

  @Index()
  String userId1;

  @Index()
  String userId2;

  @Index()
  String status;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime? matchedAt;

  bool user1Liked;
  bool user2Liked;

  MatchEntity({
    required this.matchId,
    required this.userId1,
    required this.userId2,
    this.status = 'pending',
    required this.createdAt,
    this.matchedAt,
    this.user1Liked = false,
    this.user2Liked = false,
  });
}

// ============================================
// MESSAGE ENTITY (inchangé)
// ============================================

@Entity()
class MessageEntity {
  @Id()
  int id = 0;

  @Unique()
  String messageId;

  @Index()
  String senderId;

  @Index()
  String receiverId;

  String content;
  String type;

  @Index()
  bool isRead;

  bool isDelivered;
  bool isSent;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime? readAt;

  String? attachmentUrl;
  String? attachmentLocalPath;

  MessageEntity({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.type = 'text',
    this.isRead = false,
    this.isDelivered = false,
    this.isSent = false,
    required this.createdAt,
    this.readAt,
    this.attachmentUrl,
    this.attachmentLocalPath,
  });
}

// ============================================
// PREFERENCE ENTITY (inchangé)
// ============================================

@Entity()
class PreferenceEntity {
  @Id()
  int id = 0;

  @Unique()
  @Index()
  String userId;

  int minAge;
  int maxAge;
  int maxDistance;

  String genderPreferenceJson;

  bool showOnlyVerified;
  bool showOnlyWithPhotos;

  bool notifyMatches;
  bool notifyMessages;
  bool notifyLikes;

  bool showOnline;
  bool showDistance;
  bool incognitoMode;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  PreferenceEntity({
    required this.userId,
    this.minAge = 18,
    this.maxAge = 99,
    this.maxDistance = 100,
    String? genderPreferenceJson,
    this.showOnlyVerified = false,
    this.showOnlyWithPhotos = false,
    this.notifyMatches = true,
    this.notifyMessages = true,
    this.notifyLikes = true,
    this.showOnline = true,
    this.showDistance = true,
    this.incognitoMode = false,
    required this.updatedAt,
  }) : genderPreferenceJson = genderPreferenceJson ?? '[]';

  List<String> get genderPreference {
    try {
      return List<String>.from(
        (genderPreferenceJson.isEmpty || genderPreferenceJson == '[]')
            ? []
            : Uri.decodeComponent(genderPreferenceJson).split(','),
      );
    } catch (e) {
      return [];
    }
  }

  set genderPreference(List<String> value) {
    genderPreferenceJson = value.isEmpty
        ? '[]'
        : Uri.encodeComponent(value.join(','));
  }
}