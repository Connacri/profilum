
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'package:objectbox/objectbox.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;


class NetworkService extends ChangeNotifier {
  bool _isConnected = true;
  final Connectivity _connectivity = Connectivity();

  bool get isConnected => _isConnected;

  NetworkService() {
    _initConnectivity();
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Connectivity check error: $e');
      _isConnected = false;
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;
    
    if (wasConnected != _isConnected) {
      notifyListeners();
    }
  }
}



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
    final storePath = path.join(dir.path, 'objectbox');
    
    // Note: objectbox.g.dart doit être généré via build_runner
    // flutter pub run build_runner build
    _store = await openStore(directory: storePath);
    
    _userBox = Box<UserEntity>(_store);
    _photoBox = Box<PhotoEntity>(_store);
    _groupBox = Box<GroupEntity>(_store);
    _notificationBox = Box<NotificationEntity>(_store);
  }

  // User operations
  Future<void> saveUser(UserEntity user) async {
    _userBox.put(user);
  }

  Future<UserEntity?> getUser(String userId) async {
    final query = _userBox.query(
      UserEntity_.userId.equals(userId),
    ).build();
    
    final user = query.findFirst();
    query.close();
    return user;
  }

  Future<UserEntity?> getUserByEmail(String email) async {
    final query = _userBox.query(
      UserEntity_.email.equals(email),
    ).build();
    
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
    final query = _photoBox.query(
      PhotoEntity_.status.equals('pending'),
    ).build();
    
    final photos = query.find();
    query.close();
    return photos;
  }

  Future<List<PhotoEntity>> getUserPhotos(String userId) async {
    final query = _photoBox.query(
      PhotoEntity_.userId.equals(userId),
    ).build();
    
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
    final query = _notificationBox.query(
      NotificationEntity_.userId.equals(userId) &
      NotificationEntity_.isRead.equals(false),
    ).build();
    
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

  // Cleanup
  void close() {
    _store.close();
  }
}

// lib/core/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../objectbox_entities_complete.dart';

import '../objectbox_entities_complete.dart';

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

// lib/core/database/supabase_tables.sql
/*
-- Table profiles (déjà créée selon votre schéma)

-- Table photos
CREATE TABLE IF NOT EXISTS photos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  photo_id TEXT UNIQUE NOT NULL,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  local_path TEXT,
  remote_path TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  has_watermark BOOLEAN DEFAULT false,
  uploaded_at TIMESTAMPTZ DEFAULT NOW(),
  moderated_at TIMESTAMPTZ,
  moderator_id UUID REFERENCES profiles(id),
  rejection_reason TEXT,
  is_profile_photo BOOLEAN DEFAULT false,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table groups
CREATE TABLE IF NOT EXISTS groups (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  group_id TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  photo_url TEXT,
  creator_id UUID NOT NULL REFERENCES profiles(id),
  member_ids TEXT[] DEFAULT '{}',
  member_count INTEGER DEFAULT 0,
  category TEXT NOT NULL,
  is_private BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table notifications
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  notification_id TEXT UNIQUE NOT NULL,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  image_url TEXT,
  action_route TEXT,
  metadata JSONB,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_photos_user_id ON photos(user_id);
CREATE INDEX IF NOT EXISTS idx_photos_status ON photos(status);
CREATE INDEX IF NOT EXISTS idx_groups_creator_id ON groups(creator_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);

-- RLS Policies
ALTER TABLE photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Photos policies
CREATE POLICY "Users can view their own photos"
  ON photos FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own photos"
  ON photos FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Moderators can view all photos"
  ON photos FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role IN ('moderator', 'admin')
    )
  );

CREATE POLICY "Moderators can update photos"
  ON photos FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role IN ('moderator', 'admin')
    )
  );

-- Groups policies
CREATE POLICY "Users can view groups"
  ON groups FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can create groups"
  ON groups FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = creator_id);

-- Notifications policies
CREATE POLICY "Users can view their notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "System can insert notifications"
  ON notifications FOR INSERT
  WITH CHECK (true);

-- Functions
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_groups_updated_at
  BEFORE UPDATE ON groups
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
*/