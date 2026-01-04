import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../objectbox.g.dart';
import '../objectbox_entities_complete.dart';

// ========================================
// OBJECTBOX SERVICE - FIX
// ========================================
class ObjectBoxService {
  late final Store _store;
  late final Box<UserEntity> _userBox;
  late final Box<PhotoEntity> _photoBox;
  late final Box<GroupEntity> _groupBox;
  late final Box<NotificationEntity> _notificationBox;

  static ObjectBoxService? _instance;

  ObjectBoxService._();

  static Future<ObjectBoxService> create() async {
    if (_instance != null) return _instance!;

    final instance = ObjectBoxService._();
    await instance._init();
    _instance = instance;
    return instance;
  }

  Future<void> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final storePath = path.join(dir.path, 'objectboxDBProfilum');

    _store = await openStore(directory: storePath);

    _userBox = Box<UserEntity>(_store);
    _photoBox = Box<PhotoEntity>(_store);
    _groupBox = Box<GroupEntity>(_store);
    _notificationBox = Box<NotificationEntity>(_store);
  }

  // ✅ FIX: User operations - Update existing entity
  Future<void> saveUser(UserEntity user) async {
    // ✅ Chercher l'entité existante par userId (unique)
    final query = _userBox
        .query(UserEntity_.userId.equals(user.userId))
        .build();
    final existing = query.findFirst();
    query.close();

    if (existing != null) {
      // ✅ IMPORTANT: Garder l'ID ObjectBox existant
      user.id = existing.id;
      debugPrint('✅ Updating existing user - ObjectBox ID: ${user.id}');
    } else {
      debugPrint('✅ Creating new user in ObjectBox');
    }

    _userBox.put(user);
    debugPrint('✅ User saved successfully');
  }

  Future<UserEntity?> getUser(String userId) async {
    final query = _userBox.query(UserEntity_.userId.equals(userId)).build();
    final user = query.findFirst();
    query.close();
    return user;
  }

  Future<UserEntity?> getUserByEmail(String email) async {
    final query = _userBox.query(UserEntity_.email.equals(email)).build();
    final user = query.findFirst();
    query.close();
    return user;
  }

  Future<void> deleteUser(String userId) async {
    final user = await getUser(userId);
    if (user != null) {
      _userBox.remove(user.id);
    }
  }

  // Photo operations
  Future<void> savePhoto(PhotoEntity photo) async {
    _photoBox.put(photo);
  }

  Future<List<PhotoEntity>> getPendingPhotos() async {
    final query = _photoBox
        .query(PhotoEntity_.status.equals('pending'))
        .build();
    final photos = query.find();
    query.close();
    return photos;
  }

  Future<List<PhotoEntity>> getUserPhotos(String userId) async {
    final query = _photoBox.query(PhotoEntity_.userId.equals(userId)).build();
    final photos = query.find();
    query.close();
    return photos;
  }

  // Group operations
  Future<void> saveGroup(GroupEntity group) async {
    _groupBox.put(group);
  }

  Future<List<GroupEntity>> getAllGroups() async {
    return _groupBox.getAll();
  }

  // Notification operations
  Future<void> saveNotification(NotificationEntity notification) async {
    _notificationBox.put(notification);
  }

  Future<List<NotificationEntity>> getUnreadNotifications(String userId) async {
    final query = _notificationBox
        .query(
          NotificationEntity_.userId.equals(userId) &
              NotificationEntity_.isRead.equals(false),
        )
        .build();
    final notifications = query.find();
    query.close();
    return notifications;
  }

  Future<void> markNotificationAsRead(int id) async {
    final notification = _notificationBox.get(id);
    if (notification != null) {
      notification.isRead = true;
      _notificationBox.put(notification);
    }
  }

  void close() {
    _store.close();
  }
}

// ========================================
// SUPABASE SERVICE
// ========================================
class SupabaseService {
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
