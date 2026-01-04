// lib/core/database/entities/user_entity.dart
import 'dart:convert';

import 'package:flutter/foundation.dart'; // Pour debugPrint
import 'package:flutter/material.dart';
import 'package:objectbox/objectbox.dart';

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

  // Liste sérialisée en JSON
  String photosJson;

  String? photoUrl;
  String? coverUrl;

  bool profileCompleted;
  int completionPercentage;

  String? occupation;

  String interestsJson;

  int? heightCm;
  String? education;
  String? relationshipStatus;
  String? instagramHandle;
  String? spotifyAnthem;
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
    String? photosJson,
    this.photoUrl,
    this.coverUrl,
    this.profileCompleted = false,
    this.completionPercentage = 0,
    this.occupation,
    String? interestsJson,
    this.heightCm,
    this.education,
    this.relationshipStatus,
    this.instagramHandle,
    this.spotifyAnthem,
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
  }) : photosJson = photosJson ?? '[]',
       interestsJson = interestsJson ?? '[]',
       pendingActionsJson = pendingActionsJson ?? '[]';

  // ✅ FIX: GETTER PHOTOS - JSON standard uniquement
  List<String> get photos {
    if (photosJson.isEmpty || photosJson == '[]') {
      return [];
    }

    try {
      final decoded = jsonDecode(photosJson);
      if (decoded is List) {
        return List<String>.from(decoded);
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error decoding photos from: $photosJson');
      debugPrint('   Error: $e');
      return [];
    }
  }

  // ✅ FIX: SETTER PHOTOS - JSON standard uniquement
  set photos(List<String> value) {
    photosJson = jsonEncode(value);
  }

  // ✅ FIX: GETTER INTERESTS - JSON standard uniquement
  List<String> get interests {
    if (interestsJson.isEmpty || interestsJson == '[]') {
      return [];
    }

    try {
      final decoded = jsonDecode(interestsJson);
      if (decoded is List) {
        return List<String>.from(decoded);
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error decoding interests from: $interestsJson');
      return [];
    }
  }

  // ✅ FIX: SETTER INTERESTS - JSON standard uniquement
  set interests(List<String> value) {
    interestsJson = jsonEncode(value);
  }

  // ✅ FIX: GETTER PENDING ACTIONS - JSON standard uniquement
  List<String> get pendingActions {
    if (pendingActionsJson.isEmpty || pendingActionsJson == '[]') {
      return [];
    }

    try {
      final decoded = jsonDecode(pendingActionsJson);
      if (decoded is List) {
        return List<String>.from(decoded);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ✅ FIX: SETTER PENDING ACTIONS - JSON standard uniquement
  set pendingActions(List<String> value) {
    pendingActionsJson = jsonEncode(value);
  }
}

// lib/core/database/entities/photo_entity.dart
@Entity()
class PhotoEntity {
  @Id()
  int id = 0;

  @Unique()
  String photoId;

  @Index()
  String userId;

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

  bool isProfilePhoto;
  int displayOrder;

  PhotoEntity({
    required this.photoId,
    required this.userId,
    required this.localPath,
    this.remotePath,
    this.status = 'pending',
    this.hasWatermark = false,
    required this.uploadedAt,
    this.moderatedAt,
    this.moderatorId,
    this.rejectionReason,
    this.isProfilePhoto = false,
    this.displayOrder = 0,
  });
}

// lib/core/database/entities/group_entity.dart
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

  String memberIdsJson; // List<String> serialized

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

// lib/core/database/entities/notification_entity.dart
@Entity()
class NotificationEntity {
  @Id()
  int id = 0;

  @Unique()
  String notificationId;

  @Index()
  String userId;

  @Index()
  String type; // photo_approved, photo_rejected, profile_reminder, etc.

  String title;
  String body;
  String? imageUrl;
  String? actionRoute;

  String? metadataJson; // Map<String, dynamic> serialized

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
      // Simple parsing - en production utiliser json.decode
      return {}; // TODO: Implémenter parsing JSON
    } catch (e) {
      return null;
    }
  }

  set metadata(Map<String, dynamic>? value) {
    metadataJson = value?.toString(); // TODO: Utiliser json.encode
  }
}

// lib/core/database/entities/match_entity.dart
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
  String status; // pending, matched, unmatched

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

// lib/core/database/entities/message_entity.dart
// Pour la messagerie P2P future
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
  String type; // text, image, voice, video

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

// lib/core/database/entities/preference_entity.dart
@Entity()
class PreferenceEntity {
  @Id()
  int id = 0;

  @Unique()
  @Index()
  String userId;

  // Filtres de découverte
  int minAge;
  int maxAge;
  int maxDistance; // en km

  String genderPreferenceJson; // List<String> serialized

  bool showOnlyVerified;
  bool showOnlyWithPhotos;

  // Notifications
  bool notifyMatches;
  bool notifyMessages;
  bool notifyLikes;

  // Privacy
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
